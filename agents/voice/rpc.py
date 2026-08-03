"""Calls a tool on the customer's phone and returns its result.

Every tool the agent exposes runs *on the device*, not here. That is deliberate:
the phone already holds a signed-in Supabase session, so the work happens under
the customer's own JWT with RLS applied, and their access token never has to
leave the handset or live inside a hosted process. It also means the product
cards appear the instant the tool runs, because the thing doing the work is the
thing drawing the screen.

The cost is one round trip to the phone (~50-150ms). The persona hides it by
telling the agent to keep talking while a tool runs.
"""

from __future__ import annotations

import json
import logging

from livekit import rtc
from livekit.agents import ToolError

logger = logging.getLogger("ramu-bhai.rpc")

# The phone is on a mobile network and add_to_cart writes to Postgres. Generous
# enough to survive a slow round trip, short enough that the customer is not
# left in silence wondering if it heard them.
_TIMEOUT_SECONDS = 12.0


async def call_phone(
    room: rtc.Room,
    identity: str,
    method: str,
    args: dict | None = None,
) -> dict:
    """Invokes `method` on the participant `identity` and returns its JSON result.

    Raises ToolError with a spoken-Hinglish message on any failure, because
    whatever this raises is what the customer hears.
    """
    payload = json.dumps(args or {})
    try:
        raw = await room.local_participant.perform_rpc(
            destination_identity=identity,
            method=method,
            payload=payload,
            response_timeout=_TIMEOUT_SECONDS,
        )
    except rtc.RpcError as e:
        logger.warning("rpc %s failed: %s", method, e)
        raise ToolError(
            "Abhi wo kaam nahi ho paaya, ek baar phir se boliye."
        ) from e
    except Exception as e:  # transport died mid-call
        logger.warning("rpc %s transport error: %s", method, e)
        raise ToolError("Connection thoda slow hai, ek second.") from e

    try:
        result = json.loads(raw)
    except ValueError as e:
        logger.error("rpc %s returned non-JSON: %r", method, raw[:200])
        raise ToolError("Kuch gadbad ho gayi, phir se boliye.") from e

    if not isinstance(result, dict):
        raise ToolError("Kuch gadbad ho gayi, phir se boliye.")

    if not result.get("ok"):
        # ToolDispatcher already returns customer-appropriate text here
        # ("Only 2 left of...", "Coupon has expired"), so surface it verbatim
        # rather than replacing it with something vaguer.
        raise ToolError(str(result.get("error") or "Wo abhi nahi ho paayega."))

    return result
