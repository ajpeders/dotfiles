#!/usr/bin/env python3
"""Stream smoothed FFT bands from the default PulseAudio/PipeWire sink monitor."""

import signal
import subprocess
import sys

import numpy as np


RATE = 48000
SAMPLES = 2048
HOP = 800  # 60 updates per second, retaining the FFT's frequency resolution.
BANDS = 24
EDGES = np.geomspace(45, 8000, BANDS + 1)
FREQUENCIES = np.fft.rfftfreq(SAMPLES, 1 / RATE)
WINDOW = np.hanning(SAMPLES)

# Band centers plus a gentle low-frequency emphasis. Without it the top bars
# (which span a huge linear range and grab broadband air/hiss) dominate and the
# lows barely move, producing a lopsided "only jumping on the right" look.
CENTERS = np.sqrt(EDGES[:-1] * EDGES[1:])
TILT_DB = 8 * np.log10(45.0 / CENTERS)


def spectrum(samples):
    """Return 24 logarithmic bands (0..1) on a fixed, low-emphasised dB scale."""
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

    amplitudes = bands * 2 / WINDOW.sum()
    decibels = 20 * np.log10(np.maximum(amplitudes, 1e-10)) + TILT_DB
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
    smoothed = None
    try:
        frame_bytes = SAMPLES * 2
        pending = bytearray()
        while True:
            chunk = proc.stdout.read(frame_bytes - len(pending))
            if not chunk:
                break
            pending.extend(chunk)
            if len(pending) == frame_bytes:
                bands = spectrum(np.frombuffer(pending, dtype="<i2"))
                if smoothed is None:
                    smoothed = bands
                else:
                    # asymmetric smoothing: quick attack, gentle release
                    rising = bands > smoothed
                    smoothed = np.where(rising,
                                        smoothed * 0.45 + bands * 0.55,
                                        smoothed * 0.88 + bands * 0.12)
                emit(smoothed)
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