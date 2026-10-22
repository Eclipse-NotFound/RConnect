"""Source-only checks. Does not compile, launch AIR or modify installed files."""
from pathlib import Path
import ast,json,re
from native_inputs import HERE,BASE,verify_tools
def main():
    verify_tools();checks=[]
    def check(ok,label):
        assert ok,label
        checks.append(label)
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'));checks.append('python syntax '+p.name)
    new=(HERE/'tests/FirstRasterSceneProbe.as').read_text(encoding='utf-8')
    old=(BASE/'tests/FirstRasterSceneProbe.as').read_text(encoding='utf-8-sig')
    # The entire finish method (including every old assertion) is unchanged.
    def finish(s):return s[s.index('      public function finish():Object {'):s.index('      public function dispose():void {')]
    check(finish(new)==finish(old),'exact original raster assertions retained')
    check('MAX_DIAGNOSTICS:int=20' in new and 'MAX_CHANGES:int=13' in new,'20 records with checkpoint reserve')
    check('now-lastPoll<250' in new,'scalar polls bounded to 4 per second')
    check('CHECKPOINTS:Array=[8000,15000,30000,44000,60000,90000]' in new,'timeout checkpoints retained')
    additions=(HERE/'methods.txt').read_text(encoding='utf-8')
    check(all(token not in additions for token in ('.acquire(','.receive(','.allowPaint(','.invalidate(','.sceneTick(','.setPos(')),'no production mutation calls')
    for field in ('waiting','unpainted','rconnectRasterPending','sceneViewReady','locMatchesWorld','comLoad','t_die','ng_wait','earlyPending','currentIdentity','permit'):
        check(field in new,'observes '+field)
    prep=(HERE/'prepare.py').read_text(encoding='utf-8')
    check(prep.count("shutil.copyfile(HERE/'tests/")==1,'only one original AS source replaced')
    run=(HERE/'run_native.py').read_text(encoding='utf-8')
    check("'--require-exclusive-air'" in run and "'--private-desktop'" in run,'exclusive hidden native runner retained')
    check("result['early_performance_qualified']=False" in run,'no diagnostic performance qualification')
    check("result['passed']=process.returncode==0 and before==after" in run,'original failure gate retained')
    check("'recovery-early-sandy-native/native_runner.py'" in run.replace('"',"'"),'frozen original native runner reused')
    print(json.dumps({'checks':len(checks),'passed':checks,'compiled':False,'air_started':False},ensure_ascii=False,indent=2))
if __name__=='__main__':main()
