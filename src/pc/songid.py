"""Local landmark fingerprinting. Identity metadata comes from the local library.

No network, filename lookup, speech recognition, or third-party music API is used.
Inspired by Wang, ISMIR 2003; this is an independent small-library prototype.
"""
from __future__ import annotations
from collections import defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from math import gcd
import hashlib
import json
import sqlite3
import numpy as np
from scipy import signal, ndimage
import soundfile as sf

FS, FFT, HOP = 12000, 1024, 128
CONFIG = {"algorithm": "navigator-landmarks-v1", "fs": FS, "fft": FFT, "hop": HOP,
          "freq_quant": 2, "max_pair_dt": 90, "fanout": 12}
MATCH_POLICY_VERSION = "navigator-match-v2-mic-guarded"


def read_audio_views(path: str | Path) -> tuple[list[np.ndarray], int]:
    audio, rate = sf.read(str(path), dtype="float32", always_2d=True)
    if not len(audio) or not np.isfinite(audio).all():
        raise ValueError("音频为空或包含无效采样值")
    mono = audio.mean(axis=1)
    # Preserve useful material when stereo channels are almost anti-phase.
    if np.std(mono) < .1 * np.std(audio[:, 0]):
        mono = audio[:, 0]
    # The FPGA streams only the left ADC channel. Keep stereo channel views for
    # enrollment as well as the downmix heard by a microphone. Hash coordinates
    # remain compatible with existing libraries; re-import adds these references.
    views=[mono]
    if audio.shape[1]>1:
        views.extend((audio[:,0],audio[:,1]))
    return views, rate


def read_audio(path: str | Path) -> tuple[np.ndarray, int]:
    views,rate=read_audio_views(path)
    return views[0],rate


