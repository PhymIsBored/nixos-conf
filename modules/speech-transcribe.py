import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import wave

def timed_words(result, offset=0):
    words = []
    for token, start, duration in zip(result["tokens"], result["timestamps"], result["durations"], strict=True):
        end = round(offset + start + duration, 4)
        if token.startswith(" ") or not words:
            words.append({"text": token.lstrip(), "start": round(offset + start, 4), "end": end})
        else:
            words[-1]["text"] += token
            words[-1]["end"] = end
    return words


def subtitle_cues(words, language):
    cues = []
    separator = "" if language in {"Japanese", "Chinese", "Cantonese"} else " "
    limit = 32 if not separator else 84
    for word in words:
        if word["end"] <= word["start"] or not word["text"]:
            continue
        if not cues or word["start"] - cues[-1]["end"] > 0.8 or word["end"] - cues[-1]["start"] > 6 or len(cues[-1]["text"]) + len(word["text"]) > limit:
            cues.append(dict(word))
        else:
            cues[-1]["text"] += separator + word["text"]
            cues[-1]["end"] = word["end"]
    return cues


def render_srt(segments):
    def stamp(seconds):
        ms = round(seconds * 1000)
        hours, ms = divmod(ms, 3600000)
        minutes, ms = divmod(ms, 60000)
        seconds, ms = divmod(ms, 1000)
        return f"{hours:02}:{minutes:02}:{seconds:02},{ms:03}"

    return "\n\n".join(
        f"{i}\n{stamp(s['start'])} --> {stamp(s['end'])}\n{s['text']}"
        for i, s in enumerate(segments, 1)
    ) + "\n"


def render_vtt(segments):
    lines = render_srt(segments).splitlines()
    return "WEBVTT\n\n" + "\n".join(line.replace(",", ".") if " --> " in line else line for line in lines) + "\n"


def parse_args(argv=None):
    import argparse

    parser = argparse.ArgumentParser(description="Local transcription and timed subtitles")
    parser.add_argument("mode", choices=["accuracy", "speed"])
    parser.add_argument("input")
    parser.add_argument("--language", help="Qwen language name, e.g. Japanese or English")
    parser.add_argument("--format", choices=["text", "json", "srt", "vtt"], default="text")
    parser.add_argument("--device", choices=["cuda", "cpu"], default="cuda")
    parser.add_argument("--output")
    parser.add_argument("--chunk-seconds", type=int, default=60)
    parser.add_argument("--limit-seconds", type=float, help="Transcribe only the start of the input")
    args = parser.parse_args(argv)
    if not 1 <= args.chunk_seconds <= 120:
        parser.error("--chunk-seconds must be between 1 and 120")
    return args


def audio_chunks(args, directory):
    wav = directory / "audio.wav"
    cmd = ["ffmpeg", "-v", "error", "-y", "-i", args.input]
    if args.limit_seconds is not None:
        cmd += ["-t", str(args.limit_seconds)]
    subprocess.run(cmd + ["-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", str(wav)], check=True)
    with wave.open(str(wav), "rb") as audio:
        rate = audio.getframerate()
        offset = 0.0
        while frames := audio.readframes(args.chunk_seconds * rate):
            chunk = directory / "chunk.wav"
            with wave.open(str(chunk), "wb") as out:
                out.setparams(audio.getparams())
                out.writeframes(frames)
            yield offset, chunk
            offset += len(frames) / (2 * rate)


def parakeet_chunk(args, chunk, offset):
    model = Path(os.environ["PARAKEET_MODEL"])
    cmd = [os.environ["SHERPA_CUDA_BIN"], f"--provider={args.device}", "--model-type=nemo_transducer", "--num-threads=4"]
    cmd += [f"--{name}={model}/{name}.int8.onnx" for name in ("encoder", "decoder", "joiner")]
    cmd += [f"--tokens={model}/tokens.txt", str(chunk)]
    result = subprocess.run(cmd, text=True, capture_output=True, check=True)
    if args.device == "cuda" and any(s in result.stderr.lower() for s in ("fallback to cpu", "fall back to cpu", "failed to create cuda")):
        raise RuntimeError("CUDA initialization failed; refusing silent CPU fallback\n" + result.stderr)
    data = json.loads(result.stdout)
    return data["text"], timed_words(data, offset)


def load_qwen(args):
    import torch
    from qwen_asr import Qwen3ASRModel

    if args.device == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA is unavailable; use --device cpu explicitly if intended")
    device = "cuda:0" if args.device == "cuda" else "cpu"
    dtype = torch.bfloat16 if args.device == "cuda" else torch.float32
    kwargs = dict(
        revision="7278e1e70fe206f11671096ffdd38061171dd6e5",
        dtype=dtype, device_map=device, attn_implementation="sdpa",
        max_inference_batch_size=1, max_new_tokens=1024,
    )
    if args.format != "text":
        kwargs.update(
            forced_aligner="Qwen/Qwen3-ForcedAligner-0.6B",
            forced_aligner_kwargs=dict(revision="c7cbfc2048c462b0d63a45797104fc9db3ad62b7", dtype=dtype, device_map=device, attn_implementation="sdpa"),
        )
    model = Qwen3ASRModel.from_pretrained("Qwen/Qwen3-ASR-1.7B", **kwargs)
    if args.device == "cuda" and model.model.device.type != "cuda":
        raise RuntimeError("Qwen did not load on CUDA")
    print(f"Qwen3-ASR-1.7B on {model.model.device}", file=sys.stderr)
    return model


def main():
    args = parse_args()
    started = time.monotonic()
    texts, words, languages = [], [], []
    model = load_qwen(args) if args.mode == "accuracy" else None
    with tempfile.TemporaryDirectory(prefix="transcribe-") as name:
        for offset, chunk in audio_chunks(args, Path(name)):
            print(f"Transcribing at {offset:.1f}s", file=sys.stderr)
            if model is None:
                text, spans = parakeet_chunk(args, chunk, offset)
                language = args.language or "auto"
            else:
                result = model.transcribe(audio=str(chunk), language=args.language, return_time_stamps=args.format != "text")[0]
                text, language = result.text, result.language
                spans = [] if result.time_stamps is None else [
                    dict(text=w.text, start=round(offset + w.start_time, 4), end=round(offset + w.end_time, 4)) for w in result.time_stamps
                ]
            texts.append(text)
            words.extend(spans)
            languages.append(language)
    language = args.language or next((l for l in languages if l), "auto")
    segments = subtitle_cues(words, language)
    if args.format == "text":
        output = "\n".join(texts) + "\n"
    elif args.format == "json":
        data = dict(model="Qwen/Qwen3-ASR-1.7B" if model else "nvidia/parakeet-tdt-0.6b-v3", device=args.device, language=language, text="\n".join(texts), words=words, segments=segments, elapsed_seconds=time.monotonic() - started)
        if model is not None and args.device == "cuda":
            import torch
            data["peak_vram_mib"] = torch.cuda.max_memory_allocated() / 1024**2
        output = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    else:
        output = render_vtt(segments) if args.format == "vtt" else render_srt(segments)
    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
