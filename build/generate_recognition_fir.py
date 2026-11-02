"""Reproduce the checked-in Q16 anti-alias filter. Run with src/pc/.venv Python."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.signal import firwin,freqz
ROOT=Path(__file__).resolve().parent.parent
(ROOT/'build/current').mkdir(parents=True,exist_ok=True)
coeff=np.rint(firwin(127,5000,fs=48000,window=('kaiser',8))*65536).astype(np.int64)
coeff[63]+=65536-int(coeff.sum())
assert coeff.sum()==65536 and np.max(np.abs(coeff))<32768
coeff=np.r_[coeff,0]
encoded=''.join(f'{int(c)&65535:04x}\n' for c in coeff)
path=ROOT/'data/recognition_fir.mem'
if not path.exists() or path.read_text()!=encoded:path.write_text(encoded,encoding='ascii')
freq,response=freqz(coeff/65536,worN=32768,fs=48000)
db=20*np.log10(np.maximum(np.abs(response),1e-20))
result=dict(taps=127,order=126,padded_words=128,input_rate=48000,output_rate=12000,
            design_cutoff_hz=5000,window='Kaiser beta 8',coefficient_fraction_bits=16,
            coefficient_sum=65536,passband_0_to_4000Hz_min_db=float(db[freq<=4000].min()),
            stopband_6000Hz_up_max_db=float(db[freq>=6000].max()),
            coefficient_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
(ROOT/'build/current/recognition_fir_design.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
