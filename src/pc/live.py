"""Continuous serial reader + separate matcher/writer, so FFT work cannot drop UART input."""
from __future__ import annotations
from collections import deque
from pathlib import Path
import queue,threading,time,json
from datetime import datetime,timezone,timedelta
import numpy as np
import serial
from link_protocol import Parser, AudioBlock, AUDIO, render_bitmap, overlay_packet
from songid import Library
from recognition_tracker import RecognitionTracker

WINDOW_SECONDS=8


class AudioWindow:
    """Reset on mode/session/index/sequence/drop discontinuity; never join missing audio."""
    def __init__(self):
        self.lock=threading.Lock()
        self.blocks=deque()
        self.count=0
        self.key=None
        self.rate=12000
        self.next_index=None
        self.next_sequence=None
        self.dropped=None
        self.generation=0
        self.last_time=0.
        self.ack=0xffff
        self.gaps=0

    def append(self,b:AudioBlock,now=None):
        with self.lock:
            key=(b.mode,b.epoch)
            discontinuity=(key!=self.key or
                (self.next_index is not None and b.index!=self.next_index) or
                (self.next_sequence is not None and b.sequence!=self.next_sequence) or
                (self.dropped is not None and b.dropped!=self.dropped))
            if discontinuity:
                if self.key is not None:self.gaps+=1
                self.blocks.clear();self.count=0;self.generation+=1
            self.key=key;self.rate=b.rate
            self.blocks.append(b.samples);self.count+=len(b.samples)
            limit=int((WINDOW_SECONDS+1)*b.rate)
            while self.blocks and self.count-len(self.blocks[0])>=limit:
                self.count-=len(self.blocks.popleft())
            self.next_index=(b.index+len(b.samples))&0xffffffff
            self.next_sequence=(b.sequence+1)&0xffff
            self.dropped=b.dropped;self.ack=b.display_ack
            self.last_time=time.monotonic() if now is None else now
            return discontinuity

    def snapshot(self):
        with self.lock:
            data=np.concatenate(self.blocks) if self.blocks else np.empty(0,dtype=np.int16)
            return dict(key=self.key,generation=self.generation,rate=self.rate,
                        samples=data[-WINDOW_SECONDS*self.rate:].astype(np.float32)/32768,
                        sample_end=self.next_index,
                        age=time.monotonic()-self.last_time,ack=self.ack,gaps=self.gaps,
                        dropped=self.dropped)

    def expire(self):
        with self.lock:
            if self.blocks:
                self.blocks.clear();self.count=0;self.generation+=1


