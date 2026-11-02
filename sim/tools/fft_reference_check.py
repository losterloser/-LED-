"""Independently compare one XSim FFT frame with NumPy's floating-point FFT."""
from pathlib import Path
import json
import numpy as np

root = Path(__file__).resolve().parents[2]
raw = np.array([int(v, 16) for v in (root / 'data/test_tone.mem').read_text().split()], dtype=np.int64)
samples = np.where(raw >= 32768, raw - 65536, raw)
reference = np.fft.fft(samples)
rows = np.genfromtxt(root / 'build/current/fft_first_frame.csv', delimiter=',', skip_header=1)
assert len(samples) == len(rows) == 1024
assert np.array_equal(rows[:, 0], np.arange(1024))
observed = rows[:, 1] + 1j * rows[:, 2]
relative_error = float(np.linalg.norm(observed - reference) / np.linalg.norm(reference))
peaks = (np.argsort(np.abs(observed[1:512]))[-2:] + 1).tolist()
assert set(peaks) == {16, 64}, peaks
assert relative_error < 0.001, relative_error
result = {
    'samples': len(samples), 'fft_points': len(observed),
    'max_complex_error': float(np.max(np.abs(observed - reference))),
    'relative_l2_error': relative_error, 'dominant_positive_bins': peaks,
}
(root / 'build/current/fft_reference_check.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
