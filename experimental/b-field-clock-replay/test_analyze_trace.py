"""Small in-memory observer trace fixtures, never real-game qualification."""
import copy
import json
import unittest

import analyze_trace as a


def clock(position=0, queued=0, underflows=0):
    return dict(position=position, delay=65, queued=queued, underflows=underflows,
                currentTime=position, currentTick=position, nextTime=None, nextTick=None)


def frame(time=100):
    return dict(time=time, tick=time, room="one", pauseEpoch=0, paused=False,
                players=[dict(epoch=1, roomEpoch=1), dict(epoch=1, roomEpoch=1)],
                timeControl=dict(phase="idle", cycle=0), terrainRevision=1,
                projectileCount=2, projectileEventCount=0)


def arrival(seq, at, source, returned, queued=0):
    return dict(kind="arrival", seq=seq, at=at, forwardAt=at+1, returnAt=returned,
                complete=True, queueAccounting=True, accepted=True, acceptedCount=1,
                frame=frame(source), clockBefore=clock(), clockAfter=clock(source, queued))


def fixture():
    rows = [arrival(1, 1000, 100, 1020),
            dict(kind="confirmed", seq=2, at=1010, arrivalSeq=1, screenSeq=None, frame=frame()),
            arrival(3, 1100, 200, 1110, 1),
            dict(kind="screen", seq=4, at=1190, endAt=1220, complete=True,
                 clockBefore=clock(100, 1, 1), clockAfter=clock(200, 0, 2)),
            dict(kind="confirmed", seq=5, at=1210, arrivalSeq=None, screenSeq=4, frame=frame(200))]
    return dict(header=dict(kind="header", schema="rconnect-b-clock-trace-1", role="join", at=990,
                            completeHistory=True, initialClock=clock(), build="synthetic", session="synthetic"),
                rows=rows,
                footer=dict(kind="footer", at=1230, recordedRows=len(rows), finalClock=clock(200, 0, 2),
                            acceptedFrames=2, confirmations=2, observerMs=0, reason="scenario completed"))


