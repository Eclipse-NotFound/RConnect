"""Offline counterexamples and unchanged-threshold checks. No native runtime."""
import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest

import analyze
import bounds_evidence

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "recovery-tests" / "continuity-extra"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


old = load_module("baseline_flight_analyzer", BASE / "analyze.py")
legacy = load_module("baseline_flight_counterexamples", BASE / "test_analyze.py")
original_row = legacy.row


def row(*args, **kwargs):
    result = original_row(*args, **kwargs)
    for point in result["clips"]:
        point["screen"] = dict(x=point["x"], y=point["y"], w=8, h=4)
    return result


# Run all original semantic/threshold tests unchanged against the new analyzer.
# Their synthetic positive-area points predate bounds capture; add this input
# evidence only. No assertion, position, frame, timing or pixel value changes.
legacy.row = row


class LegacyClassificationChecks(legacy.ClassificationChecks):
    pass


def pair(empty_tail=True):
    source, remote = legacy.pair()
    if empty_tail:
        for trace in (source, remote):
            point = trace["frames"][6]["clips"][0]
            point.update(f=4, viewport=False, emptyBounds=True, outsideViewport=False,
                         screen=dict(x=-9595840.8, y=-4473617.2, w=0, h=0))
    return source, remote


class EmptyBoundsChecks(unittest.TestCase):
    def proof(self, source, remote):
        return bounds_evidence.evaluate(source["frames"], remote["frames"])

    def assert_other_checks_unchanged(self, source, remote):
        before, after = old.evaluate(source, remote), analyze.evaluate(source, remote)
        for key, value in before["checks"].items():
            if key != "all_remote_samples_in_viewport":
                self.assertEqual(value, after["checks"][key], key)
        for key, value in before.items():
            if key not in ("checks", "sampled_flight_checks_passed"):
                self.assertEqual(value, after[key], key)
        return before, after

    def test_native_empty_last_frame_only_changes_viewport_item(self):
        source, remote = pair()
        before, after = self.assert_other_checks_unchanged(source, remote)
        self.assertFalse(before["checks"]["all_remote_samples_in_viewport"])
        self.assertTrue(after["checks"]["all_remote_samples_in_viewport"])
        proof = after["viewport_evidence"]
        self.assertEqual(proof["matchedNativeEmpty"], 1)
        self.assertEqual(proof["proofs"][0]["sourceRow"], 6)
        self.assertEqual(proof["proofs"][0]["f"], 4)
        self.assertEqual(after["remote"]["samples"], 7)
        self.assertEqual(after["remote"]["last"]["f"], 4)
        self.assertEqual(after["remote"]["offscreen"], 1)
        self.assertEqual(after["remote_contact"]["visible_duration_ms"], 90)

    def test_remote_only_empty_fails(self):
        source, remote = pair()
        source["frames"][6]["clips"] = []
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_same_frame_but_native_positive_area_fails(self):
        source, remote = pair()
        point = source["frames"][6]["clips"][0]
        point.update(viewport=True, emptyBounds=False, screen=dict(x=90, y=0, w=8, h=4))
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_same_point_different_animation_frame_fails(self):
        source, remote = pair()
        remote["frames"][6]["clips"][0]["f"] = 5
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_one_ulp_world_position_difference_is_not_metadata_tolerance(self):
        for key in ("x", "y"):
            source, remote = pair()
            point = remote["frames"][6]["clips"][0]
            point[key] = math.nextafter(point[key], math.inf)
            self.assertFalse(self.proof(source, remote)["passed"], key)

    def test_bounds_position_and_dimensions_must_match_exactly(self):
        for key in ("x", "y", "w", "h"):
            source, remote = pair()
            remote["frames"][6]["clips"][0]["screen"][key] += 1
            self.assertFalse(self.proof(source, remote)["passed"], key)

    def test_positive_area_offscreen_fails_even_if_source_matches(self):
        source, remote = pair(False)
        for trace in (source, remote):
            point = trace["frames"][6]["clips"][0]
            point.update(viewport=False, emptyBounds=False, outsideViewport=True,
                         screen=dict(x=-5000, y=-5000, w=8, h=4))
        before, after = self.assert_other_checks_unchanged(source, remote)
        self.assertFalse(before["checks"]["all_remote_samples_in_viewport"])
        self.assertFalse(after["checks"]["all_remote_samples_in_viewport"])
        self.assertEqual(after["viewport_evidence"]["outsideViewport"], 1)

    def test_native_source_record_is_required(self):
        source, remote = pair()
        del source["frames"][6]["native"]
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_incomplete_native_source_marker_does_not_prove_empty_frame(self):
        for native in (None, False, {}, {"x": 90, "y": 0}, {"x": 90, "y": 0, "ended": 1}):
            source, remote = pair()
            source["frames"][6]["native"] = native
            self.assertFalse(self.proof(source, remote)["passed"], native)

    def test_wire_or_endpoint_are_not_source_render_evidence(self):
        source, remote = pair()
        source["wire"] = [copy.deepcopy(source["frames"][6])]
        source["frames"][6]["clips"] = []
        source["end"].update(f=4, screen=copy.deepcopy(remote["frames"][6]["clips"][0]["screen"]))
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_all_remote_clips_require_proof_not_just_first(self):
        source, remote = pair()
        extra = copy.deepcopy(remote["frames"][6]["clips"][0]); extra["f"] = 99
        remote["frames"][6]["clips"].append(extra)
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_missing_negative_nonfinite_bounds_fail(self):
        for bad in (None, {}, dict(x=0, y=0, w=-1, h=0), dict(x=math.inf, y=0, w=0, h=0),
                    dict(x=0, y=0, w=math.nan, h=0), dict(x=0, y=0, w=False, h=0)):
            source, remote = pair()
            remote["frames"][6]["clips"][0]["screen"] = bad
            self.assertFalse(self.proof(source, remote)["passed"], bad)

    def test_false_empty_flag_or_true_empty_viewport_fail(self):
        for key, value in (("emptyBounds", False), ("outsideViewport", True), ("viewport", True),
                           ("emptyBounds", 1), ("outsideViewport", 0)):
            source, remote = pair()
            remote["frames"][6]["clips"][0][key] = value
            self.assertFalse(self.proof(source, remote)["passed"], key)

    def test_old_raw_evidence_without_new_flags_still_requires_bounds(self):
        source, remote = pair()
        for trace in (source, remote):
            for key in ("emptyBounds", "outsideViewport"):
                del trace["frames"][6]["clips"][0][key]
        self.assertTrue(self.proof(source, remote)["passed"])
        del remote["frames"][6]["clips"][0]["screen"]
        self.assertFalse(self.proof(source, remote)["passed"])

    def test_empty_frame_not_reserved_to_f4(self):
        source, remote = pair()
        for trace in (source, remote):
            trace["frames"][6]["clips"][0]["f"] = 9
        self.assertTrue(self.proof(source, remote)["passed"])

    def test_invalid_native_frame_number_is_not_empty_proof(self):
        for value in (0, -1, 1.5, True, math.inf, 2147483648):
            source, remote = pair()
            for trace in (source, remote):
                trace["frames"][6]["clips"][0]["f"] = value
            self.assertFalse(self.proof(source, remote)["passed"], value)

    def test_one_zero_dimension_is_zero_area_but_requires_equal_native_shape(self):
        source, remote = pair()
        for trace in (source, remote):
            trace["frames"][6]["clips"][0]["screen"]["h"] = 4
        self.assertTrue(self.proof(source, remote)["passed"])

    def test_proven_empty_tail_does_not_waive_lifetime_or_pixels(self):
        source, remote = pair()
        remote["frames"][6]["at"] = 500
        remote["result"]["contactProof"]["pixels"] = 0
        before, after = self.assert_other_checks_unchanged(source, remote)
        self.assertTrue(after["checks"]["all_remote_samples_in_viewport"])
        self.assertFalse(after["checks"]["contact_tail_native_position_frame_duration"])
        self.assertFalse(after["checks"]["contact_tail_pixels"])
        self.assertFalse(after["sampled_flight_checks_passed"])

    def test_no_input_mutation_or_frame_deletion(self):
        source, remote = pair()
        before = copy.deepcopy((source, remote))
        proof = self.proof(source, remote)
        self.assertEqual((source, remote), before)
        proof["proofs"][0]["screen"]["x"] = 123
        self.assertEqual((source, remote), before)

    def test_historical_coop_fail_remains_a_failure(self):
        # The standalone load() keeps the original COOP FAIL. No exception
        # removes a logged failure because the new classifier diagnoses it.
        source = (HERE / "analyze.py").read_text("utf-8")
        self.assertIn('or log_failures)', source)
        self.assertIn('failures.append(line)', source)


if __name__ == "__main__":
    unittest.main()
