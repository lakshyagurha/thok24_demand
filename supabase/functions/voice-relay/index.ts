// Realtime voice relay: Flutter <-> this function <-> Gemini Live.
//
// Why a relay and not a direct connection from the phone:
//
// The plan was for the device to hold a short-lived ephemeral token and talk to
// Gemini directly. That does not work on this project's credential — the mint
// endpoint returns 200 with a token name, but fetching that token back gives a
// 404, and the WebSocket rejects it in every documented transport
// (?access_token=, ?key=, `Authorization: Token`, on both v1beta and v1alpha).
// The only credential the Live socket accepts is the raw API key, and shipping
// that inside an APK would put a billable secret on every user's phone.
//
// So the key stays here and this function pumps frames both ways. That costs
// one extra hop (~50ms) and buys back something the ephemeral-token design
// never actually had: because the *server* composes the `setup` message and
// client `setup` frames are dropped on the floor, the persona, the tool list
// and the model are locked server-side by construction. A tampered client can
// send audio and tool results, and nothing else.
//
// Wall-clock: Edge Functions cap a socket at 150s (Free) / 400s (Pro) and drop
// earlier in practice. That is survivable because Gemini hands out a session
// resumption handle; the client reconnects with `?resume=<handle>` and the
// conversation continues mid-thought rather than restarting.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { json, preflight } from "../_shared/cors.ts";
import { requireUser } from "../_shared/auth.ts";
import { buildCatalogSnapshot } from "./catalog.ts";
import { buildSystemInstruction, Profile } from "./persona.ts";
import { TOOLS_FOR_SETUP } from "./tools.ts";

const GEMINI_WS =
  "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent";

const MODEL = Deno.env.get("GEMINI_LIVE_MODEL") ??
  "models/gemini-2.5-flash-native-audio-latest";
const VOICE = Deno.env.get("GEMINI_VOICE") ?? "";
const LANGUAGE = Deno.env.get("GEMINI_LANGUAGE") ?? "hi-IN";

/** Frames a client is allowed to forward. Anything else — `setup` above all — is dropped. */
const CLIENT_ALLOWED = new Set(["realtimeInput", "clientContent", "toolResponse"]);

