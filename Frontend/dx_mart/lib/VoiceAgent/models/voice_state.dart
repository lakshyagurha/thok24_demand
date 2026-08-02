/// The lifecycle of a single voice ordering session.
///
/// One enum drives the orb's colour and motion, the status line, and which
/// controls are reachable — so there is exactly one place to look when the UI
/// and the session disagree about what is happening.
enum VoiceState {
  /// Nothing is running. The orb breathes slowly; tapping it starts a session.
  idle,

  /// Asking the OS for the microphone, or opening the session.
  connecting,

  /// The microphone is live and the user is being heard.
  listening,

  /// Audio has stopped and the agent is working out its reply.
  thinking,

  /// The agent is talking. Speaking over it must cut it off (barge-in).
  speaking,

  /// The bill has been read back and is waiting on a yes or no.
  confirming,

  /// The order is in flight through `place-order`.
  placing,

  /// The order is committed.
  placed,

  /// Something failed; the session carries the message to show.
  failed,
}

extension VoiceStateX on VoiceState {
  /// Whether a session is open — anything other than a resting or finished state.
  bool get isLive => switch (this) {
        VoiceState.connecting ||
        VoiceState.listening ||
        VoiceState.thinking ||
        VoiceState.speaking ||
        VoiceState.confirming ||
        VoiceState.placing =>
          true,
        VoiceState.idle || VoiceState.placed || VoiceState.failed => false,
      };

  /// Whether the microphone should be capturing in this state.
  ///
  /// Capture continues while the agent speaks — that is what makes barge-in
  /// possible. It stops only once the order is placed or something broke.
  bool get wantsMic => switch (this) {
        VoiceState.listening ||
        VoiceState.thinking ||
        VoiceState.speaking ||
        VoiceState.confirming =>
          true,
        VoiceState.idle ||
        VoiceState.connecting ||
        VoiceState.placing ||
        VoiceState.placed ||
        VoiceState.failed =>
          false,
      };
}