def fingerprints(audio: np.ndarray, rate: int) -> list[tuple[int, int]]:
    """Return (hash, anchor_time_in_hops), invariant to excerpt start/gain."""
    audio = np.asarray(audio, dtype=np.float64).reshape(-1)
    if rate < 1000 or not np.isfinite(audio).all():
        raise ValueError("无效音频或采样率")
    if len(audio) < rate * 1.5:
        return []
    audio = audio - audio.mean()
    if np.sqrt(np.mean(audio ** 2)) < 2e-4:
        return []
    if rate != FS:
        div = gcd(int(rate), FS)
        audio = signal.resample_poly(audio, FS // div, int(rate) // div)
    # Bounded chunks avoid allocating an FFT matrix for the entire long song.
    windows = np.lib.stride_tricks.sliding_window_view(audio, FFT)[::HOP]
    win = np.hanning(FFT)
    spectra = np.empty((len(windows), FFT // 2 + 1), np.float32)
    for first in range(0, len(windows), 2048):
        spectra[first:first+2048] = np.abs(np.fft.rfft(windows[first:first+2048] * win))
    db = 20 * np.log10(spectra + 1e-10)
    # Drop DC/sub-bass and frequencies outside the fingerprinting passband.
    db[:, :6] = -200
    db[:, 430:] = -200
    local_max = ndimage.maximum_filter(db, size=(7, 9), mode="constant", cval=-200)
    relative_floor = np.max(db, axis=1, keepdims=True) - 30
    candidates = (db == local_max) & (db >= relative_floor) & (db > db.max()-55)
    # Keep a bounded number per 128 ms time cell, with frequency separation.
    points: list[tuple[int, int]] = []
    for first in range(0, len(db), 12):
        times, freqs = np.nonzero(candidates[first:first+12])
        order = np.argsort(db[first+times, freqs])[::-1]
        kept: list[tuple[int, int]] = []
        for k in order:
            t, f = int(first+times[k]), int(freqs[k])
            if all(abs(t-t0)>3 or abs(f-f0)>8 for t0, f0 in kept):
                kept.append((t, f))
                if len(kept) == 6:
                    break
        points.extend(kept)
    points.sort()
    result = set()
    for i, (t1, f1) in enumerate(points):
        targets = []
        for t2, f2 in points[i+1:]:
            dt = t2-t1
            if dt > CONFIG["max_pair_dt"]:
                break
            if dt >= 4:
                targets.append((t2, f2))
        # Spread targets over time, rather than only the closest dense peaks.
        if len(targets) > CONFIG["fanout"]:
            targets = [targets[k] for k in np.linspace(0, len(targets)-1, CONFIG["fanout"], dtype=int)]
        for t2, f2 in targets:
            key = ((f1//2) << 17) | ((f2//2) << 8) | (t2-t1)
            result.add((key, t1))
    return sorted(result, key=lambda x: x[1])


@dataclass
class Match:
    recognized: bool
    title: str = ""
    artist: str = ""
    track_id: int | None = None
    votes: int = 0
    query_hashes: int = 0
    anchor_count: int = 0
    span_seconds: float = 0
    score: float = 0
    runner_up_votes: int = 0
    offset_seconds: float = 0
    reason: str = "未识别到"
    acceptance_rule: str = "none"
    candidate_track_id: int | None = None
    candidate_title: str = ""
    candidate_artist: str = ""

    def to_dict(self):
        return asdict(self)


class Library:
    def __init__(self, path: str | Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(self.path, timeout=15)
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS tracks(id INTEGER PRIMARY KEY,title TEXT NOT NULL,
              artist TEXT NOT NULL,path TEXT NOT NULL,sha256 TEXT UNIQUE NOT NULL,duration REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS fingerprints(hash INTEGER NOT NULL,track INTEGER NOT NULL,t INTEGER NOT NULL);
            CREATE INDEX IF NOT EXISTS fingerprint_hash ON fingerprints(hash);
        """)
        encoded = json.dumps(CONFIG, sort_keys=True)
        old = self.db.execute("SELECT value FROM meta WHERE key='config'").fetchone()
        if old and old[0] != encoded:
            self.db.close()
            raise ValueError("曲库算法版本不一致，请重新建库")
        self.db.execute("INSERT OR IGNORE INTO meta VALUES('config',?)", (encoded,))
        self.db.commit()

    def close(self):
        self.db.close()

    def tracks(self):
        return self.db.execute("SELECT id,title,artist,path,duration FROM tracks ORDER BY id").fetchall()

    def add(self, path: str | Path, title: str, artist: str) -> int:
        title, artist = title.strip(), artist.strip()
        if not title or not artist:
            raise ValueError("每首歌曲都必须填写歌名和演唱者")
        path = Path(path).resolve()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        views, rate = read_audio_views(path)
        audio=views[0]
        # Union tokens at the same time, rather than counting channel duplicates.
        fp = sorted({token for view in views for token in fingerprints(view,rate)})
        if len(audio) < rate*8 or len(fp) < 50:
            raise ValueError("录入音频至少需要 8 秒，并且有足够的音乐特征")
        existing = self.db.execute("SELECT id FROM tracks WHERE sha256=?", (digest,)).fetchone()
        with self.db:
            if existing:
                track = existing[0]
                self.db.execute("DELETE FROM fingerprints WHERE track=?", (track,))
                self.db.execute("UPDATE tracks SET title=?,artist=?,path=?,duration=? WHERE id=?",
                                (title, artist, str(path), len(audio)/rate, track))
            else:
                track = self.db.execute("INSERT INTO tracks(title,artist,path,sha256,duration) VALUES(?,?,?,?,?)",
                    (title, artist, str(path), digest, len(audio)/rate)).lastrowid
            self.db.executemany("INSERT INTO fingerprints VALUES(?,?,?)", ((h, track, t) for h, t in fp))
        return track

    def query(self, audio: np.ndarray, rate: int, *, acoustic: bool = False) -> Match:
        fp = fingerprints(audio, rate)
        if not fp:
            return Match(False, reason="音频太短、太安静或没有可用特征")
        if not self.tracks():
            return Match(False, query_hashes=len(fp), reason="曲库为空，请先录入歌曲")
        lookup = defaultdict(list)
        keys = sorted({h for h, _ in fp})
        for first in range(0, len(keys), 800):
            chunk = keys[first:first+800]
            for h, track, t in self.db.execute(
                    "SELECT hash,track,t FROM fingerprints WHERE hash IN ("+",".join("?"*len(chunk))+")", chunk):
                lookup[h].append((track, t))
        # Time-offset voting. A token votes at most once in each time cluster.
        offsets = defaultdict(lambda: defaultdict(set))
        for h, tq in fp:
            hits = lookup[h]
            if len(hits) > 200:  # Common repetitive features are not distinctive.
                continue
            for track, tr in hits:
                center = int(round((tr-tq)/3))
                for b in (center-1, center, center+1):
                    offsets[track][b].add((h, tq))
        ranked = []
        for track, bins in offsets.items():
            best_bin, tokens = max(bins.items(), key=lambda p: len(p[1]))
            ranked.append((len(tokens), track, best_bin, tokens))
        ranked.sort(key=lambda p: p[0], reverse=True)
        if not ranked:
            return Match(False, query_hashes=len(fp), reason="未找到一致的音频指纹")
        votes, track, offset_bin, tokens = ranked[0]
        times = sorted({t for _, t in tokens})
        span = (times[-1]-times[0])*HOP/FS if times else 0
        runner = ranked[1][0] if len(ranked)>1 else 0
        score = votes/len(fp)
        # These are prototype thresholds, not calibrated probability estimates.
        strict = votes>=60 and len(times)>=20 and span>=1.5 and score>=.06 and votes>=max(1,runner)*1.6
        # Speaker/room coloration changes many peak pairs even when a strong,
        # long time-offset constellation survives. MIC alone may use this
        # alternative: it needs far more tokens/anchors and a larger winning
        # margin. LINE keeps its original rule. Scores are not probabilities.
        mic_guarded = (acoustic and votes>=150 and len(times)>=80 and span>=5.0
                       and score>=.03 and votes>=max(1,runner)*4.0)
        accepted = strict or mic_guarded
        row = self.db.execute("SELECT title,artist FROM tracks WHERE id=?", (track,)).fetchone()
        return Match(accepted, row[0] if accepted else "", row[1] if accepted else "",
                     track if accepted else None, votes, len(fp), len(times), round(span,3),
                     round(score,4), runner, round(offset_bin*3*HOP/FS,3),
                     "已识别" if accepted else "匹配不足或候选相近，未识别到",
                     "strict" if strict else "mic_guarded" if mic_guarded else "none", track, row[0], row[1])
