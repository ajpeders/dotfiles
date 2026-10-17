"""Run with: python3 -m unittest discover -s jetshell/tests."""

import importlib.util
from pathlib import Path
import unittest

import numpy as np


spec = importlib.util.spec_from_file_location(
    "visualizer", Path(__file__).resolve().parents[1] / "audio-visualizer.py"
)
visualizer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(visualizer)


class SpectrumTests(unittest.TestCase):
    def test_silence(self):
        np.testing.assert_array_equal(
            visualizer.spectrum(np.zeros(visualizer.SAMPLES)), np.zeros(visualizer.BANDS)
        )

    def test_bands_have_distinct_bins(self):
        self.assertTrue(np.all(np.diff(visualizer.BIN_EDGES) > 0))
        self.assertGreaterEqual(visualizer.BIN_EDGES[0], 1)
        self.assertLessEqual(visualizer.BIN_EDGES[-1], visualizer.SAMPLES // 2 + 1)

    def test_quiet_tones_are_visible_across_the_spectrum(self):
        time = np.arange(visualizer.SAMPLES) / visualizer.RATE
        for frequency in (30, 70.3125, 250, 1000, 4000, 7000, 12000, 18000):
            with self.subTest(frequency=frequency):
                peaks = []
                for db in (-60, -40, -20):
                    samples = np.rint(
                        32767 * 10 ** (db / 20) * np.sin(2 * np.pi * frequency * time)
                    ).astype(np.int16)
                    bands = visualizer.spectrum(samples)
                    self.assertEqual(bands.shape, (visualizer.BANDS,))
                    self.assertTrue(np.all(np.isfinite(bands)))
                    self.assertTrue(np.all((bands >= 0) & (bands <= 1)))
                    peaks.append(bands.max())
                self.assertGreater(peaks[0], 0.05)
                self.assertGreater(peaks[1], 0.3)
                self.assertTrue(np.all(np.diff(peaks) > 0))

    def test_invalid_frame_size(self):
        with self.assertRaises(ValueError):
            visualizer.spectrum(np.zeros(12))

    def test_faint_detail(self):
        time = np.arange(visualizer.SAMPLES) / visualizer.RATE
        samples = np.rint(32767 * 10 ** (-70 / 20) * np.sin(2 * np.pi * 1000 * time)).astype(np.int16)
        self.assertGreater(visualizer.spectrum(samples).max(), 0.1)

    def test_out_of_phase_stereo_does_not_cancel(self):
        time = np.arange(visualizer.SAMPLES) / visualizer.RATE
        samples = np.rint(1000 * np.sin(2 * np.pi * 1000 * time)).astype(np.int16)
        stereo = np.column_stack((samples, -samples))
        np.testing.assert_allclose(visualizer.spectrum(stereo), visualizer.spectrum(samples))

    def test_sound_in_either_channel_is_visible(self):
        time = np.arange(visualizer.SAMPLES) / visualizer.RATE
        samples = np.rint(1000 * np.sin(2 * np.pi * 1000 * time)).astype(np.int16)
        silence = np.zeros_like(samples)
        for stereo in (np.column_stack((samples, silence)), np.column_stack((silence, samples))):
            self.assertGreater(visualizer.spectrum(stereo).max(), 0.3)


if __name__ == "__main__":
    unittest.main()
