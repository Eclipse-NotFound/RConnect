"""Offline adapter checks: no compiler, AIR, registry acquisition or real freeze."""
import argparse
import copy
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

import native_tool as tool


def manifest(compiled=False):
    binding = tool.prepare.read(tool.HERE / 'inputs.json')
    return dict(entries={tool.ENTRY: dict(scenarios=8, seconds=360, land='random_mane',
        functional_only=True, performance_qualified=False)}, components={},
        inputs={dest: binding['outputs'][name] for name, dest in tool.FILES.items()},
        originals={}, compiled=compiled, control_sha256=tool.prepare.BASE_SHA,
        extension=dict(kind=tool.KIND, entry=tool.ENTRY, fixture_sha256=binding['outputs'],
                       installation_files=22, source_tools=tool.source_tools()))


class AdapterChecks(unittest.TestCase):
    def test_generic_recipe_resolved_not_local_generator(self):
        self.assertEqual(Path(tool.prepare.__file__).resolve(), tool.GENERIC / 'prepare.py')
        self.assertEqual(tool.prepare.COMPONENTS, {})

    def test_freeze_four_inputs_and_only_one_entry(self):
        with tempfile.TemporaryDirectory(prefix='adapter-check-', dir=tool.HERE) as temp:
            output = Path(temp) / 'new'
            source = Path(temp) / 'source'

            def fake_freeze(src, out, entry_names):
                self.assertEqual(src, source)
                self.assertEqual(entry_names, [tool.ENTRY])
                self.assertEqual(tool.prepare.COMPONENTS, {})
                out.mkdir()
                return manifest()

            with patch.object(tool.prepare, 'freeze', side_effect=fake_freeze), \
                 patch.object(tool.prepare, 'verify') as verify, \
                 patch.object(tool.prepare, 'build') as build:
                result = tool.freeze(source, output)
            verify.assert_called_once_with(output, source)
            build.assert_not_called()
            self.assertEqual(set(result['entries']), {tool.ENTRY})
            for name, dest in tool.FILES.items():
                self.assertEqual((output / dest).read_bytes(), (tool.HERE / name).read_bytes())
            self.assertFalse((output / 'components').exists())
            self.assertTrue((output / 'analysis/bounds_evidence.py').is_file())
            self.assertTrue((output / 'inputs/flight-empty-frame/offline-receipt.json').is_file())
            self.assertEqual(json.loads((output / 'prepared.json').read_text())['extension']['source_tools'],
                             tool.source_tools())

    def test_manifest_accepts_bound_single_entry(self):
        tool.check_manifest(manifest())

    def test_manifest_rejects_old_component(self):
        data = manifest()
        data['components']['impact'] = {}
        with self.assertRaises(AssertionError):
            tool.check_manifest(data)

    def test_manifest_rejects_changed_helper(self):
        data = manifest()
        data['inputs']['analysis/bounds_evidence.py'] = 'changed'
        with self.assertRaises(AssertionError):
            tool.check_manifest(data)

    def test_manifest_rejects_weaker_qualification(self):
        for key, value in [('scenarios', 7), ('seconds', 359), ('performance_qualified', True)]:
            with self.subTest(key=key):
                data = manifest()
                data['entries'][tool.ENTRY][key] = value
                with self.assertRaises(AssertionError):
                    tool.check_manifest(data)
        data = manifest()
        data['extension']['installation_files'] = 21
        with self.assertRaises(AssertionError):
            tool.check_manifest(data)

    def test_manifest_rejects_changed_runner_tool(self):
        data = manifest()
        data['extension']['source_tools'][str(tool.GENERIC / 'run.py')] = 'changed'
        with self.assertRaises(AssertionError):
            tool.check_manifest(data)

    def test_run_delegates_control_and_keeps_failure(self):
        data = manifest(True)
        saved_argv = sys.argv
        observed = {}
        tools = lambda: {'unchanged-native-gate': 'original-tool-hash'}

        def native_main():
            observed['argv'] = list(sys.argv)
            observed['tools'] = fake.runtime_tools()
            return 1  # Failed 574D control remains failed.

        fake = types.SimpleNamespace(__file__=str(tool.GENERIC / 'run.py'),
            EXPECTED_INSTALLATION_FILES=22, SUITES={tool.ENTRY: 'native-flight-continuity'},
            runtime_tools=tools, main=native_main)
        args = argparse.Namespace(output=tool.ROOT / 'build/m52/not-created',
                                  registry_wait=900, control=True)
        with patch.dict(sys.modules, {'run': fake}), patch.object(tool.prepare, 'read', return_value=data):
            code = tool.run_native(args, tool.ROOT / 'build/m52/not-read')
        self.assertEqual(code, 1)
        self.assertEqual(observed['argv'][1], 'native')
        self.assertIn('--control', observed['argv'])
        self.assertIn(tool.ENTRY, observed['argv'])
        self.assertEqual(observed['tools']['unchanged-native-gate'], 'original-tool-hash')
        self.assertEqual(observed['tools'][str(Path(tool.__file__).resolve())],
                         tool.prepare.sha(Path(tool.__file__)))
        self.assertIs(fake.runtime_tools, tools)
        self.assertIs(sys.argv, saved_argv)

    def test_run_rejects_uncompiled_fixture(self):
        args = argparse.Namespace(output=Path('unused'), registry_wait=900, control=False)
        with patch.object(tool.prepare, 'read', return_value=manifest(False)), \
             self.assertRaises(AssertionError):
            tool.run_native(args, Path('unused'))

    def test_output_outside_build_m52_rejected_before_freeze(self):
        with patch.object(tool.prepare, 'freeze') as freeze, self.assertRaises(AssertionError):
            tool.main(['prepare', '--source', 'build/m52/recovery-08/src',
                       '--output', 'experimental/not-allowed'])
        freeze.assert_not_called()


if __name__ == '__main__':
    unittest.main(verbosity=2)