class TraceTests(unittest.TestCase):
    def test_same_process_wait_and_boundary_negative_return(self):
        result = a.analyze(fixture())
        self.assertTrue(result["clean_pairing"])
        self.assertEqual(result["waits"]["all"]["entry_to_confirm_ms"]["mean"], 60)
        self.assertEqual(result["waits"]["delivery_flush"]["return_to_confirm_signed_ms"]["min"], -10)
        self.assertEqual(result["waits"]["delivery_flush"]["push_to_confirm_lower_ms"]["min"], 0)
        self.assertEqual(result["waits"]["screen"]["entry_to_confirm_ms"]["mean"], 110)

    def test_json_and_jsonl_have_same_meaning(self):
        value = fixture()
        lines = [value["header"], *value["rows"], value["footer"]]
        jsonl = "\n".join(json.dumps(x) for x in lines)
        self.assertEqual(a.analyze(a.decode(json.dumps(value))), a.analyze(a.decode(jsonl)))

    def test_pending_tail_is_not_called_lost(self):
        value = fixture()
        value["rows"].append(arrival(6, 1225, 300, 1228, 1))
        value["footer"].update(recordedRows=6, acceptedFrames=3, finalClock=clock(200, 1, 2))
        result = a.analyze(value)
        self.assertTrue(result["clean_pairing"])
        self.assertEqual(result["counts"]["tail_arrivals_not_yet_confirmed"], 1)
        self.assertEqual(result["counts"]["skipped_captured_arrivals"], 0)

    def test_equal_source_times_pair_in_fifo_order(self):
        value = fixture()
        value["rows"] = [arrival(1, 1000, 100, 1005, 1), arrival(2, 1006, 100, 1015),
                         dict(kind="confirmed", seq=3, at=1010, arrivalSeq=2, screenSeq=None, frame=frame(100)),
                         dict(kind="confirmed", seq=4, at=1011, arrivalSeq=2, screenSeq=None, frame=frame(100))]
        value["footer"].update(recordedRows=4)
        result = a.analyze(value)
        self.assertEqual(result["counts"]["matched"], 2)
        self.assertEqual([x["arrival_seq"] for x in result["slowest_matched"]], [1, 2])

    def test_missing_confirmation_is_explicit(self):
        value = fixture()
        value["rows"].pop(1)
        for i, row in enumerate(value["rows"], 1):
            row["seq"] = i
        value["footer"].update(recordedRows=4, confirmations=1)
        result = a.analyze(value)
        self.assertFalse(result["clean_pairing"])
        self.assertEqual(result["counts"]["skipped_captured_arrivals"], 1)

    def test_midstream_capture_does_not_claim_complete_history(self):
        value = fixture()
        value["header"]["completeHistory"] = False
        result = a.analyze(value)
        self.assertTrue(result["clean_pairing"])
        self.assertFalse(result["complete_history"])
        self.assertTrue(any("private clock history" in note for note in result["quality_notes"]))
        self.assertEqual(result["counts"]["matched"], 2)

    def test_impossible_causal_or_source_order_rejected(self):
        value = fixture()
        value["rows"][0]["forwardAt"] = 1015
        with self.assertRaises(a.TraceError):
            a.analyze(value)
        value = fixture()
        value["rows"][2]["frame"]["time"] = 99
        with self.assertRaises(a.TraceError):
            a.analyze(value)

    def test_nonfinite_and_noncontiguous_records_rejected(self):
        value = fixture()
        value["rows"][0]["frame"]["time"] = float("nan")
        with self.assertRaises(a.TraceError):
            a.analyze(value)
        value = fixture()
        value["rows"][1]["seq"] = 999
        with self.assertRaises(a.TraceError):
            a.analyze(value)

    def test_terrain_revision_is_only_a_labeled_cohort(self):
        value = fixture()
        value["rows"][2]["frame"]["terrainRevision"] = 2
        value["rows"][4]["frame"].update(terrainRevision=2, projectileEventCount=1)
        result = a.analyze(value)
        self.assertEqual(result["waits"]["terrain_revision_changed"]["entry_to_confirm_ms"]["n"], 1)
        self.assertEqual(result["waits"]["with_projectile_events"]["entry_to_confirm_ms"]["n"], 1)
        self.assertEqual(result["scene_coverage"]["status"], "aggregate_events_observed_full_scene_unverified")
        self.assertTrue(result["scene_coverage"]["supports_observed_projectile_event_waits"])
        self.assertFalse(result["scene_coverage"]["full_scene_coverage_established"])
        self.assertFalse(result["scene_coverage"]["supports_weapon_specific_latency"])

    def test_callback_replaced_after_one_initial_load_is_not_a_rocket_scene(self):
        value = fixture()
        first = arrival(1, 1000, 100, 11243)
        first["frame"].update(tick=0, projectileCount=0)
        confirmation = dict(kind="confirmed", seq=2, at=11242, arrivalSeq=1, screenSeq=None,
                            frame=copy.deepcopy(first["frame"]))
        value["rows"] = [first, confirmation]
        value["footer"].update(at=11550, recordedRows=2, acceptedFrames=1, confirmations=1,
                               reason="another owner replaced a diagnostic callback")
        result = a.analyze(value)
        self.assertTrue(result["pairing_valid"])
        self.assertTrue(result["clean_pairing"])
        self.assertEqual(result["pairing_quality_notes"], [])
        self.assertTrue(result["quality_notes"])
        self.assertEqual(result["termination"]["status"], "callback_ownership_lost")
        self.assertEqual(result["scene_coverage"]["status"], "insufficient")
        self.assertFalse(result["scene_coverage"]["supports_observed_projectile_event_waits"])
        self.assertEqual(result["waits"]["initial_tick_zero"]["entry_to_confirm_ms"]["mean"], 10242)
        self.assertEqual(result["waits"]["post_initial"]["entry_to_confirm_ms"]["n"], 0)
        self.assertEqual(result["waits"]["with_projectile_events"]["entry_to_confirm_ms"]["n"], 0)

    def test_late_footer_clock_is_not_attributed_to_the_collection_interval(self):
        value = fixture()
        value["footer"].update(finalFrame=frame(900), finalClock=clock(900, 0, 50))
        result = a.analyze(value)
        self.assertTrue(result["clean_pairing"])
        self.assertFalse(result["footer_state_within_captured_history"])
        self.assertIsNone(result["clock"]["underflow_counter_delta"])
        self.assertEqual(result["clock"]["footer_underflow_counter_delta_unscoped"], 50)
        self.assertEqual(result["clock"]["underflow_in_screen_brackets"], 1)

    def test_same_final_frame_does_not_hide_a_later_clock_position(self):
        value = fixture()
        value["footer"].update(finalFrame=frame(200), finalClock=clock(900, 0, 50))
        self.assertFalse(a.analyze(value)["footer_state_within_captured_history"])

    def test_missing_reason_and_normal_caller_stop_do_not_prove_scene_completion(self):
        for reason in (None, "caller wrote trace", "caller stopped", "unknown reason"):
            value = fixture()
            value["footer"]["reason"] = reason
            result = a.analyze(value)
            self.assertTrue(result["clean_pairing"])
            self.assertFalse(result["scene_coverage"]["collector_reported_scenario_completed"])

    def test_normal_stop_without_events_still_has_insufficient_event_coverage(self):
        result = a.analyze(fixture())
        self.assertTrue(result["clean_pairing"])
        self.assertTrue(result["scene_coverage"]["collector_reported_scenario_completed"])
        self.assertEqual(result["scene_coverage"]["status"], "insufficient")
        self.assertEqual(result["scene_coverage"]["matched_projectile_event_frames"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
