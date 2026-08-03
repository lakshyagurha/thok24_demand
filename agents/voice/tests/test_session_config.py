"""Constructs the real session config, so a bad field type cannot reach a deploy.

This exists because one did. `AudioTranscriptionConfig.language_auto` is a
`LanguageAuto` object, not a bool; passing `False` raised a pydantic
ValidationError the instant the session was built. The agent accepted the job,
joined the room, crashed, and left — which on the phone looked like
"connection टूट गया" with no other clue.

Introspecting field *names* was not enough. These tests instantiate the real
objects, which is the only thing that checks the types.

Run: ./.venv/bin/python -m pytest tests/ -q
"""

import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

os.environ.setdefault("GOOGLE_API_KEY", "test-key-not-used")

from google.genai import types as g  # noqa: E402


class TestTranscriptionConfig:
    def test_language_codes_pins_the_script(self):
        # Hindi and Urdu are the same spoken language in different scripts, so
        # without an explicit code the transcript sometimes came back in
        # Nastaliq — correct, but unreadable to this audience.
        c = g.AudioTranscriptionConfig(language_codes=["hi-IN"])
        assert c.language_codes == ["hi-IN"]

    def test_language_auto_is_not_a_bool(self):
        """The exact bug. Kept as a test so nobody 'simplifies' it back."""
        with pytest.raises(Exception):
            g.AudioTranscriptionConfig(language_codes=["hi-IN"], language_auto=False)


class TestVadConfig:
    def test_low_sensitivity_values_exist(self):
        # These are what stop the agent treating its own leaked audio as the
        # customer interrupting.
        assert g.StartSensitivity.START_SENSITIVITY_LOW
        assert g.EndSensitivity.END_SENSITIVITY_LOW

    def test_activity_detection_accepts_our_tuning(self):
        d = g.AutomaticActivityDetection(
            start_of_speech_sensitivity=g.StartSensitivity.START_SENSITIVITY_LOW,
            end_of_speech_sensitivity=g.EndSensitivity.END_SENSITIVITY_LOW,
            prefix_padding_ms=300,
            silence_duration_ms=700,
        )
        assert d.silence_duration_ms == 700


def test_full_realtime_model_constructs():
    """The whole config agent.py builds, instantiated for real.

    A deploy cycle takes minutes; this takes milliseconds and catches the same
    class of failure.
    """
    from livekit.plugins import google

    model = google.realtime.RealtimeModel(
        model="gemini-2.5-flash-native-audio-latest",
        voice="Charon",
        language="hi-IN",
        temperature=0.6,
        input_audio_transcription=g.AudioTranscriptionConfig(language_codes=["hi-IN"]),
        output_audio_transcription=g.AudioTranscriptionConfig(language_codes=["hi-IN"]),
        context_window_compression=g.ContextWindowCompressionConfig(
            sliding_window=g.SlidingWindow(),
        ),
        realtime_input_config=g.RealtimeInputConfig(
            automatic_activity_detection=g.AutomaticActivityDetection(
                start_of_speech_sensitivity=g.StartSensitivity.START_SENSITIVITY_LOW,
                end_of_speech_sensitivity=g.EndSensitivity.END_SENSITIVITY_LOW,
                prefix_padding_ms=300,
                silence_duration_ms=700,
            ),
        ),
    )
    assert model is not None


def test_tool_names_match_the_flutter_rpc_handlers():
    """A rename on either side fails silently as an unknown RPC method.

    Keep in step with voiceRpcMethods in
    Frontend/dx_mart/lib/VoiceAgent/session/rpc_handlers.dart.
    """
    import agent

    a = agent.RamuBhai(instructions="test", phone_identity="user_test")
    assert {t.info.name for t in a.tools} == {
        "search_products",
        "get_price",
        "add_to_cart",
        "update_cart_item",
        "read_cart",
        "place_order",
    }
