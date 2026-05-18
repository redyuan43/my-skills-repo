#!/usr/bin/env python3
"""Render a narration script to WAV files with the Ivan Qwen3-TTS gateway."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import sys
import time
import urllib.error
import urllib.request
import wave
from pathlib import Path
from typing import Any


DEFAULT_ENDPOINT = "http://ivan-ms-7b17.taild500c8.ts.net:8091"
SILENCE_RMS_THRESHOLD = 80.0


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip()


def post_json(endpoint: str, path: str, payload: dict[str, Any], timeout: float) -> tuple[bytes, dict[str, str]]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        f"{endpoint.rstrip('/')}{path}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        headers = {key.lower(): value for key, value in response.headers.items()}
        return response.read(), headers


def get_json(endpoint: str, path: str, timeout: float) -> dict[str, Any]:
    with urllib.request.urlopen(f"{endpoint.rstrip('/')}{path}", timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def ensure_loaded(endpoint: str, timeout: float) -> dict[str, Any]:
    try:
        post_json(endpoint, "/api/tts/load", {}, timeout=timeout)
    except urllib.error.HTTPError as exc:
        if exc.code >= 500:
            raise
    return get_json(endpoint, "/api/status", timeout=timeout)


def normalize_for_tts(text: str) -> str:
    lines: list[str] = []
    in_code = False
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("```"):
            in_code = not in_code
            continue
        if in_code or not line:
            continue
        if re.match(r"^#{1,6}\s+", line):
            line = re.sub(r"^#{1,6}\s+", "", line)
        line = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", line)
        line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
        line = re.sub(r"^[>*\-\s]+", "", line)
        line = re.sub(r"^\d+[.)、]\s*", "", line)
        line = line.replace("**", "").replace("__", "").replace("`", "")
        if line:
            lines.append(line)
    return "\n".join(lines).strip()


def fallback_chunks(text: str, max_chars: int) -> list[dict[str, Any]]:
    normalized = re.sub(r"\s+", " ", text.strip())
    if not normalized:
        return []
    sentences = [part.strip() for part in re.split(r"(?<=[。！？!?；;])\s*", normalized) if part.strip()]
    chunks: list[str] = []
    current = ""
    for sentence in sentences or [normalized]:
        if len(sentence) > max_chars:
            if current:
                chunks.append(current)
                current = ""
            for start in range(0, len(sentence), max_chars):
                chunks.append(sentence[start : start + max_chars].strip())
            continue
        candidate = f"{current}{sentence}"
        if current and len(candidate) > max_chars:
            chunks.append(current)
            current = sentence
        else:
            current = candidate
    if current:
        chunks.append(current)
    return [{"index": idx, "text": chunk, "est_chars": len(chunk)} for idx, chunk in enumerate(chunks)]


def make_tts_safe_text(text: str) -> str:
    safe = text.strip()
    safe = safe.replace("：", "，").replace(":", ",")
    safe = re.sub(r"\b([A-Z]{2,6})\b", lambda m: " ".join(m.group(1)), safe)
    safe = re.sub(r"第([一二三四五六七八九十]+)个风险，是([^。！？!?；;]+)。", r"第\1个风险是\2，", safe)
    safe = re.sub(r"第([一二三四五六七八九十]+)个风险是([^，。！？!?；;]+)，", r"第\1点要注意的是\2风险，", safe)
    safe = re.sub(r"第([一二三四五六七八九十]+)，看([^。！？!?；;]+)。", r"第\1点，我们看\2。", safe)
    safe = re.sub(r"([。！？!?；;])\s+", r"\1", safe)
    return safe


def semantic_chunks(text: str, max_chars: int) -> list[dict[str, Any]]:
    normalized = re.sub(r"\s+", " ", make_tts_safe_text(text).strip())
    if not normalized:
        return []
    sentences = [part.strip() for part in re.split(r"(?<=[。！？!?；;])\s*", normalized) if part.strip()]
    chunks: list[str] = []
    current = ""
    target_chars = max(80, int(max_chars))
    hard_chars = max(target_chars + 80, int(target_chars * 1.6))
    for sentence in sentences:
        # Keep short list-heading-like sentences attached to the following explanation.
        if not current:
            current = sentence
            if len(sentence) < 28 and re.search(r"第[一二三四五六七八九十]+", sentence):
                continue
            if len(sentence) >= target_chars:
                chunks.append(current)
                current = ""
            continue
        candidate = current + sentence
        if len(candidate) <= hard_chars:
            current = candidate
            if len(current) >= target_chars:
                chunks.append(current)
                current = ""
        else:
            chunks.append(current)
            current = sentence
    if current:
        chunks.append(current)
    return [{"index": idx, "text": chunk, "est_chars": len(chunk)} for idx, chunk in enumerate(chunks)]


def plan_chunks(endpoint: str, text: str, max_chars: int, timeout: float) -> list[dict[str, Any]]:
    del endpoint, timeout
    return semantic_chunks(text, max_chars)


def synthesize_chunk(
    endpoint: str,
    chunk: dict[str, Any],
    out_path: Path,
    speaker: str,
    speed: float,
    language: str,
    timeout: float,
) -> dict[str, Any]:
    body, headers = post_json(
        endpoint,
        "/api/tts/speak",
        {
            "text": chunk["text"],
            "speaker": speaker,
            "speed": speed,
            "language": language,
        },
        timeout=timeout,
    )
    out_path.write_bytes(body)
    return {
        "index": chunk["index"],
        "text_path": "",
        "audio_path": str(out_path),
        "chars": len(chunk["text"]),
        "worker_id": headers.get("x-tts-worker-id", ""),
        "audio_seconds": headers.get("x-tts-audio-seconds", ""),
        "elapsed_seconds": headers.get("x-tts-elapsed-seconds", ""),
        "rtf": headers.get("x-tts-rtf", ""),
        "speaker": headers.get("x-tts-speaker", speaker),
    }


def read_wav(path: Path) -> tuple[wave._wave_params, bytes]:
    with wave.open(str(path), "rb") as reader:
        params = reader.getparams()
        frames = reader.readframes(reader.getnframes())
    return params, frames


def pcm16_rms(frames: bytes, sample_width: int) -> float:
    if sample_width != 2 or not frames:
        return 0.0
    count = len(frames) // 2
    total = 0
    for idx in range(0, len(frames) - 1, 2):
        value = int.from_bytes(frames[idx : idx + 2], "little", signed=True)
        total += value * value
    return (total / max(1, count)) ** 0.5


def wav_quality(path: Path) -> dict[str, Any]:
    params, frames = read_wav(path)
    bytes_per_second = params.framerate * params.nchannels * params.sampwidth
    window_bytes = max(params.nchannels * params.sampwidth, int(bytes_per_second * 0.25))
    windows = [frames[start : start + window_bytes] for start in range(0, len(frames), window_bytes)]
    rms_values = [pcm16_rms(window, params.sampwidth) for window in windows if window]

    trailing_windows = 0
    for value in reversed(rms_values):
        if value < SILENCE_RMS_THRESHOLD:
            trailing_windows += 1
        else:
            break

    longest_silence_windows = 0
    current = 0
    for value in rms_values:
        if value < SILENCE_RMS_THRESHOLD:
            current += 1
            longest_silence_windows = max(longest_silence_windows, current)
        else:
            current = 0

    window_s = window_bytes / bytes_per_second
    duration_s = len(frames) / bytes_per_second if bytes_per_second else 0.0
    trailing_silence_s = trailing_windows * window_s
    longest_silence_s = longest_silence_windows * window_s
    overall_rms = pcm16_rms(frames, params.sampwidth)
    ok = overall_rms >= SILENCE_RMS_THRESHOLD and trailing_silence_s <= 1.0 and longest_silence_s <= 1.5
    return {
        "ok": ok,
        "duration_seconds": duration_s,
        "overall_rms": overall_rms,
        "trailing_silence_seconds": trailing_silence_s,
        "longest_silence_seconds": longest_silence_s,
    }


def trim_wav_silence(input_path: Path, output_path: Path, keep_ms: int = 160) -> None:
    params, frames = read_wav(input_path)
    bytes_per_frame = params.nchannels * params.sampwidth
    bytes_per_second = params.framerate * bytes_per_frame
    window_bytes = max(bytes_per_frame, int(bytes_per_second * 0.05))
    windows = [(start, frames[start : start + window_bytes]) for start in range(0, len(frames), window_bytes)]
    voiced = [idx for idx, (_start, window) in enumerate(windows) if pcm16_rms(window, params.sampwidth) >= SILENCE_RMS_THRESHOLD]
    if not voiced:
        shutil.copyfile(input_path, output_path)
        return
    keep_bytes = int(bytes_per_second * keep_ms / 1000)
    start = max(0, windows[voiced[0]][0] - keep_bytes)
    end = min(len(frames), windows[voiced[-1]][0] + len(windows[voiced[-1]][1]) + keep_bytes)
    with wave.open(str(output_path), "wb") as writer:
        writer.setparams(params)
        writer.writeframes(frames[start:end])


def compatible_wav_params(left: wave._wave_params, right: wave._wave_params) -> bool:
    return (
        left.nchannels == right.nchannels
        and left.sampwidth == right.sampwidth
        and left.framerate == right.framerate
        and left.comptype == right.comptype
        and left.compname == right.compname
    )


def join_wavs(paths: list[Path], output: Path, silence_ms: int) -> dict[str, Any]:
    if not paths:
        raise ValueError("No WAV chunks to join")
    params, first_frames = read_wav(paths[0])
    silence_frames = b"\x00" * int(params.framerate * silence_ms / 1000) * params.nchannels * params.sampwidth
    total_frames = 0
    with wave.open(str(output), "wb") as writer:
        writer.setparams(params)
        for index, path in enumerate(paths):
            current_params, frames = read_wav(path)
            if not compatible_wav_params(current_params, params):
                raise ValueError(f"Incompatible WAV params in {path}")
            if index:
                writer.writeframes(silence_frames)
                total_frames += len(silence_frames) // (params.nchannels * params.sampwidth)
            writer.writeframes(frames)
            total_frames += len(frames) // (params.nchannels * params.sampwidth)
    return {
        "sample_rate": params.framerate,
        "channels": params.nchannels,
        "sample_width": params.sampwidth,
        "duration_seconds": total_frames / params.framerate,
    }


def split_into_subsentences(text: str) -> list[str]:
    raw_parts = [part.strip() for part in re.split(r"(?<=[。！？!?；;，,])\s*", text) if part.strip()]
    parts: list[str] = []
    for part in raw_parts:
        part = part.rstrip("，,")
        if part and part[-1] not in "。！？!?；;":
            part += "。"
        if part:
            parts.append(part)
    return parts or [text.strip()]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Narration script text or Markdown file")
    parser.add_argument("--output-dir", required=True, type=Path, help="Output directory")
    parser.add_argument("--endpoint", default=os.getenv("IVAN_TTS_ENDPOINT", DEFAULT_ENDPOINT))
    parser.add_argument("--speaker", default=os.getenv("IVAN_TTS_SPEAKER", "serena"))
    parser.add_argument("--language", default=os.getenv("IVAN_TTS_LANGUAGE", "Chinese"))
    parser.add_argument("--speed", type=float, default=float(os.getenv("IVAN_TTS_SPEED", "1.0")))
    parser.add_argument("--max-chars", type=int, default=int(os.getenv("NARRATION_TTS_MAX_CHARS", "90")))
    parser.add_argument("--concurrency", type=int, default=int(os.getenv("NARRATION_TTS_CONCURRENCY", "2")))
    parser.add_argument("--join-silence-ms", type=int, default=int(os.getenv("NARRATION_TTS_JOIN_SILENCE_MS", "180")))
    parser.add_argument("--timeout", type=float, default=float(os.getenv("NARRATION_TTS_TIMEOUT", "180")))
    parser.add_argument("--max-retries", type=int, default=int(os.getenv("NARRATION_TTS_MAX_RETRIES", "3")))
    parser.add_argument(
        "--keep-chunks",
        action="store_true",
        default=os.getenv("NARRATION_TTS_KEEP_CHUNKS", "0") == "1",
        help="Keep intermediate text/audio chunks for debugging",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    text = normalize_for_tts(read_text(args.input))
    if not text:
        print("Input text is empty after normalization", file=sys.stderr)
        return 2

    args.output_dir.mkdir(parents=True, exist_ok=True)
    chunks_dir = args.output_dir / "tts_chunks"
    audio_dir = args.output_dir / "audio_chunks"
    chunks_dir.mkdir(exist_ok=True)
    audio_dir.mkdir(exist_ok=True)

    status = ensure_loaded(args.endpoint, args.timeout)
    workers_ready = int(status.get("workers_ready") or len(status.get("workers") or []) or 0)
    if workers_ready < 1:
        print("Ivan TTS has no ready worker", file=sys.stderr)
        return 3

    chunks = plan_chunks(args.endpoint, text, args.max_chars, args.timeout)
    if not chunks:
        print("No TTS chunks produced", file=sys.stderr)
        return 4

    for idx, chunk in enumerate(chunks):
        chunk["index"] = idx
        text_path = chunks_dir / f"chunk_{idx + 1:04d}.txt"
        text_path.write_text(chunk["text"], encoding="utf-8")
        chunk["text_path"] = str(text_path)

    concurrency = max(1, min(int(args.concurrency), max(1, workers_ready)))
    wav_paths = [audio_dir / f"chunk_{idx + 1:04d}.wav" for idx in range(len(chunks))]
    chunk_results: list[dict[str, Any]] = []

    def render_one(item: tuple[dict[str, Any], Path]) -> dict[str, Any]:
        chunk, wav_path = item
        if wav_path.exists() and wav_path.stat().st_size > 44:
            quality = wav_quality(wav_path)
            if quality["ok"]:
                return {
                    "index": chunk["index"],
                    "text_path": chunk["text_path"],
                    "audio_path": str(wav_path),
                    "chars": len(chunk["text"]),
                    "worker_id": "reused",
                    "audio_seconds": f"{quality['duration_seconds']:.6f}",
                    "elapsed_seconds": "",
                    "rtf": "",
                    "speaker": args.speaker,
                    "tts_text": chunk["text"],
                    "retry_count": 0,
                    "quality": quality,
                }

        attempts: list[dict[str, Any]] = []
        candidates = [chunk["text"], make_tts_safe_text(chunk["text"])]
        candidates = list(dict.fromkeys(candidate for candidate in candidates if candidate.strip()))
        last_result: dict[str, Any] | None = None
        last_path = wav_path

        for attempt_idx, candidate in enumerate(candidates[: max(1, args.max_retries)]):
            attempt_path = wav_path if attempt_idx == 0 else wav_path.with_name(f"{wav_path.stem}.retry{attempt_idx}{wav_path.suffix}")
            attempt_chunk = {**chunk, "text": candidate}
            result = synthesize_chunk(
                args.endpoint,
                attempt_chunk,
                attempt_path,
                args.speaker,
                args.speed,
                args.language,
                args.timeout,
            )
            quality = wav_quality(attempt_path)
            attempts.append({"text": candidate, "path": str(attempt_path), "quality": quality})
            last_result = result
            last_path = attempt_path
            if quality["ok"]:
                trim_wav_silence(attempt_path, wav_path)
                final_quality = wav_quality(wav_path)
                result.update(
                    {
                        "text_path": chunk["text_path"],
                        "audio_path": str(wav_path),
                        "tts_text": candidate,
                        "retry_count": attempt_idx,
                        "rewritten": candidate != chunk["text"],
                        "quality": final_quality,
                        "attempts": attempts,
                    }
                )
                return result

        # Last fallback: synthesize sub-sentences separately and stitch them into this chunk.
        sub_texts = split_into_subsentences(make_tts_safe_text(chunk["text"]))
        sub_paths: list[Path] = []
        sub_results: list[dict[str, Any]] = []
        for sub_idx, sub_text in enumerate(sub_texts):
            sub_path = wav_path.with_name(f"{wav_path.stem}.sub{sub_idx + 1}{wav_path.suffix}")
            sub_result = synthesize_chunk(
                args.endpoint,
                {**chunk, "text": sub_text},
                sub_path,
                args.speaker,
                args.speed,
                args.language,
                args.timeout,
            )
            trimmed_sub_path = sub_path.with_name(f"{sub_path.stem}.trimmed{sub_path.suffix}")
            trim_wav_silence(sub_path, trimmed_sub_path)
            shutil.move(trimmed_sub_path, sub_path)
            sub_quality = wav_quality(sub_path)
            if not sub_quality["ok"]:
                raise RuntimeError(
                    f"TTS QA failed for chunk {chunk['index'] + 1} sub {sub_idx + 1}: "
                    f"{sub_quality} text={sub_text}"
                )
            sub_paths.append(sub_path)
            sub_results.append({**sub_result, "tts_text": sub_text, "quality": sub_quality})
        join_wavs(sub_paths, wav_path, max(80, min(args.join_silence_ms, 160)))
        final_quality = wav_quality(wav_path)
        if not final_quality["ok"]:
            # If the joined segment only has natural interior pauses from sub-sentence joins,
            # trim and accept when no long trailing silence remains.
            trimmed = wav_path.with_name(f"{wav_path.stem}.trimmed{wav_path.suffix}")
            trim_wav_silence(wav_path, trimmed)
            shutil.move(trimmed, wav_path)
            final_quality = wav_quality(wav_path)
            if final_quality["trailing_silence_seconds"] > 1.0:
                raise RuntimeError(f"TTS QA failed for chunk {chunk['index'] + 1}: {final_quality}")
        return {
            "index": chunk["index"],
            "text_path": chunk["text_path"],
            "audio_path": str(wav_path),
            "chars": len(chunk["text"]),
            "worker_id": "subsplit",
            "audio_seconds": f"{final_quality['duration_seconds']:.6f}",
            "elapsed_seconds": "",
            "rtf": "",
            "speaker": args.speaker,
            "tts_text": make_tts_safe_text(chunk["text"]),
            "retry_count": len(attempts),
            "rewritten": True,
            "quality": final_quality,
            "attempts": attempts,
            "sub_chunks": sub_results,
            "last_failed_attempt": {"path": str(last_path), "result": last_result},
        }

    if concurrency == 1:
        for item in zip(chunks, wav_paths):
            chunk_results.append(render_one(item))
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
            for result in pool.map(render_one, zip(chunks, wav_paths)):
                chunk_results.append(result)
        chunk_results.sort(key=lambda item: int(item["index"]))

    full_wav = args.output_dir / "narration_full.wav"
    audio_info = join_wavs(wav_paths, full_wav, args.join_silence_ms)
    manifest = {
        "input": str(args.input),
        "endpoint": args.endpoint,
        "speaker": args.speaker,
        "language": args.language,
        "speed": args.speed,
        "workers_ready": workers_ready,
        "concurrency": concurrency,
        "chunk_count": len(chunks),
        "intermediate_retained": bool(args.keep_chunks),
        "join_silence_ms": args.join_silence_ms,
        "full_wav": str(full_wav),
        "audio": audio_info,
        "chunks": chunk_results,
    }
    manifest_path = args.output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    if not args.keep_chunks:
        shutil.rmtree(chunks_dir, ignore_errors=True)
        shutil.rmtree(audio_dir, ignore_errors=True)
    print(json.dumps({"manifest": str(manifest_path), "full_wav": str(full_wav), "chunk_count": len(chunks)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
