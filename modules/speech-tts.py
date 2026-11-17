import argparse
import re
import sys
import time
from pathlib import Path

MODEL = "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice"
REVISION = "0c0e3051f131929182e2c023b9537f8b1c68adfe"
DEFAULT_SPEAKER = "ryan"
MAX_CHUNK_CHARS = 300
PAUSE_SECONDS = 0.25


def split_text(text, limit=MAX_CHUNK_CHARS):
    sentences = [s.strip() for s in re.split(r"(?<=[.!?。！？])\s*|\n+", text) if s.strip()]
    chunks, current = [], ""
    for sentence in sentences:
        while len(sentence) > limit:
            cut = max(sentence.rfind(" ", 0, limit), sentence.rfind("，", 0, limit) + 1, sentence.rfind(",", 0, limit) + 1)
            cut = cut if cut > 0 else limit
            if current:
                chunks.append(current)
                current = ""
            chunks.append(sentence[:cut].strip())
            sentence = sentence[cut:].strip()
        if current and len(current) + 1 + len(sentence) > limit:
            chunks.append(current)
            current = sentence
        else:
            current = f"{current} {sentence}".strip()
    if current:
        chunks.append(current)
    return chunks


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Local text-to-speech with Qwen3-TTS (preset voices)")
    source = parser.add_mutually_exclusive_group()
    source.add_argument("text", nargs="?", help="Text to speak")
    source.add_argument("--input", help="Read text from a UTF-8 file")
    parser.add_argument("--output", help="Output WAV path")
    parser.add_argument("--language", default="English", help="Qwen language name, e.g. English, Japanese, Chinese")
    parser.add_argument("--speaker", default=DEFAULT_SPEAKER, help="Preset speaker name")
    parser.add_argument("--device", choices=["cuda", "cpu"], default="cuda")
    parser.add_argument("--list-speakers", action="store_true", help="Print preset speakers and exit")
    args = parser.parse_args(argv)
    if args.list_speakers:
        return args
    if args.output is None:
        parser.error("--output is required")
    if args.text is None and args.input is None:
        parser.error("provide text or --input")
    return args


def load_model(device):
    import torch
    from qwen_tts import Qwen3TTSModel

    if device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable; use --device cpu explicitly if intended")
    dtype = torch.bfloat16 if device == "cuda" else torch.float32
    model = Qwen3TTSModel.from_pretrained(
        MODEL, revision=REVISION, device_map="cuda:0" if device == "cuda" else "cpu",
        dtype=dtype, attn_implementation="sdpa",
    )
    print(f"{MODEL} on {model.model.device}", file=sys.stderr)
    return model


def main():
    args = parse_args()
    started = time.monotonic()
    model = load_model(args.device)
    if args.list_speakers:
        print("\n".join(model.get_supported_speakers()))
        return
    speakers = {name.lower(): name for name in model.get_supported_speakers()}
    if args.speaker.lower() not in speakers:
        raise SystemExit(f"unknown speaker {args.speaker!r}; see --list-speakers")
    speaker = speakers[args.speaker.lower()]
    text = args.text if args.input is None else Path(args.input).read_text(encoding="utf-8")
    chunks = split_text(text)
    if not chunks:
        raise SystemExit("no text to synthesize")

    import numpy as np
    import soundfile as sf

    pieces, rate = [], None
    for i, chunk in enumerate(chunks, 1):
        print(f"Synthesizing chunk {i}/{len(chunks)}", file=sys.stderr)
        wavs, rate = model.generate_custom_voice(text=chunk, language=args.language, speaker=speaker)
        pieces.append(np.asarray(wavs[0], dtype=np.float32))
        pieces.append(np.zeros(int(PAUSE_SECONDS * rate), dtype=np.float32))
    sf.write(args.output, np.concatenate(pieces[:-1]), rate)
    print(f"wrote {args.output} ({len(chunks)} chunks, {time.monotonic() - started:.1f}s)", file=sys.stderr)


if __name__ == "__main__":
    main()
