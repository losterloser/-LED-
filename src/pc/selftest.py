"""Reproducible checks using synthesized fixtures, not a real-song acceptance test."""
from pathlib import Path
import binascii,json,struct,unittest,tempfile,time,threading
from unittest.mock import patch
import numpy as np
import soundfile as sf
from scipy import signal
from songid import Library,read_audio,FS
from link_protocol import Parser,packet,AUDIO,AUDIO_HEADER,AudioBlock,render_bitmap,overlay_packet
from live import AudioWindow,Session
from test_recognition_tracker import TrackerTests

ROOT=Path(__file__).resolve().parents[2]
REPORT=ROOT/'sim/results/current_pc'
REPORT.mkdir(parents=True,exist_ok=True)


def synthetic(seed,seconds=26,rate=48000):
    rng=np.random.default_rng(seed)
    t=np.arange(int(seconds*rate))/rate
    audio=np.zeros(len(t))
    scale=np.array([0,2,4,5,7,9,11,12,14,16])
    for start in np.arange(0,seconds,.23):
        duration=rng.uniform(.16,.5);f=110*2**(int(rng.choice(scale))/12)
        a=int(start*rate);b=min(len(t),a+int(duration*rate));u=np.arange(b-a)/rate
        env=np.minimum(u/.01,1)*np.exp(-u/rng.uniform(.10,.3))
        audio[a:b]+=.18*env*(np.sin(2*np.pi*f*u)+.45*np.sin(2*np.pi*2*f*u)+.2*np.sin(2*np.pi*3*f*u))
    for start in np.arange(.11,seconds,.37):
        a=int(start*rate);b=min(len(t),a+int(.11*rate));u=np.arange(b-a)/rate
        audio[a:b]+=.06*rng.normal(size=b-a)*np.exp(-u/.018)
    # Independent high melody gives each fixture a distinctive constellation.
    for start in np.arange(.07,seconds,.41):
        a=int(start*rate);b=min(len(t),a+int(.24*rate));u=np.arange(b-a)/rate
        f=440*2**(int(rng.choice(scale))/12)
        audio[a:b]+=.14*np.sin(2*np.pi*f*u)*np.sin(np.pi*np.minimum(u/.24,1))**2
    return audio.astype(np.float32)


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=tempfile.TemporaryDirectory();cls.dir=Path(cls.tmp.name)
        cls.db=Library(cls.dir/'test.sqlite3');cls.rate=48000
        cls.audio=[synthetic(20+k) for k in range(3)]
        for k,a in enumerate(cls.audio):
            path=cls.dir/f'fixture{k}.wav';sf.write(path,a,cls.rate,subtype='PCM_16')
            cls.db.add(path,f'测试旋律{k+1}',f'测试演奏者{k+1}')
        cls.evidence=[]

    @classmethod
    def tearDownClass(cls):
        cls.db.close();cls.tmp.cleanup()
        (REPORT/'recognizer_python_results.json').write_text(json.dumps(cls.evidence,ensure_ascii=False,indent=2),encoding='utf-8')

    def check_query(self,label,a,rate,expected=None):
        r=self.db.query(a,rate)
        self.evidence.append(dict(case=label,**r.to_dict()))
        print(label,r.to_dict(),flush=True)
        self.assertEqual(r.recognized,expected is not None)
        if expected is not None:
            self.assertEqual(r.title,f'测试旋律{expected+1}')
            self.assertEqual(r.artist,f'测试演奏者{expected+1}')

    def test_01_excerpt(self):
        for k,a in enumerate(self.audio):
            start=int((5.137+k*.723)*self.rate)
            self.check_query(f'excerpt{k}',a[start:start+8*self.rate],self.rate,k)

    def test_02_gain_noise(self):
        a=self.audio[1][int(8.783*self.rate):int(16.783*self.rate)]
        rng=np.random.default_rng(123)
        quiet=.12*a+rng.normal(0,.002,len(a))
        self.check_query('gain_0.12_with_noise',quiet,self.rate,1)

    def test_03_resampling(self):
        a=self.audio[2][int(10.037*self.rate):int(18.037*self.rate)]
        self.check_query('44100Hz',signal.resample_poly(a,147,160),44100,2)
        self.check_query('12000Hz_uart',signal.resample_poly(a,1,4),12000,2)

    def test_04_negative(self):
        self.check_query('silence',np.zeros(8*self.rate),self.rate)
        self.check_query('unregistered_fixture',synthetic(999,8),self.rate)
        self.check_query('white_noise',np.random.default_rng(7).normal(0,.03,8*self.rate),self.rate)
        self.check_query('single_tone',.1*np.sin(2*np.pi*750*np.arange(8*self.rate)/self.rate),self.rate)

    def test_05_echo(self):
        a=self.audio[0][int(7.147*self.rate):int(15.147*self.rate)].copy()
        echo=np.zeros_like(a);delay=int(.032*self.rate);echo[delay:]=a[:-delay]*.22
        self.check_query('short_echo',a+echo,self.rate,0)

    def test_06_ambiguity(self):
        path=self.dir/'same_recording_quieter.wav';sf.write(path,.8*self.audio[0],self.rate,subtype='PCM_16')
        db=Library(self.dir/'ambiguous.sqlite3')
        try:
            p=self.dir/'fixture0.wav';db.add(p,'候选一','甲');db.add(path,'候选二','乙')
            result=db.query(self.audio[0][6*self.rate:14*self.rate],self.rate)
            self.evidence.append(dict(case='ambiguous_duplicate',**result.to_dict()))
            self.assertFalse(result.recognized)
        finally:db.close()

    def test_07_protocol(self):
        self.assertEqual(binascii.crc_hqx(b'123456789',0xffff),0x29b1)
        pcm=np.arange(128,dtype='<i2')-64
        payload=AUDIO_HEADER.pack(2,7,12000,0,0,123)+pcm.tobytes()
        first=packet(AUDIO,0,payload);bad=bytearray(first);bad[44]^=1
        parser=Parser();frames=[]
        stream=b'garbage\xa5'+bytes(bad)+first+packet(AUDIO,1,payload)
        for i in range(0,len(stream),7):frames.extend(parser.feed(stream[i:i+7]))
        self.assertEqual(len(frames),2);self.assertGreaterEqual(parser.bad_crc,1)
        block=AudioBlock.decode(frames[0][1],frames[0][2]);np.testing.assert_array_equal(block.samples,pcm)
        self.assertEqual(block.display_ack,123)
        self.assertLess(len(parser.buffer),2)

    def test_08_gap_reset(self):
        w=AudioWindow()
        def b(seq,index,epoch=4,mode=2,dropped=0):
            return AudioBlock(seq,mode,epoch,12000,index,dropped,0,np.ones(128,dtype=np.int16))
        w.append(b(0,0));w.append(b(1,128));self.assertEqual(len(w.snapshot()['samples']),256)
        w.append(b(3,384));self.assertEqual(len(w.snapshot()['samples']),128)
        w.append(b(4,512,epoch=5));self.assertEqual(len(w.snapshot()['samples']),128)
        w.append(b(5,640,epoch=5,dropped=512));self.assertEqual(len(w.snapshot()['samples']),128)
        self.assertEqual(w.gaps,3)

    def test_09_chinese_overlay(self):
        image,bitmap=render_bitmap('示例歌曲名称','示例演唱者')
        self.assertEqual(len(bitmap),7680);self.assertGreater(sum(bitmap),0)
        image.resize((960,64)).save(REPORT/'song_text_preview.png')
        frame=overlay_packet(17,2,5,bitmap)
        self.assertEqual(Parser().feed(frame),[(0x20,17,struct.pack('<BH',2,5)+bitmap)])
        # A vector generated by the real host encoder is consumed by RTL simulation.
        (ROOT/'data/overlay_test_packet.mem').write_text(''.join(f'{b:02x}\n' for b in frame),encoding='ascii')

    def test_10_single_song_library_negatives(self):
        db=Library(self.dir/'one_song.sqlite3')
        try:
            db.add(self.dir/'fixture0.wav','测试旋律1','测试演奏者1')
            for seed in range(100,120):
                result=db.query(synthetic(seed,8),self.rate)
                self.assertFalse(result.recognized,f'Unknown fixture {seed} was incorrectly recognized: {result}')
            self.evidence.append(dict(case='20_unknowns_against_single_song_library',false_accepts=0,queries=20))
        finally:db.close()

    def test_11_filtered_transport_recognition(self):
        # Bit-exact integer filter model is separately cross-checked against RTL.
        coef=np.array([int(s,16) for s in (ROOT/'data/recognition_fir.mem').read_text().split()],dtype=np.int64)
        coef=np.where(coef>=32768,coef-65536,coef)
        start=int(6.133*self.rate)
        pcm=np.rint(self.audio[1][start:start+int(8.1*self.rate)]*32768).astype(np.int64)
        filtered=(np.convolve(pcm,coef)[:len(pcm)][127::4]>>16).clip(-32768,32767).astype('<i2')
        parser=Parser();window=AudioWindow()
        for seq,index in enumerate(range(0,len(filtered)-127,128)):
            raw=packet(AUDIO,seq,AUDIO_HEADER.pack(2,12,12000,index,0,17)+filtered[index:index+128].tobytes())
            for cut in range(0,len(raw),29):
                for _,n,payload in parser.feed(raw[cut:cut+29]):window.append(AudioBlock.decode(n,payload))
        snap=window.snapshot();result=self.db.query(snap['samples'],snap['rate'])
        self.assertEqual(len(snap['samples']),8*12000);self.assertEqual(snap['gaps'],0)
        self.assertTrue(result.recognized);self.assertEqual(result.title,'测试旋律2')
        self.assertEqual(result.artist,'测试演奏者2')
        image,_=render_bitmap(result.title,result.artist)
        image.save(REPORT/'recognized_synthetic_fixture.png')
        self.evidence.append(dict(case='integer_FIR_to_framed_UART_model_to_PC_query',**result.to_dict()))

    def test_12_live_threads_without_hardware(self):
        db_path=self.dir/'live.sqlite3';db=Library(db_path)
        db.add(self.dir/'fixture1.wav','测试旋律2','测试演奏者2');db.close()
        a=signal.resample_poly(self.audio[1],1,4)
        clip=np.rint(a[2*12000:2*12000+98304]*32768).astype('<i2')
        class FakeSerial:
            def __init__(self):self.seq=0;self.index=0;self.ack=65535;self.writes=[];self.quiet=False;self.silent=False;self.closed=False
            @property
            def in_waiting(self):return 282
            def reset_input_buffer(self):pass
            def read(self,n):
                time.sleep(.002)
                if self.quiet:return b''
                start=self.index%len(clip);samples=clip[start:start+128]
                if self.silent:samples=np.zeros_like(samples)
                raw=packet(AUDIO,self.seq,AUDIO_HEADER.pack(2,5,12000,self.index,0,self.ack)+samples.tobytes())
                self.seq=(self.seq+1)&65535;self.index+=128;return raw
            def write(self,raw):
                frame=Parser().feed(raw);assert len(frame)==1 and frame[0][0]==0x20
                self.ack=frame[0][1];self.writes.append(frame[0]);return len(raw)
            def cancel_read(self):pass
            def close(self):self.closed=True
        transport=FakeSerial();events=[]
        session=Session('SIMULATED_NO_HARDWARE',db_path,events.append,log_directory=self.dir/'logs')
        with patch('live.serial.Serial',return_value=transport):session.start()
        try:
            deadline=time.monotonic()+8
            while time.monotonic()<deadline and not any(e.get('title')=='测试旋律2' for e in events):time.sleep(.05)
            self.assertTrue(any(e.get('title')=='测试旋律2' and e.get('artist')=='测试演奏者2' for e in events),events[-3:])
            self.assertGreater(len(transport.writes),0)
            transport.silent=True
            deadline=time.monotonic()+5
            while time.monotonic()<deadline and not any(e.get('clear_reason')=='silence' for e in events):time.sleep(.05)
            self.assertTrue(any(e.get('clear_reason')=='silence' for e in events),events[-3:])
            time.sleep(1)
            self.assertEqual(events[-1]['title'],'')
            transport.silent=False
            resume_index=len(events);deadline=time.monotonic()+8
            while time.monotonic()<deadline and not any(e.get('title')=='测试旋律2' for e in events[resume_index:]):time.sleep(.05)
            self.assertTrue(any(e.get('title')=='测试旋律2' for e in events[resume_index:]),events[-3:])
            transport.quiet=True;time.sleep(1.6)
            self.assertEqual(events[-1]['title'],'')
            self.assertIn('等待开发板音频数据',events[-1]['status'])
        finally:session.stop()
        self.assertTrue(transport.closed);self.assertFalse(any(t.is_alive() for t in session.threads))
        self.evidence.append(dict(case='mock_serial_live_reader_matcher_writer',recognized=True,
                                 two_query_confirmation=True,disconnect_clears_title=True,physical_hardware=False))

    def test_13_stereo_reference_views(self):
        left,right=synthetic(251),synthetic(252)
        path=self.dir/'stereo_reference.wav'
        sf.write(path,np.column_stack((left,right)),self.rate,subtype='PCM_16')
        db=Library(self.dir/'stereo.sqlite3')
        try:
            track=db.add(path,'立体声测试曲','测试演奏者')
            db.add(self.dir/'fixture0.wav','干扰候选','另一演奏者')
            start=round(6.137*self.rate)
            for label,audio in [('left',left),('right',right),('downmix',(left+right)/2)]:
                result=db.query(audio[start:start+8*self.rate],self.rate)
                self.assertTrue(result.recognized,(label,result));self.assertEqual(result.track_id,track)
            count=db.db.execute('SELECT COUNT(*) FROM fingerprints WHERE track=?',(track,)).fetchone()[0]
            self.assertEqual(db.add(path,'立体声测试曲','测试演奏者'),track)
            self.assertEqual(db.db.execute('SELECT COUNT(*) FROM fingerprints WHERE track=?',(track,)).fetchone()[0],count)
            self.assertFalse(db.query(synthetic(253,8),self.rate).recognized)
            self.evidence.append(dict(case='stereo_downmix_left_right_reference_union',passed=True,
                                     idempotent_reimport=True,match_thresholds_changed=False))
        finally:db.close()

    def test_14_acoustic_unknowns(self):
        for seed in range(300,320):
            result=self.db.query(synthetic(seed,8),self.rate,acoustic=True)
            self.assertFalse(result.recognized,(seed,result))
        self.evidence.append(dict(case='mic_policy_20_unknown_fixtures',false_accepts=0))

    def test_15_acoustic_ambiguity(self):
        path=self.dir/'ambiguous_acoustic.wav'
        sf.write(path,.8*self.audio[0],self.rate,subtype='PCM_16')
        db=Library(self.dir/'ambiguous_acoustic.sqlite3')
        try:
            db.add(self.dir/'fixture0.wav','候选甲','演奏者甲')
            db.add(path,'候选乙','演奏者乙')
            result=db.query(self.audio[0][6*self.rate:14*self.rate],self.rate,acoustic=True)
            self.assertFalse(result.recognized,result)
            self.evidence.append(dict(case='mic_policy_ambiguous_recordings',rejected=True))
        finally:db.close()


def generate_fir_vectors():
    coef=np.array([int(s,16) for s in (ROOT/'data/recognition_fir.mem').read_text().split()],dtype=np.int64)
    coef=np.where(coef>=32768,coef-65536,coef)
    n=np.arange(1024)
    values=np.rint(10000*np.sin(2*np.pi*750*n/48000)+6000*np.sin(2*np.pi*3000*n/48000)+3000*np.sin(2*np.pi*10000*n/48000)).astype(np.int64)
    expected=np.convolve(values,coef)[np.arange(127,1024,4)]>>16
    expected=np.clip(expected,-32768,32767)
    for name,vector in [('fir_input.mem',values),('fir_expected.mem',expected)]:
        (ROOT/'data'/name).write_text(''.join(f'{int(v)&65535:04x}\n' for v in vector),encoding='ascii')

if __name__=='__main__':
    generate_fir_vectors();unittest.main(verbosity=2)