class Session:
    def __init__(self,port,library_path,callback,log_directory=None):
        self.port_name=port;self.library_path=Path(library_path);self.callback=callback
        self.window=AudioWindow();self.parser=Parser();self.stop_event=threading.Event()
        self.commands=queue.Queue(maxsize=1)
        self.serial=None;self.threads=[];self.sequence=0
        self.log_file=None
        self.log_directory=log_directory

    def start(self):
        self.serial=serial.Serial(self.port_name,500000,timeout=.1,write_timeout=1)
        stamp=datetime.now(timezone(timedelta(hours=8))).strftime('%Y%m%d_%H%M%S')
        log_dir=Path(self.log_directory) if self.log_directory else Path(__file__).resolve().parents[2]/'board/runtime'
        log_dir.mkdir(parents=True,exist_ok=True)
        try:self.log_file=(log_dir/f'live_recognition_{stamp}.jsonl').open('a',encoding='utf-8')
        except OSError:
            self.serial.close();raise
        self.serial.reset_input_buffer()
        for function in (self.reader,self.matcher,self.writer):
            t=threading.Thread(target=function,daemon=True);t.start();self.threads.append(t)

    def stop(self):
        self.stop_event.set()
        if self.serial:
            try:self.serial.cancel_read()
            except (AttributeError,OSError,serial.SerialException):pass
        for t in self.threads:
            if t is not threading.current_thread():t.join(timeout=2)
        if self.serial:self.serial.close()
        if self.log_file:self.log_file.close();self.log_file=None

    def fail(self,exc):
        if not self.stop_event.is_set():self.callback(dict(status=f'连接错误：{exc}',title='',artist=''))
        self.stop_event.set()

    def reader(self):
        try:
            while not self.stop_event.is_set():
                data=self.serial.read(max(1,min(self.serial.in_waiting,8192)))
                for kind,seq,payload in self.parser.feed(data):
                    if kind==AUDIO:
                        try:b=AudioBlock.decode(seq,payload)
                        except ValueError:continue
                        self.window.append(b)
        except (OSError,serial.SerialException) as e:self.fail(e)

    def writer(self):
        try:
            while not self.stop_event.is_set():
                try:command=self.commands.get(timeout=.1)
                except queue.Empty:continue
                # Match result may have become stale while queued for transmission.
                snap=self.window.snapshot()
                if snap['key']!=command['key'] or snap['generation']!=command['generation']:continue
                mode,epoch=command['key']
                _,bits=render_bitmap(command['title'],command['artist'],command['status'])
                self.serial.write(overlay_packet(self.sequence,mode,epoch,bits))
                self.sequence=(self.sequence+1)%65535 # 0xffff reserved for no display ACK.
        except (OSError,serial.SerialException,ValueError) as e:self.fail(e)

    def publish(self,snap,status,title='',artist='',**extra):
        event=dict(status=status,title=title,artist=artist,key=snap['key'],
                   generation=snap['generation'],gaps=snap['gaps'],bad_crc=self.parser.bad_crc,
                   dropped=snap['dropped'],display_ack=snap['ack'],sample_end=snap.get('sample_end'),
                   port=self.port_name,**extra)
        self.callback(event)
        if self.log_file:
            record=dict(event,time=datetime.now(timezone(timedelta(hours=8))).isoformat(timespec='milliseconds'))
            self.log_file.write(json.dumps(record,ensure_ascii=False)+'\n');self.log_file.flush()
        if snap['key'] is not None:
            try:self.commands.put_nowait(event)
            except queue.Full:
                try:self.commands.get_nowait()
                except queue.Empty:pass
                try:self.commands.put_nowait(event)
                except queue.Full:pass

    def matcher(self):
        db=None
        tracker=RecognitionTracker()
        last_query=0.;last_generation=-1
        try:
            db=Library(self.library_path)
            while not self.stop_event.wait(.5):
                snap=self.window.snapshot()
                if snap['generation']!=last_generation:
                    tracker.reset();last_query=0
                    last_generation=snap['generation']
                if snap['age']>1.:
                    self.window.expire()
                    tracker.reset()
                    self.publish(snap,'等待开发板音频数据','', '检查板端程序、USB UART 连接和 P5 跳帽')
                    continue
                if snap['key'][0]==0:
                    tracker.reset()
                    self.publish(snap,'ROM 测试模式','', '按 PL_KEY0 选择 MIC 或 LINE IN 后识曲')
                    continue
                if len(snap['samples'])<WINDOW_SECONDS*snap['rate']:
                    seconds=len(snap['samples'])/snap['rate']
                    self.publish(snap,f'正在采样 {seconds:.1f} / {WINDOW_SECONDS} 秒','', '播放已经录入曲库的歌曲')
                    continue
                now=time.monotonic()
                tail=snap['samples'][-max(1,snap['rate']//2):]
                tail_rms=float(np.sqrt(np.mean(tail.astype(np.float64)**2)))
                if tracker.quiet(tail_rms,now):
                    # Remove the old song's samples as well as its title so
                    # a paused stream cannot immediately reacquire stale music.
                    self.window.expire();snap=self.window.snapshot()
                    tracker.reset();last_generation=snap['generation'];last_query=0
                    self.publish(snap,'未识别到','','检测到停声，等待音乐',
                                 recognition_state='silence',clear_reason='silence')
                    continue
                if now-last_query>=2.:
                    result=db.query(snap['samples'],snap['rate'],acoustic=snap['key'][0]==1);last_query=now
                    current=self.window.snapshot()
                    if current['key']!=snap['key'] or current['generation']!=snap['generation'] or current['age']>1:continue
                    rms=float(np.sqrt(np.mean(snap['samples'].astype(np.float64)**2)))
                    tracker.update(result,time.monotonic(),snap['sample_end'],snap['rate'],rms,
                                   acoustic=snap['key'][0]==1)
                decision=tracker.view(time.monotonic())
                self.publish(snap,**decision)
        except Exception as e:self.fail(e)
        finally:
            if db:db.close()
