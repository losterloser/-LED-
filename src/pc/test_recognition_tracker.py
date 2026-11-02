"""Behavioral checks for stable identities and bounded stale-title protection."""
import unittest
from songid import Match
from recognition_tracker import RecognitionTracker


def strong(track=1, offset=40):
    return Match(True, f'歌曲{track}', f'歌手{track}', track, votes=220,
                 query_hashes=4300, anchor_count=110, span_seconds=7.5,
                 score=.051, runner_up_votes=10, offset_seconds=offset,
                 reason='已识别', acceptance_rule='mic_guarded', candidate_track_id=track)


def weak(track=1, offset=40):
    return Match(False, votes=110, query_hashes=4300, anchor_count=65,
                 span_seconds=7.2, score=.025, runner_up_votes=10,
                 offset_seconds=offset, candidate_track_id=track)


class TrackerTests(unittest.TestCase):
    def setUp(self):
        self.tracker=RecognitionTracker()

    def update(self, result, now, acoustic=True, end=None, rms=.02):
        self.tracker.update(result,now,(96000+round(now*12000))&0xffffffff if end is None else end,
                            12000,rms,acoustic=acoustic)

    def establish(self):
        self.update(strong(offset=40),0)
        self.update(strong(offset=42),2)

    def low(self,offset=40,track=1,runner=7):
        return Match(False,votes=64,query_hashes=4368,anchor_count=41,span_seconds=7.2,
                     score=.0147,runner_up_votes=runner,offset_seconds=offset,candidate_track_id=track)

    def establish_tracking(self):
        self.establish()
        self.update(weak(offset=44),4)
        self.update(weak(offset=46),6)

    def temporal(self,offset=40,track=1):
        return Match(False,votes=65,query_hashes=4368,anchor_count=44,span_seconds=7.2,
                     score=.0149,runner_up_votes=5,offset_seconds=offset,candidate_track_id=track,
                     candidate_title=f'歌曲{track}',candidate_artist=f'歌手{track}')

    def test_temporal_acquisition_needs_four_progressing_windows(self):
        for now in (0,2,4):
            result=self.temporal(offset=40+now)
            self.update(result,now)
            self.assertFalse(result.recognized)
            self.assertEqual(self.tracker.view(now)['title'],'')
        self.update(self.temporal(offset=46),6)
        decision=self.tracker.view(6)
        self.assertEqual(decision['title'],'歌曲1')
        self.assertEqual(decision['display_acceptance_rule'],'mic_temporal_sequence')
        self.assertEqual(decision['recognition_state'],'confirmed_temporal')

    def test_temporal_acquisition_forbidden_for_line_or_missing_metadata(self):
        for mode in ('line','missing_artist','missing_title'):
            self.tracker.reset()
            for now in (0,2,4,6,8,10):
                result=self.temporal(offset=40+now)
                if mode=='missing_artist':result.candidate_artist=''
                if mode=='missing_title':result.candidate_title=''
                self.update(result,now,acoustic=mode!='line')
                self.assertEqual(self.tracker.view(now)['title'],'',mode)

    def test_temporal_wrong_offset_or_frozen_audio_or_margin_cannot_acquire(self):
        for mode in ('offset','frozen','margin','candidate'):
            self.tracker.reset()
            for now in (0,2,4,6,8,10):
                result=self.temporal(offset=40+now)
                if mode=='offset':result.offset_seconds=40
                if mode=='margin':result.runner_up_votes=20
                if mode=='candidate':result.candidate_track_id=now%4
                self.update(result,now,end=96000 if mode=='frozen' else None)
                self.assertEqual(self.tracker.view(now)['title'],'',mode)

    def test_temporal_partial_sequence_expires_and_reset_clears(self):
        self.update(self.temporal(offset=40),0)
        self.update(self.temporal(offset=42),2)
        self.assertEqual(self.tracker.view(9)['recognition_state'],'unknown')
        self.update(self.temporal(offset=50),10)
        self.tracker.reset()
        self.assertEqual(self.tracker.view(10)['title'],'')

    def test_paired_low_evidence_keeps_only_established_mic_identity(self):
        self.establish_tracking()
        self.update(self.low(offset=48),8)
        self.assertEqual(self.tracker.view(8)['recognition_state'],'holding')
        self.update(self.low(offset=50),10)
        self.assertEqual(self.tracker.view(10)['recognition_state'],'tracking_paired_weak')
        for now in range(12,40,2):
            self.update(self.low(offset=40+now),now)
            self.assertEqual(self.tracker.view(now)['title'],'歌曲1')
        self.assertEqual(self.tracker.view(44)['title'],'')

    def test_low_evidence_never_acquires_or_applies_to_line(self):
        for now in range(0,20,2):
            self.update(self.low(offset=40+now),now)
            self.assertEqual(self.tracker.view(now)['title'],'')
        self.establish_tracking()
        self.update(self.low(offset=48),8,acoustic=False)
        self.update(self.low(offset=50),10,acoustic=False)
        self.assertEqual(self.tracker.view(12)['title'],'')

    def test_low_evidence_wrong_candidate_offset_margin_or_frozen_clock_does_not_hold(self):
        for label in ('candidate','offset','margin','frozen'):
            self.tracker.reset();self.establish_tracking()
            first=self.low(offset=48)
            second=self.low(offset=50)
            if label=='candidate':first.candidate_track_id=2;second.candidate_track_id=2
            if label=='offset':first.offset_seconds=100;second.offset_seconds=102
            if label=='margin':first.runner_up_votes=20;second.runner_up_votes=20
            self.update(first,8)
            self.update(second,10,end=192000 if label=='frozen' else None)
            self.assertEqual(self.tracker.view(12)['title'],'',label)

    def test_initial_two_confirmations_and_no_weak_acquisition(self):
        self.update(weak(offset=40),0)
        self.assertEqual(self.tracker.view(0)['title'],'')
        self.update(strong(offset=42),2)
        self.assertEqual(self.tracker.view(2)['recognition_state'],'confirming')
        self.update(strong(offset=44),4)
        self.assertEqual(self.tracker.view(4)['title'],'歌曲1')

    def test_continuous_mic_evidence_survives_long_weak_section(self):
        self.establish()
        for now in range(4,32,2):
            self.update(weak(offset=40+now),now)
            self.assertEqual(self.tracker.view(now)['title'],'歌曲1')
            self.assertEqual(self.tracker.view(now)['recognition_state'],'tracking')
        self.assertEqual(self.tracker.view(35.9)['title'],'歌曲1')
        self.assertEqual(self.tracker.view(36)['title'],'')

    def test_unrelated_or_wrong_offset_cannot_extend_identity(self):
        self.establish()
        self.update(weak(track=2,offset=44),4)
        self.assertEqual(self.tracker.view(4)['recognition_state'],'holding')
        self.update(weak(offset=99),6)
        self.assertEqual(self.tracker.view(6)['recognition_state'],'holding')
        self.assertEqual(self.tracker.view(8)['title'],'')
        self.update(weak(offset=50),10)
        self.assertEqual(self.tracker.view(10)['title'],'')

    def test_line_does_not_use_weak_mic_evidence(self):
        self.establish()
        self.update(weak(offset=44),4,acoustic=False)
        self.assertEqual(self.tracker.view(4)['recognition_state'],'holding')
        self.update(weak(offset=46),6,acoustic=False)
        self.assertEqual(self.tracker.view(8)['title'],'')

    def test_song_change_needs_two_confirmations(self):
        self.establish()
        self.update(strong(track=2,offset=20),4)
        self.assertEqual(self.tracker.view(4)['title'],'歌曲1')
        self.assertEqual(self.tracker.view(4)['recognition_state'],'holding')
        self.update(strong(track=2,offset=22),6)
        self.assertEqual(self.tracker.view(6)['title'],'歌曲2')

    def test_reset_clears_without_grace_period(self):
        self.establish()
        self.tracker.reset()
        self.assertEqual(self.tracker.view(2)['title'],'')
        self.assertFalse(self.tracker.quiet(0,3))

    def test_sustained_silence_and_brief_pause(self):
        self.establish()
        self.assertFalse(self.tracker.quiet(.001,3))
        self.assertFalse(self.tracker.quiet(.001,4.5))
        self.assertFalse(self.tracker.quiet(.02,4.9))
        self.assertFalse(self.tracker.quiet(.001,5))
        self.update(strong(offset=46),6,rms=.003)
        self.assertAlmostEqual(self.tracker.reference_rms,.02)
        self.assertTrue(self.tracker.quiet(.001,7))

    def test_sample_counter_wrap_and_stalled_samples(self):
        self.update(strong(offset=40),0,end=(1<<32)-36000)
        self.update(strong(offset=42),2,end=(1<<32)-12000)
        self.update(weak(offset=44),4,end=12000)
        self.assertEqual(self.tracker.view(4)['recognition_state'],'tracking')
        self.update(weak(offset=46),6,end=12000)
        self.assertEqual(self.tracker.view(6)['recognition_state'],'holding')
        self.assertEqual(self.tracker.view(10)['title'],'')

    def test_quieter_music_above_noise_level_is_not_silence(self):
        self.establish()
        self.assertFalse(self.tracker.quiet(.003,3))
        self.assertFalse(self.tracker.quiet(.003,5.5))

    def test_different_song_evidence_prevents_silence_flush(self):
        self.establish()
        self.update(weak(track=2,offset=10),3)
        self.assertFalse(self.tracker.quiet(.0005,3))
        self.assertFalse(self.tracker.quiet(.0005,5.5))
        self.assertEqual(self.tracker.view(8)['title'],'')

    def test_expired_identity_needs_fresh_confirmation(self):
        self.establish()
        self.update(strong(offset=48),8)
        self.assertEqual(self.tracker.view(8)['recognition_state'],'confirming')
        self.update(strong(offset=50),10)
        self.assertEqual(self.tracker.view(10)['title'],'歌曲1')


if __name__=='__main__':
    unittest.main(verbosity=2)
