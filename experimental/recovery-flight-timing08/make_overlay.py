"""Insert removable scalar-only diagnostics in exact recovery08/drivers14 inputs."""
from pathlib import Path
import hashlib
import importlib.util
import json
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-08/src'
DRIVER=ROOT/'build/m52/recovery-flight-drivers-14/tests/NativeFlightContinuityTestDoc.as'
BASE_SHA='74d2ab0f6c1d174153af56e9c3a8e3750fa429de066f0dfe90226d48db906f02'
DRIVER_SHA='3fd803a59bfa84fd9aa5e82c3d6df83934d5041ac399b0b335ef57468f0da23a'
RECIPE=ROOT/'experimental/recovery-flight-diagnostics/make_overlay.py'
RECIPE_SHA='6b6dcb0c53d51e614ab9c8c6dc536d5affe18b1c136c347a30f6ce1904a57f98'


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()


assert sha(RECIPE)==RECIPE_SHA
spec=importlib.util.spec_from_file_location('flight08_old_insertions',RECIPE)
old=importlib.util.module_from_spec(spec);spec.loader.exec_module(old)
block,plain,add_after=old.block,old.plain,old.add_after


def closing_brace(text,start):
    """Count code braces, skipping quoted strings and both AS comment forms."""
    depth=0;i=start
    while i<len(text):
        if text.startswith('//',i):
            end=text.find('\n',i);i=len(text) if end<0 else end+1;continue
        if text.startswith('/*',i):
            end=text.find('*/',i+2);assert end>=0;i=end+2;continue
        if text[i] in ('"',"'"):
            quote=text[i];i+=1
            while i<len(text):
                if text[i]=='\\':i+=2;continue
                if text[i]==quote:i+=1;break
                i+=1
            continue
        if text[i]=='{':depth+=1
        elif text[i]=='}':
            depth-=1
            if depth==0:return i
        i+=1
    raise AssertionError('Unclosed function')


def span(text,name,code,detail='0'):
    matches=list(re.finditer(r'private function '+name+r'\([^\n]*\):void\s*\{',text))
    assert len(matches)==1,name
    opening=matches[0].end()-1;closing=closing_brace(text,opening)
    begin=block('\n         var _flight08Start:int=FlightDiagnostics.sink==null?-1:getTimer();\n         try {')
    end=block('\n         } finally {if(_flight08Start>=0)FlightDiagnostics.span('+str(code)+','+detail+',_flight08Start,getTimer());}\n')
    return text[:opening+1]+begin+text[opening+1:closing]+end+text[closing:]


def session(text):
    text=add_after(text,'   import flash.utils.Timer;\n','   import flash.utils.getTimer;\n   import rconnect.diagnostics.FlightDiagnostics;')
    for name,code,detail in [('onLinkMessage',1,'FlightDiagnostics.messageType(e.data)'),
                             ('onHostMessage',2,'FlightDiagnostics.messageType(e.data)'),('onTick',3,'0')]:
        text=span(text,name,code,detail)
    return text


def bridge(text):
    text=add_after(text,'   import flash.utils.getTimer;\n','   import rconnect.diagnostics.FlightDiagnostics;')
    for name,code in [('onPerceptionFrame',10),('onMirrorMaskFrame',11),('onMirrorFrame',12),('onVisForceFrame',13)]:
        text=span(text,name,code)
    return text


def motion(text):
    return old.motion(text).replace('if(FlightDiagnostics.sink!=null)diagnoseMotion(',
        'if(FlightDiagnostics.sink!=null && FlightDiagnostics.watches(this))diagnoseMotion(')


def main():
    assert sha(BASE.parent/'RConnectMod.swf')==BASE_SHA and sha(DRIVER)==DRIVER_SHA
    prepared=json.loads((BASE.parent/'prepared.json').read_text(encoding='utf-8'))
    assert all(sha(BASE/n)==h for n,h in prepared['source'].items())
    # No RoomCodec/WallImpactVisuals insertion, no payload capture, no timing flag mutation.
    changes={'rconnect/game/RemoteMotion.as':motion,'rconnect/game/ProjectileFrameStream.as':old.stream,
             'rconnect/game/ProjectileVisuals.as':old.projectiles,'rconnect/core/Session.as':session,
             'rconnect/game/GameBridge.as':bridge}
    manifest={'schema':1,'purpose':'timing08_diagnostic_only','baseline':str(BASE),
              'baseline_prepared_sha256':sha(BASE.parent/'prepared.json'),'baseline_binary_sha256':BASE_SHA,
              'recipe_dependencies':{str(RECIPE):RECIPE_SHA},'files':[]}
    for relative,transform in changes.items():
        source=BASE/relative;original=source.read_text(encoding='utf-8');modified=transform(original)
        assert plain(modified)==original,relative
        dest=HERE/'src'/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(modified.encode('utf-8'))
        manifest['files'].append({'source':str(source),'source_sha256':sha(source),'overlay':dest.relative_to(HERE).as_posix(),
                                  'sha256':sha(dest),'stripped_equal':True,'diagnostic_spans':modified.count(old.BEGIN)})
    original=DRIVER.read_text(encoding='utf-8');modified=old.driver(original)
    assert plain(modified)==original
    dest=HERE/'tests'/DRIVER.name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(modified.encode('utf-8'))
    manifest['driver']={'source':str(DRIVER),'source_sha256':sha(DRIVER),'overlay':dest.relative_to(HERE).as_posix(),'sha256':sha(dest),'stripped_equal':True}
    manifest['driver_support']={name:sha(DRIVER.parent/name) for name in ['NativeFlightBounds.as']}
    manifest['new_files']={p:sha(HERE/p) for p in ['src/rconnect/diagnostics/FlightDiagnostics.as','tests/FlightDiagnosticRecorder.as']}
    manifest['method_files']={p:sha(HERE/p) for p in ['make_overlay.py','prepare.py','run.py','analyze.py','test_static.py','README.md']}
    (HERE/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'overlays':5,'driver_original_restored':True,'baseline':BASE_SHA,'JVM':False,'AIR':False}))


if __name__=='__main__':main()
