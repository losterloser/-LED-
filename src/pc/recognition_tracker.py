"""Keep an established identity only with recent or time-consistent evidence."""
from __future__ import annotations
from dataclasses import replace
from songid import Match

DISPLAY_POLICY_VERSION = 'navigator-display-v3-mic-temporal-acquisition'


class RecognitionTracker:
    CONFIRMATIONS = 2
    HOLD_SECONDS = 6.0
    OFFSET_TOLERANCE_SECONDS = .35
    QUIET_SECONDS = 2.0
    QUIET_LEVEL_RATIO = .20
    QUIET_RMS_CEILING = .002

    def __init__(self):
        self.reset()

    def reset(self):
        self.active = None
        self.pending_id = None
        self.confirmations = 0
        self.last_result = None
        self.last_support_at = float('-inf')
        self.last_offset = None
        self.last_sample_end = None
        self.reference_rms = None
        self.quiet_since = None
        self.evidence = 'none'
        self.last_update_supported = False
        self.support_updates = 0
        self.weak_pending = None
        self.temporal_pending = []

    def _expire(self, now):
        if self.temporal_pending and now-self.temporal_pending[-1][3] > self.HOLD_SECONDS:
            self.temporal_pending = []
        if self.active is not None and now-self.last_support_at >= self.HOLD_SECONDS:
            self.active = None
            self.last_offset = None
            self.last_sample_end = None
            self.reference_rms = None
            self.quiet_since = None
            self.evidence = 'none'
            self.last_update_supported = False
            self.support_updates = 0
            self.weak_pending = None

    def _support(self, result, now, sample_end, rms, evidence):
        self.last_support_at = now
        self.last_offset = result.offset_seconds
        self.last_sample_end = sample_end
        self.evidence = evidence
        self.last_update_supported = True
        self.support_updates += 1
        # A stale 8-second window must not lower the silence threshold after
        # the recent samples have already gone quiet.
        if evidence == 'confirmed' and self.quiet_since is None and rms > 0:
            self.reference_rms = (rms if self.reference_rms is None
                                  else .8*self.reference_rms+.2*rms)

    def update(self, result: Match, now, sample_end, rate, rms, *, acoustic):
        self._expire(now)
        self.last_result = result
        self.last_update_supported = False
        if result.recognized:
            self.weak_pending = None
            self.temporal_pending = []
            if self.active is not None and result.track_id == self.active.track_id:
                self.active = result
                self.pending_id = None
                self.confirmations = 0
                self._support(result, now, sample_end, rms, 'confirmed')
            else:
                self.confirmations = self.confirmations+1 if result.track_id == self.pending_id else 1
                self.pending_id = result.track_id
                if self.confirmations >= self.CONFIRMATIONS:
                    self.active = result
                    self.pending_id = None
                    self.confirmations = 0
                    self.reference_rms = None
                    self.support_updates = 0
                    self.quiet_since = None
                    self._support(result, now, sample_end, rms, 'confirmed')
            return
        self.pending_id = None
        self.confirmations = 0
        if self.active is None:
            self._temporal_acquisition(result,now,sample_end,rate,rms,acoustic)
            return
        # This can maintain an already confirmed MIC identity; it cannot
        # create a new identity, change songs, or apply to LINE IN.
        same_candidate = (self.active is not None and
                          result.candidate_track_id == self.active.track_id)
        enough = (result.votes >= 80 and result.anchor_count >= 45 and
                  result.span_seconds >= 4.5 and result.score >= .018 and
                  result.votes >= max(1, result.runner_up_votes)*3.0)
        consistent = False
        if acoustic and same_candidate and self.last_sample_end is not None:
            advanced = ((sample_end-self.last_sample_end) & 0xffffffff)/rate
            progress = result.offset_seconds-self.last_offset
            consistent = 0 < advanced <= self.HOLD_SECONDS and abs(progress-advanced) <= self.OFFSET_TOLERANCE_SECONDS
            if enough and consistent:
                self.weak_pending = None
                self._support(result, now, sample_end, rms, 'tracking')
                return
        # A weaker match can only maintain a well-established MIC identity.
        # Require two consecutive high-margin constellations with mutually
        # consistent audio-clock and song-offset progression. Never acquire,
        # change songs or extend the hold with a frozen sample counter.
        paired_enough = (result.votes >= 50 and result.anchor_count >= 30 and
                         result.span_seconds >= 5.0 and result.score >= .010 and
                         result.votes >= max(1,result.runner_up_votes)*6.0)
        if acoustic and same_candidate and consistent and paired_enough and self.support_updates >= 3:
            previous = self.weak_pending
            self.weak_pending = (sample_end,result.offset_seconds)
            if previous is not None:
                delta = ((sample_end-previous[0]) & 0xffffffff)/rate
                if 0 < delta <= self.HOLD_SECONDS and abs((result.offset_seconds-previous[1])-delta) <= self.OFFSET_TOLERANCE_SECONDS:
                    self._support(result, now, sample_end, rms, 'tracking_paired_weak')
        else:
            self.weak_pending = None

    def _temporal_acquisition(self,result,now,sample_end,rate,rms,acoustic):
        # Four overlapping eight-second windows must describe the same
        # candidate progressing through at least six seconds of new audio.
        # The original per-window and LINE IN criteria are unchanged.
        enough = (acoustic and result.candidate_track_id is not None and
                  result.candidate_title and result.candidate_artist and
                  result.votes >= 55 and result.anchor_count >= 35 and
                  result.span_seconds >= 5.0 and result.score >= .012 and
                  result.votes >= max(1,result.runner_up_votes)*6.0)
        if not enough:
            self.temporal_pending = []
            return
        if self.temporal_pending:
            candidate,previous_end,previous_offset,_=self.temporal_pending[-1]
            elapsed=((sample_end-previous_end)&0xffffffff)/rate
            progression=result.offset_seconds-previous_offset
            if (candidate!=result.candidate_track_id or not .5 <= elapsed <= 4.0 or
                abs(progression-elapsed)>.20):
                self.temporal_pending=[]
        self.temporal_pending.append((result.candidate_track_id,sample_end,result.offset_seconds,now))
        self.temporal_pending=self.temporal_pending[-4:]
        if len(self.temporal_pending)<4:
            return
        span=((sample_end-self.temporal_pending[0][1])&0xffffffff)/rate
        if span<5.5:
            return
        self.active=replace(result,recognized=True,title=result.candidate_title,
            artist=result.candidate_artist,track_id=result.candidate_track_id,
            acceptance_rule='mic_temporal_sequence',reason='连续 MIC 指纹与采样进度一致')
        self.reference_rms=rms if rms>0 else None
        self.quiet_since=None
        self.support_updates=3
        self._support(self.active,now,sample_end,rms,'confirmed_temporal')
        self.temporal_pending=[]

    def quiet(self, tail_rms, now):
        """Caller clears the audio window when sustained silence is detected."""
        self._expire(now)
        if self.active is None or self.reference_rms is None:
            self.quiet_since = None
            return False
        # A quieter next song must not be mistaken for silence just because
        # the preceding track was loud. Require a small absolute level too.
        # Substantial evidence for a different candidate also defers a flush
        # while the eight-second window straddles two songs.
        changed_candidate = (self.last_result is not None and
                             self.last_result.candidate_track_id not in (None,self.active.track_id) and
                             self.last_result.votes>=80 and self.last_result.anchor_count>=40 and
                             self.last_result.score>=.018)
        threshold=min(self.reference_rms*self.QUIET_LEVEL_RATIO,self.QUIET_RMS_CEILING)
        if not changed_candidate and tail_rms < threshold:
            if self.quiet_since is None:
                self.quiet_since = now
            return now-self.quiet_since >= self.QUIET_SECONDS
        self.quiet_since = None
        return False

    def view(self, now):
        self._expire(now)
        raw = self.last_result.to_dict() if self.last_result else {}
        if self.active is not None:
            state = self.evidence if self.last_update_supported else 'holding'
            return dict(status='已识别', title=self.active.title, artist=self.active.artist,
                        match=raw, recognition_state=state,
                        support_age_seconds=round(max(0, now-self.last_support_at), 3),
                        display_acceptance_rule=self.active.acceptance_rule,
                        display_policy_version=DISPLAY_POLICY_VERSION)
        if self.temporal_pending:
            return dict(status='正在累计 MIC 连续证据',title='',
                        artist=f'连续一致窗口 {len(self.temporal_pending)} / 4',
                        match=raw,recognition_state='confirming_temporal',
                        display_policy_version=DISPLAY_POLICY_VERSION)
        if self.pending_id is not None:
            return dict(status='正在确认歌曲', title='', artist='等待第二次一致匹配',
                        match=raw, recognition_state='confirming',
                        display_policy_version=DISPLAY_POLICY_VERSION)
        return dict(status='未识别到', title='',
                    artist=self.last_result.reason if self.last_result else '请继续播放音乐',
                    match=raw, recognition_state='unknown',
                    display_policy_version=DISPLAY_POLICY_VERSION)
