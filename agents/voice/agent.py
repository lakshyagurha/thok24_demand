"""Ramu Bhai — the DxMart voice ordering agent.

Runs on LiveKit Cloud. Speech in and speech out are handled by Gemini Live
(speech-to-speech, with its own VAD); LiveKit handles the WebRTC transport,
acoustic echo cancellation and interruption. Every tool call is forwarded to the
customer's phone over RPC, so nothing here ever holds a user's Supabase token.

Verified against livekit-agents 1.6.7 by introspecting the installed package,
not from memory: `perform_rpc` is keyword-only with a float `response_timeout`,
and `google.realtime.RealtimeModel` accepts the transcription and
context-compression configs used below.
"""

from __future__ import annotations

import asyncio
import logging
import os

from dotenv import load_dotenv
from google.genai import types as genai_types
from livekit import rtc
from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    JobProcess,
    RunContext,
    WorkerOptions,
    cli,
    function_tool,
    get_job_context,
)
from livekit.plugins import google

import catalog
from persona import build_system_instruction, from_attributes
from rpc import call_phone

load_dotenv(".env.local")
logger = logging.getLogger("ramu-bhai")

AGENT_NAME = "ramu-bhai"

# Confirmed available on this project's key by listing models that support
# bidiGenerateContent. Override per-deployment without touching code.
MODEL = os.getenv("GEMINI_LIVE_MODEL", "gemini-2.5-flash-native-audio-latest")
# "Charon" reads as clear and informative. Warmer options exist ("Sulafat",
# "Achird"); this is a one-word change once someone has actually listened.
VOICE = os.getenv("GEMINI_VOICE", "Charon")

# A phone left face-down must not hold a billed session open forever.
MAX_SESSION_SECONDS = int(os.getenv("MAX_SESSION_SECONDS", "480"))


class RamuBhai(Agent):
    """The order-taker. Every tool here runs on the customer's phone."""

    def __init__(self, instructions: str, phone_identity: str) -> None:
        super().__init__(instructions=instructions)
        self._phone = phone_identity

    async def _call(self, ctx: RunContext, method: str, args: dict) -> dict:
        # get_job_context().room, NOT ctx.session.room -- AgentSession has no
        # `room` attribute at all, so the previous form raised AttributeError on
        # every single tool call. That is why nothing could be added to the cart
        # and no product card ever appeared: the tools were failing before they
        # reached the phone.
        return await call_phone(get_job_context().room, self._phone, method, args)

    @function_tool
    async def search_products(self, ctx: RunContext, query: str) -> dict:
        """Search the catalog by name when the product list in your instructions is not enough.

        Prefer the catalog you already have; use this only for a genuinely unfamiliar word.

        Args:
            query: Hindi, Hinglish or English word to look up.
        """
        return await self._call(ctx, "search_products", {"query": query})

    @function_tool
    async def get_price(
        self, ctx: RunContext, product_id: int, variant_id: int | None = None
    ) -> dict:
        """Authoritative live price and stock for one product or variant.

        The catalog in your instructions is a snapshot and may be stale; call this
        before quoting a price you are unsure of.

        Args:
            product_id: Catalog product id, e.g. 3 for P3.
            variant_id: Optional variant id, e.g. 5 for V5.
        """
        return await self._call(
            ctx, "get_price", {"product_id": product_id, "variant_id": variant_id}
        )

    @function_tool
    async def add_to_cart(
        self,
        ctx: RunContext,
        product_id: int,
        variant_id: int | None = None,
        quantity: int = 1,
    ) -> dict:
        """Add a quantity of one variant to the cart.

        This is the ONLY way anything enters the cart; saying an item is added does
        not add it. Pick the variant matching the size the customer asked for.

        Args:
            product_id: Catalog product id.
            variant_id: Variant id. Required unless the product has only one.
            quantity: Whole units of this variant.
        """
        return await self._call(
            ctx,
            "add_to_cart",
            {
                "product_id": product_id,
                "variant_id": variant_id,
                "quantity": quantity,
            },
        )

    @function_tool
    async def update_cart_item(
        self,
        ctx: RunContext,
        product_id: int,
        quantity: int,
        variant_id: int | None = None,
    ) -> dict:
        """Set an existing cart line to an exact quantity. Use 0 to remove it.

        Args:
            product_id: Catalog product id.
            quantity: Target quantity. 0 removes the line.
            variant_id: Variant id of the line to change.
        """
        return await self._call(
            ctx,
            "update_cart_item",
            {
                "product_id": product_id,
                "variant_id": variant_id,
                "quantity": quantity,
            },
        )

    @function_tool
    async def read_cart(self, ctx: RunContext) -> dict:
        """The full cart with every line, the subtotal, and the delivery address.

        You MUST call this and read the result back aloud before placing any order.
        It returns a confirm_token which place_order requires.
        """
        return await self._call(ctx, "read_cart", {})

    @function_tool
    async def place_order(
        self, ctx: RunContext, confirm_token: str, confirmed: bool
    ) -> dict:
        """Place the order.

        Only call this after read_cart, after you have read the items and the total
        aloud, and after the customer has clearly agreed. Pass the confirm_token
        exactly as read_cart returned it. If they have not agreed, do not call this.

        Args:
            confirm_token: The token returned by the most recent read_cart call.
            confirmed: True only if the customer verbally agreed to place the order.
        """
        return await self._call(
            ctx,
            "place_order",
            {"confirm_token": confirm_token, "confirmed": confirmed},
        )


