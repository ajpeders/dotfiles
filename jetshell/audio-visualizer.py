#!/usr/bin/env python3
"""Stream smoothed FFT bands from the default PulseAudio/PipeWire sink monitor."""

import signal
import subprocess
import sys

import numpy as np


RATE = 48000
SAMPLES = 2048
CHANNELS = 2
HOP = 800  # 60 updates per second, retaining the FFT's frequency resolution.
BANDS = 24
EDGES = np.geomspace(20, 20000, BANDS + 1)
WINDOW = np.hanning(SAMPLES)
# Each band needs at least one distinct FFT bin. At this window size the
# narrowest logarithmic bands otherwise reuse the same low-frequency bin.
BIN_EDGES = np.rint(EDGES * SAMPLES / RATE).astype(int)
for index in range(1, len(BIN_EDGES)):
    BIN_EDGES[index] = max(BIN_EDGES[index], BIN_EDGES[index - 1] + 1)
POWER_SCALE = 2 / (SAMPLES * np.sum(WINDOW ** 2))


def spectrum(samples):
    """Return 24 non-overlapping bands (0..1), scaled from -84 to -12 dBFS."""
    audio = np.asarray(samples, dtype=np.float64) / 32768.0
    if len(audio) != SAMPLES:
        raise ValueError(f"expected {SAMPLES} samples")
    if audio.ndim == 1:
        audio = audio[:, None]
    if audio.ndim != 2 or audio.shape[1] not in (1, CHANNELS):
        raise ValueError("expected mono or stereo audio")
    if np.max(np.abs(audio)) < 1e-4:
        return np.zeros(BANDS)

    # Combine channel energy, not waveforms: a mono downmix can cancel
    # out-of-phase stereo details before the FFT ever sees them.
    magnitudes = np.abs(np.fft.rfft(audio * WINDOW[:, None], axis=0))
    powers = np.mean(magnitudes ** 2, axis=1)
    # Integrate energy rather than averaging magnitudes: wide treble bands
    # must not dilute a tone just because they contain more FFT bins.
    bands = np.array([np.sum(powers[start:stop])
                      for start, stop in zip(BIN_EDGES[:-1], BIN_EDGES[1:])])
    decibels = 10 * np.log10(np.maximum(bands * POWER_SCALE, 1e-12))
    return np.clip((decibels + 84) / 72, 0, 1)


def emit(bands):
    print(" ".join(f"{value:.3f}" for value in bands), flush=True)


def stop(_signum, _frame):
    raise KeyboardInterrupt


def main():
    signal.signal(signal.SIGTERM, stop)
    proc = subprocess.Popen(
        ["parec", "--device=@DEFAULT_MONITOR@", "--format=s16le",
         "--rate=48000", f"--channels={CHANNELS}", "--latency-msec=16"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    smoothed = None
    try:
        frame_bytes = SAMPLES * CHANNELS * 2
        pending = bytearray()
        while True:
            chunk = proc.stdout.read(frame_bytes - len(pending))
            if not chunk:
                break
            pending.extend(chunk)
            if len(pending) == frame_bytes:
                bands = spectrum(np.frombuffer(pending, dtype="<i2").reshape(SAMPLES, CHANNELS))
                if smoothed is None:
                    smoothed = bands
                else:
                    # asymmetric smoothing: quick attack, gentle release
                    rising = bands > smoothed
                    smoothed = np.where(rising,
                                        smoothed * 0.45 + bands * 0.55,
                                        smoothed * 0.88 + bands * 0.12)
                emit(smoothed)
                del pending[:HOP * CHANNELS * 2]
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
