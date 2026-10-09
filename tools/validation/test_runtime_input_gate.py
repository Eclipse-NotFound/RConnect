"""Reject same-on-both-sides but wrong/missing external runtime inputs."""
import copy
import unittest
from validation_baseline import verify_runtime_inputs


class RuntimeInputGateTest(unittest.TestCase):
    def setUp(self):
        self.baseline = dict(protected={'pfe.swf': 'game'},
            runtime_modules={'mods/WallBlend/release/WallBlendMod.swf': 'installed'},
            runtime_config={'mods/WallBlend/release/config.json': 'settings'},
            runtime_assets={'Music/mainmenu.mp3':'music','Rooms/room.xml':'room','sound.swf':'sound'})
        role = dict(game='game',modules={'mods\\WallBlend\\release\\WallBlendMod.swf': 'installed',
                                       'mods\\Rconnect\\release\\RConnectMod.swf': 'harness'})
        role['assets']=dict(self.baseline['runtime_assets'])
        config = {'mods/WallBlend/release/config.json': 'settings', 'mods/Rconnect/release/config.txt': 'isolated'}
        self.run = dict(inputs={r:copy.deepcopy(role) for r in ('host','join')},
                        configuration_files={r:dict(config) for r in ('host','join')})

    def test_complete_real_settings(self):
        verify_runtime_inputs(self.baseline,self.run)

    def test_old_module_even_when_both_sides_match(self):
        for role in self.run['inputs'].values():
            role['modules']['mods\\WallBlend\\release\\WallBlendMod.swf']='old'
        with self.assertRaisesRegex(AssertionError,'external module'):verify_runtime_inputs(self.baseline,self.run)

    def test_json_omitted_on_both_sides(self):
        for config in self.run['configuration_files'].values():config.pop('mods/WallBlend/release/config.json')
        with self.assertRaisesRegex(AssertionError,'external config'):verify_runtime_inputs(self.baseline,self.run)

    def test_only_join_has_different_config(self):
        self.run['configuration_files']['join']['mods/WallBlend/release/config.json']='wrong'
        with self.assertRaisesRegex(AssertionError,'external config'):verify_runtime_inputs(self.baseline,self.run)

    def test_extra_external_module_rejected(self):
        self.run['inputs']['host']['modules']['mods/Extra/release/Extra.swf']='extra'
        with self.assertRaisesRegex(AssertionError,'external module'):verify_runtime_inputs(self.baseline,self.run)

    def test_wrong_game_rejected(self):
        self.run['inputs']['join']['game']='another'
        with self.assertRaisesRegex(AssertionError,'game input'):verify_runtime_inputs(self.baseline,self.run)

    def test_music_omitted_on_both_sides(self):
        for role in self.run['inputs'].values():role['assets'].pop('Music/mainmenu.mp3')
        with self.assertRaisesRegex(AssertionError,'native runtime'):verify_runtime_inputs(self.baseline,self.run)

    def test_changed_native_resource_rejected(self):
        self.run['inputs']['join']['assets']['sound.swf']='different'
        with self.assertRaisesRegex(AssertionError,'native runtime'):verify_runtime_inputs(self.baseline,self.run)

    def test_missing_asset_manifest_rejected(self):
        self.run['inputs']['host'].pop('assets')
        with self.assertRaisesRegex(AssertionError,'native runtime'):verify_runtime_inputs(self.baseline,self.run)


if __name__=='__main__':unittest.main()
