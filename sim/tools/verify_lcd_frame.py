"""Check and render the actual RGB pixel stream exported by XSim."""
from pathlib import Path
from PIL import Image
from collections import Counter
import json
import hashlib

root=Path(__file__).resolve().parents[2]
path=root/'build/current/lcd_spectrum.ppm'
image=Image.open(path).convert('RGB')
assert image.size==(1024,600)
counts=Counter(image.get_flattened_data())
expected={(0,255,255):((458,310,502,520),44*210),
          (128,0,255):((714,380,758,520),44*140)}
out={}
for color,(box,area) in expected.items():
    assert counts[color]==area,(color,counts[color],area)
    crop=image.crop(box)
    assert set(crop.get_flattened_data())=={color},color
    out[str(color)]={'bbox':box,'area':area}
image.save(root/'build/current/lcd_spectrum.png')
out['image_size']=image.size
out['source']='XSim RGB output from real FFT + LCD integration; not a physical screen photograph'
out['ppm_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
(root/'build/current/lcd_frame_check.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print(json.dumps(out))
