from pathlib import Path
import hashlib,json,os,shutil,subprocess
HERE=Path(__file__).resolve().parent;RC=HERE.parents[1];GAME=RC.parents[1]
OUT=RC/'build/a-tcp-driver-01';assert not OUT.exists();OUT.mkdir()
JAVA='C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe'
SDK=GAME/'mods/Sandevistan/build/tools/flexsdk'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
commands=[]
for folder,entry,name in [('harness',RC/'experimental/a-visual-round2/RConnectMod.as','EffectsHarness'),('driver',HERE/'TunnelProbe.as','EffectsDriver')]:
    source=OUT/folder;source.mkdir();shutil.copy2(entry,source/entry.name)
    command=[JAVA,'-Xmx256m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),'-swf-version=38','-debug=false','-optimize=true','-source-path='+str(source),'-output='+str(OUT/(name+'.swf')),str(source/entry.name)]
    commands.append(command)
    with (OUT/(name+'.log')).open('w',encoding='utf8') as log:subprocess.run(command,env=dict(os.environ,AIR_HOME=str(SDK)),stdout=log,stderr=subprocess.STDOUT,check=True)
(OUT/'compile.json').write_text(json.dumps(dict(compiled=True,commands=commands,driver_sha256=sha(OUT/'EffectsDriver.swf'),harness_sha256=sha(OUT/'EffectsHarness.swf')),indent=2),encoding='utf8')
print('External localization probe compiled')
