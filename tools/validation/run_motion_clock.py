"""Isolated AS3 replay; freeze exact source first and retain red comparisons."""
import argparse, datetime, hashlib, json, os, shutil, subprocess, sys, uuid
from pathlib import Path
from validation_baseline import ROOT, GAME, AFTER_UI, sha, read

ap=argparse.ArgumentParser()
ap.add_argument('--output',required=True,type=Path)
ap.add_argument('--variant',choices=['original','compensated','constant-delay'],default='original')
ap.add_argument('--motion-source',type=Path,default=ROOT/'src/rconnect/game/RemoteMotion.as')
a=ap.parse_args();out=a.output.resolve()
assert out.parent==ROOT/'build/m46' and out.name.startswith('clock-'),out
baseline=read(ROOT/AFTER_UI/'inputs.json');motion=a.motion_source.resolve();digest=sha(motion)
test=ROOT/'tests/RemoteMotionClockTestDoc.as';test_digest=sha(test)
def verify():
    assert sha(motion)==digest and sha(test)==test_digest
    for n,h in baseline['protected'].items():assert sha(GAME/n)==h,n
verify();out.mkdir(parents=True,exist_ok=False)
source=motion.read_text(encoding='utf-8-sig')
if a.variant=='compensated':
    old='offset=Math.min(offset,clockOffset);';assert source.count(old)==1
    source=source.replace(old,'var previousOffset:Number=offset;\n            offset=Math.min(offset,clockOffset);\n            cursor+=previousOffset-offset;')
elif a.variant=='constant-delay':
    old='return Math.min(Math.max(250,interval*3),value);';assert source.count(old)==1
    source=source.replace(old,'return 100;')
dest=out/'src/rconnect/game/RemoteMotion.as';dest.parent.mkdir(parents=True);dest.write_text(source,encoding='utf-8')
entry=out/test.name;shutil.copy2(test,entry)
JAVA='C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
SDK=Path('D:/RemainsMod/mods/Sandevistan/build/tools/flexsdk')
cmd=[JAVA,'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
     '-swf-version=38','-debug=true','-optimize=true','-source-path='+str(out/'src'),
     '-output='+str(out/'RemoteMotionClockTestDoc.swf'),str(entry)]
record={'at':datetime.datetime.now().astimezone().isoformat(),'variant':a.variant,'source_origin':str(motion),
        'original_source_sha256':digest,'actual_source_sha256':sha(dest),'test_source_sha256':test_digest,
        'runner_sha256':sha(Path(__file__)),'baseline_path':AFTER_UI,
        'baseline_sha256':sha(ROOT/AFTER_UI/'inputs.json'),'command':cmd}
def save(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
save(out/'input.json',record)
proc=subprocess.run(cmd,env=dict(os.environ,AIR_HOME=str(SDK)),capture_output=True,timeout=60)
(out/'build.log').write_bytes(proc.stdout+proc.stderr);record['build_exit']=proc.returncode
save(out/'build-result.json',{'exit':proc.returncode,'log_sha256':sha(out/'build.log')})
assert proc.returncode==0,proc.stdout.decode('utf-8',errors='replace')[-5000:]
record['driver_sha256']=sha(out/'RemoteMotionClockTestDoc.swf')
appid='rconnect-clock-'+uuid.uuid4().hex[:10]
descriptor=out/'application.xml'
descriptor.write_text('<?xml version="1.0" encoding="utf-8"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>'+appid+'</id><versionNumber>1.0.0</versionNumber><filename>RemoteMotionClockTestDoc</filename><initialWindow><content>RemoteMotionClockTestDoc.swf</content><visible>false</visible><width>100</width><height>100</height></initialWindow></application>',encoding='utf-8')
record.update(namespace=appid,descriptor_sha256=sha(descriptor))
with (out/'adl.log').open('wb') as log:
    p=subprocess.Popen([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(descriptor)],
                       cwd=out,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    record['pid']=p.pid
    try:record['exit']=p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        p.kill();p.wait();record.update(timeout=True,exit=p.returncode)
    record['owned_process_exited']=p.poll() is not None
result=Path(os.environ['APPDATA'])/appid/'Local Store/result.json'
if result.exists():
    shutil.copy2(result,out/'result.json');record['result_sha256']=sha(out/'result.json')
verify();save(out/'process.json',record)
assert result.exists() and not record.get('timeout'),record
d=read(out/'result.json');assert record['exit']==(1 if d['fail'] else 0),record
print(json.dumps({'variant':a.variant,'pass':d['pass'],'fail':d['fail'],'pid':p.pid,
                  'failed_checks':[x for x in d['checks'] if not x['pass']]},ensure_ascii=False),flush=True)
sys.exit(1 if d['fail'] else 0)