async function buildProfile(
  db: SupabaseClient,
  displayName: string | null,
): Promise<Profile> {
  const profile: Profile = {
    name: displayName,
    regulars: [],
    hasAddress: false,
    cartCount: 0,
  };

  // All three are nice-to-have context. A failure here must not cost the user
  // their voice session, so each is best-effort and silent.
  const [regulars, addresses, cart] = await Promise.allSettled([
    db.from("regular_orders")
      .select("products(name)")
      .order("frequency_score", { ascending: false })
      .limit(5),
    db.from("delivery_address").select("id").limit(1),
    db.from("cart_items").select("id"),
  ]);

  if (regulars.status === "fulfilled" && regulars.value.data) {
    profile.regulars = (regulars.value.data as { products?: { name?: string } }[])
      .map((r) => r.products?.name)
      .filter((n): n is string => !!n);
  }
  if (addresses.status === "fulfilled") {
    profile.hasAddress = (addresses.value.data?.length ?? 0) > 0;
  }
  if (cart.status === "fulfilled") {
    profile.cartCount = cart.value.data?.length ?? 0;
  }
  return profile;
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  // Authenticate BEFORE looking at the upgrade, so an unauthenticated caller
  // gets an identical 401 whatever shape their request is and cannot use the
  // response code to probe what this endpoint expects.
  //
  // This check is the ONLY gate: the function is deployed with verify_jwt
  // disabled because the platform's gateway JWT check cannot pass a WebSocket
  // upgrade through (it 502s before the function is ever invoked). Everything
  // past this line is therefore load-bearing — do not weaken it.
  const caller = await requireUser(req);
  if (!caller) {
    return json({ success: false, message: "Unauthorized" }, 401, req);
  }

  if (req.headers.get("upgrade")?.toLowerCase() !== "websocket") {
    return json(
      { success: false, message: "Expected a WebSocket upgrade." },
      400,
      req,
    );
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return json(
      { success: false, message: "Voice ordering is unavailable right now." },
      503,
      req,
    );
  }

  // Compose the whole session server-side before upgrading, so the socket is
  // useful the moment it opens.
  let systemInstruction: string;
  try {
    const [catalog, profile] = await Promise.all([
      buildCatalogSnapshot(caller.client),
      buildProfile(
        caller.client,
        (await caller.client.auth.getUser()).data.user?.user_metadata?.name ??
          null,
      ),
    ]);
    systemInstruction = buildSystemInstruction(catalog, profile);
  } catch (e) {
    console.error("voice-relay setup failed:", e instanceof Error ? e.message : e);
    return json(
      { success: false, message: "Voice ordering is unavailable right now." },
      503,
      req,
    );
  }

  const resume = new URL(req.url).searchParams.get("resume");

  const { socket: client, response } = Deno.upgradeWebSocket(req);

  // deno-lint-ignore no-explicit-any
  const speechConfig: Record<string, any> = { languageCode: LANGUAGE };
  if (VOICE) {
    speechConfig.voiceConfig = { prebuiltVoiceConfig: { voiceName: VOICE } };
  }

  const setup = {
    setup: {
      model: MODEL,
      generationConfig: {
        responseModalities: ["AUDIO"],
        speechConfig,
      },
      systemInstruction: { parts: [{ text: systemInstruction }] },
      tools: TOOLS_FOR_SETUP,
      // Captions. Native audio is speech-to-speech, so without these there is
      // no text at all to render — and a voice UI with no transcript is
      // unusable to anyone who mishears it or has the phone muted.
      inputAudioTranscription: {},
      outputAudioTranscription: {},
      // Audio accrues ~25 tokens/sec; without this a long session eventually
      // walks off the end of the context window mid-order.
      contextWindowCompression: { slidingWindow: {} },
      sessionResumption: resume ? { handle: resume } : {},
    },
  };

  let upstream: WebSocket | null = null;
  let upstreamReady = false;
  const pending: string[] = [];

  const closeBoth = (code: number, reason: string) => {
    try { upstream?.close(); } catch { /* already gone */ }
    try {
      // 1000-4999 are the only codes close() accepts; anything else throws.
      client.close(code >= 1000 && code <= 4999 ? code : 1011, reason.slice(0, 120));
    } catch { /* already gone */ }
  };

  client.onopen = () => {
    upstream = new WebSocket(`${GEMINI_WS}?key=${encodeURIComponent(apiKey)}`);

    upstream.onopen = () => {
      upstream!.send(JSON.stringify(setup));
    };

    upstream.onmessage = async (ev: MessageEvent) => {
      const raw = typeof ev.data === "string"
        ? ev.data
        : ev.data instanceof Blob
        ? await ev.data.text()
        : new TextDecoder().decode(ev.data as ArrayBuffer);

      // Flush anything the client said while we were still handshaking.
      if (!upstreamReady && raw.includes("setupComplete")) {
        upstreamReady = true;
        for (const m of pending.splice(0)) {
          try { upstream!.send(m); } catch { /* upstream died mid-flush */ }
        }
      }

      if (client.readyState === WebSocket.OPEN) client.send(raw);
    };

    upstream.onerror = () => {
      closeBoth(1011, "upstream error");
    };

    upstream.onclose = (e: CloseEvent) => {
      closeBoth(e.code, e.reason || "upstream closed");
    };
  };

  client.onmessage = (ev: MessageEvent) => {
    if (typeof ev.data !== "string") return;

    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(ev.data);
    } catch {
      return;
    }

    // The security boundary. A client that sends `setup` — trying to swap the
    // persona, widen the tool list, or point at a different model — gets it
    // silently dropped rather than honoured.
    const keys = Object.keys(parsed);
    if (!keys.length || !keys.every((k) => CLIENT_ALLOWED.has(k))) return;

    if (!upstreamReady || upstream?.readyState !== WebSocket.OPEN) {
      // Bounded so a client that floods before setup cannot grow this without limit.
      if (pending.length < 256) pending.push(ev.data);
      return;
    }
    try { upstream.send(ev.data); } catch { /* dropped frame; audio is lossy anyway */ }
  };

  client.onclose = () => {
    try { upstream?.close(); } catch { /* already gone */ }
  };

  client.onerror = () => {
    try { upstream?.close(); } catch { /* already gone */ }
  };

  return response;
});
