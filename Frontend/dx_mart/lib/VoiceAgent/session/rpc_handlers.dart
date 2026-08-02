import 'dart:convert';

import 'package:livekit_client/livekit_client.dart';

import '../tools/tool_dispatcher.dart';

/// The names the agent calls. These must match the `@function_tool` names in
/// `agents/voice/agent.py` exactly — a mismatch fails silently as an unknown
/// method, which the agent hears as a tool error and apologises for.
const voiceRpcMethods = <String>[
  'search_products',
  'get_price',
  'add_to_cart',
  'update_cart_item',
  'read_cart',
  'place_order',
];

/// Wires the agent's tool calls to code running on this phone.
///
/// This is the whole reason the agent can act without ever holding the user's
/// Supabase token: it asks the phone to do the work, and the phone does it
/// through the same repositories the rest of the app uses, under the signed-in
/// user's own JWT with RLS applied. `place-order` still recomputes every rupee
/// server-side regardless of anything said out loud.
///
/// Must be called BEFORE [Room.connect]. The agent can issue its first tool
/// call the moment it joins, and a handler registered after that races.
void registerVoiceRpc(Room room, ToolDispatcher dispatcher) {
  for (final method in voiceRpcMethods) {
    room.registerRpcMethod(method, (RpcInvocationData data) async {
      Map<String, dynamic> args;
      try {
        final decoded = data.payload.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(data.payload);
        args = decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
      } catch (_) {
        // Malformed payload is the agent's problem to recover from, not a
        // reason to drop the connection.
        return jsonEncode({'ok': false, 'error': 'Could not read the request.'});
      }

      final result = await dispatcher.call(method, args);
      return jsonEncode(result);
    });
  }
}
