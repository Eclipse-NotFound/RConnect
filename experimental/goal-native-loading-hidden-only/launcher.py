"""Original shared runner; only pre-launch private CS/telemetry and readback hooks."""
from pathlib import Path
import importlib.util,os,sys,xml.etree.ElementTree as ET
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('hidden_only_adapter',HERE/'run.py')
adapter=importlib.util.module_from_spec(spec);spec.loader.exec_module(adapter)
def main():
    b=adapter.ui_bundle();before=b['installation'];pins=b['pins']
    sys.path.insert(0,str(adapter.ROOT/'tools'))
    runner=adapter.load(adapter.SHARED,'hidden_only_shared_runner')
    original=runner.run_registered;settings={};errors=[]
    def registered(args,parser,output,record):
        assert args.private_desktop and args.require_exclusive_air and args.all_mods and args.effects
        assert not args.keep_copies and not args.solo and args.seconds==600
        assert args.game_candidate.resolve()==adapter.HOST_DIR/'pfe.swf'
        assert args.candidate.resolve()==adapter.PRODUCT/'RConnectMod.swf'
        binding=args.effects_driver.resolve();out=binding.parent
        assert out.parent==adapter.M52 and out.name.startswith('goal-native-loading-hidden-')
        assert output.resolve().parent==adapter.ROOT/'build/cooperation'
        launch,stopped=record.before_launch,record.child_stopped
        def before_launch(detail):
            if not settings:
                assert not record.children and not record.launching
                assert adapter.installation()==before and all(adapter.sha(p)==h for p,h in pins.items())
                native=adapter.read(output/'input.json');assert native['minimum_start_gib']==6
                for role in ('host','join'):
                    desc=output/role/'coop.xml';xml=ET.fromstring(desc.read_bytes());ns='{http://ns.adobe.com/air/application/30.0}'
                    appid='pfe-modsettings-rconnect-coop-'+role+'-'+output.name
                    assert xml.findtext(ns+'id')==appid and xml.findtext(ns+'initialWindow/'+ns+'content')=='pfe.swf'
                    assert adapter.sha(desc)==native['descriptors'][role]
                    app_root=Path(os.environ['APPDATA']).resolve()/appid
                    preference=app_root/'Local Store/ContinuousScene.preferences.json'
                    telemetry=output/role/'mods/ModLoader/release/telemetry.json'
                    assert preference.resolve().is_relative_to(app_root.resolve()) and not preference.exists()
                    assert telemetry.resolve().is_relative_to((output/role).resolve()) and not telemetry.exists()
                    settings[role]=dict(app_id=appid,preference=str(preference),telemetry=str(telemetry))
                for row in settings.values():
                    pref,tele=Path(row['preference']),Path(row['telemetry']);pref.parent.mkdir(parents=True,exist_ok=True)
                    with pref.open('xb') as f:f.write(adapter.PREFERENCE)
                    with tele.open('xb') as f:f.write(adapter.TELEMETRY.read_bytes())
                    row.update(preference_sha256=adapter.sha(pref),telemetry_sha256=adapter.sha(tele))
                adapter.save(out/'private-settings-before.json',dict(run=str(output.resolve()),before_any_air=True,
                    roles=settings,input_sha256=adapter.sha(output/'input.json')))
            launch(detail)
        def after_stopped():
            checked={}
            try:
                assert set(settings)=={'host','join'}
                for role,row in settings.items():
                    assert Path(row['preference']).read_bytes()==adapter.PREFERENCE
                    checked[role]=dict(preference_sha256=adapter.sha(row['preference']),telemetry_sha256=adapter.sha(row['telemetry']))
                    assert checked[role]['telemetry_sha256']==row['telemetry_sha256']==adapter.sha(adapter.TELEMETRY)
            except Exception as error:errors.append(repr(error))
            finally:
                try:adapter.save(out/'private-settings-after.json',dict(run=str(output.resolve()),before_copy_cleanup=True,
                    unchanged=not errors,roles=checked,errors=errors))
                finally:stopped()
        record.before_launch,record.child_stopped=before_launch,after_stopped
        try:return original(args,parser,output,record)
        finally:record.before_launch,record.child_stopped=launch,stopped
    runner.run_registered=registered
    try:return runner.main()
    finally:runner.run_registered=original
if __name__=='__main__':main()
