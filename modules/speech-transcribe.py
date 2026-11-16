import sys
import wave

import numpy as np
import sherpa_onnx

CHUNK_S = 25


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getframerate() == 16000 and w.getnchannels() == 1, "need 16 kHz mono"
        frames = w.readframes(w.getnframes())
    return 16000, np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0


def decode(rec, sr, samples):
    s = rec.create_stream()
    s.accept_waveform(sr, samples)
    rec.decode_stream(s)
    return s.result.text


def parakeet(model_dir, wav):
    rec = sherpa_onnx.OfflineRecognizer.from_transducer(
        encoder=f"{model_dir}/encoder.int8.onnx",
        decoder=f"{model_dir}/decoder.int8.onnx",
        joiner=f"{model_dir}/joiner.int8.onnx",
        tokens=f"{model_dir}/tokens.txt",
        model_type="nemo_transducer",
        num_threads=4,
    )
    sr, samples = read_wav(wav)
    return decode(rec, sr, samples)


def qwen3(model_dir, wav):
    rec = sherpa_onnx.OfflineRecognizer.from_qwen3_asr(
        conv_frontend=f"{model_dir}/conv_frontend.onnx",
        encoder=f"{model_dir}/encoder.int8.onnx",
        decoder=f"{model_dir}/decoder.int8.onnx",
        tokenizer=f"{model_dir}/tokenizer",
        num_threads=4,
        max_new_tokens=512,
    )
    sr, samples = read_wav(wav)
    step = CHUNK_S * sr
    parts = [
        decode(rec, sr, samples[i : i + step]) for i in range(0, len(samples), step)
    ]
    return " ".join(p.strip() for p in parts if p.strip())


if __name__ == "__main__":
    kind, model_dir, wav = sys.argv[1], sys.argv[2], sys.argv[3]
    print({"parakeet": parakeet, "qwen3": qwen3}[kind](model_dir, wav))
