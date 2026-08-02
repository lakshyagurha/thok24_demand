// Mints the short-lived LiveKit token the phone uses to join its voice room.
//
// A plain POST, deliberately. The previous design tried to proxy the audio
// socket itself through an Edge Function, which meant fighting a wall-clock cap
// and a gateway that maps any non-101 response to 502. Here the function does
// one cheap thing and gets out of the way: WebRTC media never touches Supabase.
//
// Two properties worth stating, because both are load-bearing:
//
//   * Personalisation travels as *signed token attributes*. The customer's
//     name, their repeat items and whether they have an address are read here,
//     under the caller's own RLS, and stamped into the JWT. A tampered client
//     cannot claim someone else's history, because it cannot forge the token.
//
//   * The token carries an explicit agent dispatch. No agent — and therefore no
//     billed minute — can be started by merely joining a room; only a token this
//     function issued will summon one.

import { json, preflight } from "../_shared/cors.ts";
import { requireUser } from "../_shared/auth.ts";
import { buildProfile } from "./profile.ts";

// First `npm:` specifier in this repo; fine on Deno 2, and livekit-server-sdk
// v2 documents Deno support.
//
// Type-checked against the real package (2.17.0) rather than taken on trust:
// `deno check` validates the AccessToken options, addGrant, roomConfig,
// RoomConfiguration and RoomAgentDispatch shapes below against the package's
// own type definitions. What that does NOT prove is runtime behaviour — that
// the server honours this dispatch config — which only a live join will show.
import {
  AccessToken,
  RoomAgentDispatch,
  RoomConfiguration,
} from "npm:livekit-server-sdk@2";

/** Must match `agent_name` in agents/voice/agent.py. */
const AGENT_NAME = "ramu-bhai";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  const caller = await requireUser(req);
  if (!caller) {
    return json({ success: false, message: "Unauthorized" }, 401, req);
  }

  const url = Deno.env.get("LIVEKIT_URL");
  const apiKey = Deno.env.get("LIVEKIT_API_KEY");
  const apiSecret = Deno.env.get("LIVEKIT_API_SECRET");
  if (!url || !apiKey || !apiSecret) {
    // Degrades the same way every other function here does when a secret is
    // missing: a clear, honest unavailable rather than a confusing crash.
    return json(
      { success: false, message: "Voice ordering is unavailable right now." },
      503,
      req,
    );
  }

  try {
    const { data: userData } = await caller.client.auth.getUser();
    const displayName =
      (userData.user?.user_metadata?.name as string | undefined) ?? null;

    const profile = await buildProfile(caller.client, displayName);

    const identity = `user_${caller.id}`;
    const room = `voice_${caller.id}_${crypto.randomUUID().slice(0, 8)}`;

    const at = new AccessToken(apiKey, apiSecret, {
      identity,
      name: profile.name ?? undefined,
      // Long enough to join and reconnect once, short enough that a leaked
      // token is worth little. The session itself outlives the token.
      ttl: "15m",
      // Attribute values must be strings.
      attributes: {
        display_name: profile.name ?? "",
        regulars: JSON.stringify(profile.regulars),
        has_address: profile.hasAddress ? "true" : "false",
        cart_count: String(profile.cartCount),
      },
    });

    at.addGrant({
      roomJoin: true,
      room,
      canPublish: true,
      canSubscribe: true,
      // The tool results the phone returns travel on LiveKit's data plane.
      canPublishData: true,
      // The client must not be able to rewrite the attributes we just signed.
      canUpdateOwnMetadata: false,
    });

    at.roomConfig = new RoomConfiguration({
      agents: [new RoomAgentDispatch({ agentName: AGENT_NAME })],
      // Cost guardrails: reap the room quickly once nobody is in it, and cap it
      // to the customer plus one agent.
      emptyTimeout: 30,
      departureTimeout: 10,
      maxParticipants: 2,
    });

    return json(
      { success: true, url, token: await at.toJwt(), room, identity },
      200,
      req,
    );
  } catch (e) {
    console.error("voice-token failed:", e instanceof Error ? e.message : e);
    return json(
      { success: false, message: "Voice ordering is unavailable right now." },
      503,
      req,
    );
  }
});
