import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("speech", Path(__file__).with_name("speech-transcribe.py"))
speech = importlib.util.module_from_spec(spec)
spec.loader.exec_module(speech)


class SubtitleTests(unittest.TestCase):
    def test_vtt_preserves_commas_in_text(self):
        self.assertTrue(hasattr(speech, "render_vtt"), "VTT rendering is missing")
        result = speech.render_vtt([{"start": 1.25, "end": 2.5, "text": "Hello, world."}])
        self.assertIn("00:00:01.250 --> 00:00:02.500", result)
        self.assertIn("Hello, world.", result)
        self.assertTrue(result.startswith("WEBVTT\n\n"))

    def test_cli_selects_gpu_and_subtitle_format(self):
        self.assertTrue(hasattr(speech, "parse_args"), "new CLI is missing")
        args = speech.parse_args(["accuracy", "clip.webm", "--language", "Japanese", "--format", "srt"])
        self.assertEqual((args.mode, args.language, args.format, args.device), ("accuracy", "Japanese", "srt", "cuda"))

    def test_cues_split_on_long_pauses(self):
        self.assertTrue(hasattr(speech, "subtitle_cues"), "cue grouping is missing")
        words = [{"text": "こんにちは", "start": 0.1, "end": 1.0}, {"text": "皆さん", "start": 1.0, "end": 2.0}, {"text": "次", "start": 5.0, "end": 6.0}]
        self.assertEqual(speech.subtitle_cues(words, "Japanese"), [
            {"start": 0.1, "end": 2.0, "text": "こんにちは皆さん"},
            {"start": 5.0, "end": 6.0, "text": "次"},
        ])

    def test_parakeet_subwords_become_timed_words(self):
        self.assertTrue(hasattr(speech, "timed_words"), "timed word conversion is missing")
        result = {"tokens": [" A", "sk", " not", "."], "timestamps": [0.0, 0.2, 0.4, 0.7], "durations": [0.2, 0.2, 0.3, 0.1]}
        self.assertEqual(speech.timed_words(result, 10), [
            {"text": "Ask", "start": 10.0, "end": 10.4},
            {"text": "not.", "start": 10.4, "end": 10.8},
        ])

    def test_srt_has_real_timestamps_and_unicode(self):
        self.assertTrue(hasattr(speech, "render_srt"), "subtitle rendering is missing")
        self.assertEqual(speech.render_srt([
            {"start": 1.25, "end": 3.5, "text": "こんにちは。"},
            {"start": 3601.0, "end": 3602.0, "text": "Hello."},
        ]), "1\n00:00:01,250 --> 00:00:03,500\nこんにちは。\n\n2\n01:00:01,000 --> 01:00:02,000\nHello.\n")


if __name__ == "__main__":
    unittest.main()
