"""Offline classifier checks only: no native game, network or performance pass."""
import copy
import math
import unittest

import analyze


def row(at, x, frame, f=1, ended=False):
    return dict(at=at, wall=10000 + at, frame=frame, render=frame,
                clips=[dict(x=x, y=0, f=f, viewport=True)],
                native=dict(x=x, y=0, ended=ended))


def pair():
    rows = [row(0, 0, 0), row(30, 30, 1), row(60, 60, 2), row(90, 90, 3, ended=True),
            row(120, 90, 4, ended=True), row(150, 90, 5, ended=True), row(180, 90, 6, ended=True)]
    rows.append(dict(at=800, wall=10800, frame=7, render=7, clips=[]))
    source = dict(frames=rows, info=dict(begx=0, begy=0), end=dict(x=90, y=0, wall=10210),
                  meta=dict(shotCount=1, pixelProof=dict(pixels=1), contactProof=dict(pixels=1)))
    remote = dict(frames=copy.deepcopy(rows), info=copy.deepcopy(source["info"]), end=copy.deepcopy(source["end"]),
                  result=dict(pixelProof=dict(pixels=1), contactProof=dict(pixels=1)))
    return source, remote


class ClassificationChecks(unittest.TestCase):
    def test_ulp_exact_boundary(self):
        x = 1.1
        y = math.nextafter(x, math.inf)
        records = []
        self.assertTrue(analyze.metadata_equal(dict(x=x), dict(x=y), roundtrips=records))
        self.assertEqual(records[0]["ulps"], 1)
        self.assertFalse(analyze.metadata_equal(x, math.nextafter(y, math.inf)))
        self.assertTrue(analyze.metadata_equal(-x, -y))

    def test_structure_boolean_integer_zero_remain_strict(self):
        for a, b in ((True, 1), (dict(x=1), dict(x=1, y=0)), ([1, 2], [2, 1]), ("1", 1),
                     (1., math.nextafter(1., math.inf)), (0., -0.), (math.nan, math.nan)):
            self.assertFalse(analyze.metadata_equal(a, b), (a, b))

    def test_contact_hold_is_checked_separately(self):
        s, r = pair()
        result = analyze.evaluate(s, r)
        self.assertEqual(result["remote"]["max_hold_ms"], 90)
        self.assertEqual(result["remote_flight"]["max_hold_ms"], 0)
        self.assertTrue(result["checks"]["moves_without_85ms_position_stall"])
        self.assertTrue(result["checks"]["contact_tail_native_position_frame_duration"])
        self.assertTrue(result["sampled_flight_checks_passed"])

    def test_real_inflight_hold_still_fails(self):
        s, r = pair()
        r["frames"] = [row(0, 0, 0), row(30, 30, 1), row(130, 30, 2), row(160, 60, 3),
                       row(190, 90, 4), row(220, 90, 5), row(250, 90, 6)]
        result = analyze.evaluate(s, r)
        self.assertFalse(result["checks"]["moves_without_85ms_position_stall"])
        self.assertFalse(result["checks"]["final_render_gap_relative_to_source"])

    def test_contact_requires_pixels(self):
        s, r = pair()
        r["result"]["contactProof"]["pixels"] = 0
        self.assertFalse(analyze.evaluate(s, r)["checks"]["contact_tail_pixels"])

    def test_two_renders_same_game_frame_do_not_prove_tail(self):
        s, r = pair()
        for p in r["frames"][3:7]:
            p["frame"] = 3
        self.assertFalse(analyze.evaluate(s, r)["checks"]["contact_tail_native_position_frame_duration"])

    def test_contact_cannot_invent_frame_or_extend_lifetime(self):
        s, r = pair()
        r["frames"][4]["clips"][0]["f"] = 99
        self.assertFalse(analyze.evaluate(s, r)["checks"]["contact_tail_native_position_frame_duration"])
        s, r = pair()
        r["frames"][6]["at"] = 500
        self.assertFalse(analyze.evaluate(s, r)["checks"]["contact_tail_native_position_frame_duration"])

    def test_missing_tail_and_startup_gap_remain_visible(self):
        s, r = pair()
        r["frames"] = [row(400, 20, 1), row(420, 20, 1),
                       dict(at=677, wall=10677, frame=2, render=3, clips=[])]
        result = analyze.evaluate(s, r)
        self.assertFalse(result["checks"]["visible_tail_coverage"])
        self.assertFalse(result["checks"]["contact_tail_native_position_frame_duration"])
        self.assertEqual(result["remote"]["max_recorded_render_gap_ms"], 257)
        self.assertFalse(result["phase_timings"]["remote"]["available"])


if __name__ == "__main__":
    unittest.main()
