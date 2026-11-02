"""Byte framing shared with the FPGA; serial reads may split anywhere."""
from __future__ import annotations
from dataclasses import dataclass
import binascii
import struct
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

MAGIC=b'\xa5\x5a'
AUDIO, OVERLAY=1,0x20
MAX_PAYLOAD=8192
AUDIO_HEADER=struct.Struct('<BHIIIH')
WIDTH, HEIGHT=960,64


def packet(kind: int, sequence: int, payload: bytes) -> bytes:
    if not 0<=len(payload)<=MAX_PAYLOAD:
        raise ValueError('数据包过长')
    body=struct.pack('<BHH', kind,len(payload),sequence&0xffff)+payload
    return MAGIC+body+struct.pack('<H',binascii.crc_hqx(body,0xffff))


class Parser:
    def __init__(self):
        self.buffer=bytearray()
        self.bad_crc=0
        self.discarded=0

    def feed(self,data: bytes):
        self.buffer.extend(data)
        frames=[]
        while True:
            start=self.buffer.find(MAGIC)
            if start<0:
                keep=1 if self.buffer[-1:]==MAGIC[:1] else 0
                self.discarded+=len(self.buffer)-keep
                self.buffer[:]=self.buffer[-keep:] if keep else b''
                break
            if start:
                self.discarded+=start
                del self.buffer[:start]
            if len(self.buffer)<7:
                break
            kind,size,seq=struct.unpack_from('<BHH',self.buffer,2)
            if size>MAX_PAYLOAD or kind not in (AUDIO,OVERLAY):
                del self.buffer[0];self.discarded+=1
                continue
            total=size+9
            if len(self.buffer)<total:
                break
            expected=struct.unpack_from('<H',self.buffer,total-2)[0]
            actual=binascii.crc_hqx(self.buffer[2:total-2],0xffff)
            if expected!=actual:
                del self.buffer[0];self.bad_crc+=1
                continue
            frames.append((kind,seq,bytes(self.buffer[7:total-2])))
            del self.buffer[:total]
        return frames


@dataclass
class AudioBlock:
    sequence:int
    mode:int
    epoch:int
    rate:int
    index:int
    dropped:int
    display_ack:int
    samples:np.ndarray

    @classmethod
    def decode(cls,sequence,payload):
        if len(payload)!=273:
            raise ValueError('PCM 数据包长度不正确')
        mode,epoch,rate,index,dropped,ack=AUDIO_HEADER.unpack_from(payload)
        if mode not in (0,1,2) or rate!=12000:
            raise ValueError('PCM 模式或采样率不正确')
        return cls(sequence,mode,epoch,rate,index,dropped,ack,
                   np.frombuffer(payload, dtype='<i2', offset=AUDIO_HEADER.size).copy())


def render_bitmap(title:str,artist:str,status:str='已识别',font_path:str|None=None):
    font_path=font_path or str(Path('C:/Windows/Fonts/msyh.ttc'))
    if not Path(font_path).is_file():
        raise FileNotFoundError('缺少中文字体，请指定 font_path')
    font=ImageFont.truetype(font_path,24)
    image=Image.new('1',(WIDTH,HEIGHT),0)
    draw=ImageDraw.Draw(image)
    def fit(text):
        while draw.textlength(text,font=font)>WIDTH-12:
            text=text[:-2]+'…' if len(text)>2 else ''
        return text
    lines=(f'歌名：{title}',f'演唱者：{artist}') if title else (status,artist)
    for y,text in zip((0,32),lines):
        draw.text((4,y),fit(text),font=font,fill=1,stroke_width=0)
    # PIL mode 1 is MSB first, row-major: exactly 120 bytes per row.
    return image,image.tobytes()


def overlay_packet(sequence,mode,epoch,bitmap):
    if len(bitmap)!=7680:
        raise ValueError('文字位图必须为 960×64 单色')
    return packet(OVERLAY,sequence,struct.pack('<BH',mode,epoch)+bitmap)
