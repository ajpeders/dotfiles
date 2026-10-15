#!/usr/bin/env python3
"""Stream FFT bands from the default PulseAudio/PipeWire sink monitor."""

import signal
import subprocess
import sys

import numpy as np


RATE = 48000
SAMPLES = 2048
HOP = 800  # 60 updates per second, retaining the FFT's frequency resolution.
BANDS = 24
EDGES = np.geomspace(40, 16000, BANDS + 1)
FREQUENCIES = np.fft.rfftfreq(SAMPLES, 1 / RATE)
WINDOW = np.hanning(SAMPLES)


def spectrum(samples):
    """Return 24 logarithmic bands on a fixed decibel scale."""
    audio = np.asarray(samples, dtype=np.float64) / 32768.0
    if len(audio) != SAMPLES:
        raise ValueError(f"expected {SAMPLES} samples")
    if np.max(np.abs(audio)) < 1e-4:
        return np.zeros(BANDS)

    magnitudes = np.abs(np.fft.rfft(audio * WINDOW))
    bands = np.empty(BANDS)
    for index, (low, high) in enumerate(zip(EDGES[:-1], EDGES[1:])):
        start = np.searchsorted(FREQUENCIES, low, side="left")
        stop = np.searchsorted(FREQUENCIES, high, side="left")
        if stop <= start:
            start = min(np.searchsorted(FREQUENCIES, (low + high) / 2), len(magnitudes) - 1)
            stop = start + 1
        bands[index] = np.mean(magnitudes[start:stop])

    # A fixed dB range keeps quiet detail visible without forcing every
    # frame's loudest bar to full height (including near-silent noise).
    amplitudes = bands * 2 / WINDOW.sum()
    decibels = 20 * np.log10(np.maximum(amplitudes, 1e-10))
    return np.clip((decibels + 65) / 55, 0, 1)


def emit(bands):
    print(" ".join(f"{value:.3f}" for value in bands), flush=True)


def stop(_signum, _frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, stop)
    proc = subprocess.Popen(
        ["parec", "--device=@DEFAULT_MONITOR@", "--format=s16le",
         "--rate=48000", "--channels=1", "--latency-msec=16"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    try:
        frame_bytes = SAMPLES * 2
        pending = bytearray()
        while True:
            chunk = proc.stdout.read(frame_bytes - len(pending))
            if not chunk:
                break
            pending.extend(chunk)
            if len(pending) == frame_bytes:
                emit(spectrum(np.frombuffer(pending, dtype="<i2")))
                del pending[:HOP * 2]
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        proc.stdout.close()
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
        else:
            proc.wait()


if __name__ == "__main__":
    try:
        main()
    except FileNotFoundError as error:
        print(f"audio visualizer: {error}", file=sys.stderr)
        sys.exit(1)