def prewarm(proc: JobProcess) -> None:
    """Warm the catalog before a job lands, so the first turn is not paying for it."""
    try:
        asyncio.get_event_loop().run_until_complete(catalog.fetch())
    except Exception as e:  # never block a session on this
        logger.warning("catalog prewarm failed: %s", e)


async def entrypoint(ctx: JobContext) -> None:
    await ctx.connect()

    participant = await ctx.wait_for_participant()
    logger.info("customer joined: %s", participant.identity)

    # Personalisation arrives as SIGNED token attributes minted by the
    # voice-token Edge Function, so a tampered client cannot claim someone
    # else's history.
    profile = from_attributes(dict(participant.attributes or {}))

    try:
        snapshot = await catalog.fetch()
    except Exception as e:
        logger.error("catalog fetch failed: %s", e)
        snapshot = catalog.cached() or ""

    session = AgentSession(
        llm=google.realtime.RealtimeModel(
            model=MODEL,
            voice=VOICE,
            language="hi-IN",
            temperature=0.6,
            # Captions for the on-screen transcript. Without these a
            # speech-to-speech model produces no text at all, which makes the
            # feature unusable to anyone who mishears it or has the phone muted.
            #
            # The language is pinned rather than auto-detected. Hindi and Urdu
            # are the same spoken language with different scripts, so
            # auto-detection kept rendering the customer's own words in
            # Nastaliq — correct transcription, unreadable to this audience.
            input_audio_transcription=genai_types.AudioTranscriptionConfig(
                language_codes=["hi-IN"],
                language_auto=False,
            ),
            output_audio_transcription=genai_types.AudioTranscriptionConfig(
                language_codes=["hi-IN"],
                language_auto=False,
            ),
            # The agent leaks into its own microphone on a speakerphone, and
            # the default sensitivity treats that as the customer interrupting,
            # so it cuts itself off mid-sentence. LOW start-sensitivity demands
            # stronger evidence before yielding the floor; the padding and
            # silence window stop it mistaking a mid-sentence breath for the
            # end of a turn.
            realtime_input_config=genai_types.RealtimeInputConfig(
                automatic_activity_detection=genai_types.AutomaticActivityDetection(
                    start_of_speech_sensitivity=genai_types.StartSensitivity.START_SENSITIVITY_LOW,
                    end_of_speech_sensitivity=genai_types.EndSensitivity.END_SENSITIVITY_LOW,
                    prefix_padding_ms=300,
                    silence_duration_ms=700,
                ),
            ),
            # Audio accrues ~25 tokens/sec; without this a long order eventually
            # walks off the end of the context window mid-conversation.
            context_window_compression=genai_types.ContextWindowCompressionConfig(
                sliding_window=genai_types.SlidingWindow(),
            ),
        )
    )

    # Deliberately no stt/tts/vad/turn_detection: Gemini Live is
    # speech-to-speech and does its own turn detection. Layering LiveKit's
    # semantic turn detector on top adds a whole pipeline and 200-400ms for no
    # gain here.
    await session.start(
        room=ctx.room,
        agent=RamuBhai(
            instructions=build_system_instruction(snapshot, profile),
            phone_identity=participant.identity,
        ),
    )

    async def _cap() -> None:
        await asyncio.sleep(MAX_SESSION_SECONDS)
        logger.info("session hit the %ss cap, shutting down", MAX_SESSION_SECONDS)
        ctx.shutdown(reason="max session duration reached")

    asyncio.create_task(_cap())

    greeting = (
        f"Namaste {profile.name} ji! Boliye, aaj kya bhijwaana hai?"
        if profile.name
        else "Namaste ji! Boliye, aaj kya bhijwaana hai?"
    )
    await session.generate_reply(instructions=f"Greet the customer: {greeting}")


if __name__ == "__main__":
    cli.run_app(
        WorkerOptions(
            entrypoint_fnc=entrypoint,
            prewarm_fnc=prewarm,
            agent_name=AGENT_NAME,
        )
    )
