"""Decode bytes sampled by RTL UART RX using the production PC decoder."""
from pathlib import Path
import sys,json
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'src/pc'))
from link_protocol import Parser,AudioBlock

raw=bytes(int(x,16) for x in (ROOT/'build/current/pcm_uart_capture.hex').read_text().split())
parser=Parser();frames=parser.feed(raw)
assert len(frames)==4 and parser.bad_crc==0 and not parser.buffer
blocks=[AudioBlock.decode(seq,b) for _,seq,b in frames]
assert [b.sequence for b in blocks]==[0,1,2,0]
assert [b.mode for b in blocks]==[2,2,2,1]
assert [b.epoch for b in blocks]==[0,0,0,1]
assert [b.index for b in blocks]==[0,128,256,0]
assert all(b.display_ack==4660 and b.dropped==0 for b in blocks)
np.testing.assert_array_equal(np.concatenate([b.samples for b in blocks[:3]]),np.arange(384)*97-23000)
np.testing.assert_array_equal(blocks[3].samples,12000-np.arange(128)*47)
result=dict(passed=True,bytes=len(raw),packets=len(frames),crc_errors=parser.bad_crc,
            all_samples_bit_exact=True,mode_epoch_reset_verified=True)
(ROOT/'build/current/uart_host_crosscheck.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result))
