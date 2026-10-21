"""Build one isolated native-travel Game patch from the exact installed BEFC host.

Usage (does invoke FFDec when explicitly run):
  python -B tools/validation/prepare_recovery_native_travel.py build/m52/native-travel-host-01

The output must be new. Shared resource=game registration serializes every JVM
invocation; no AIR is launched and no installation/release file is written.
Sources are frozen from their actual bytes at invocation, not stale integration
hashes. Any source/recipe/installation drift during preparation aborts acceptance.

Acceptance covers Game bridge/E4X readback, unchanged normalized representative
class sources, class list, movie header and every non-code tag. It is deliberately
NOT an audit of the semantics of every ABC method, nor native gameplay validation.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import zlib

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT.parents[1]
SOURCE=ROOT/'experimental/recovery-native-travel'
EXPECTED_HOST='befcf0509e11fac9fef7afb834708b8b93752a14ae3d5cd72b42aa6d42f9b82a'
PATCHED='fe.loc.Game'
REPRESENTATIVES=('MainFE','fe.loc.Land','fe.World','fe.graph.Grafon',
                 'fe.serv.Interact','fe.unit.UnitTurret','fe.weapon.Bullet')
GAME_SOURCE='native-import/fe/loc/Game.as'
GAME_REFERENCE='native-export/scripts/fe/loc/Game.as'
HELPER='rconnectTravelXmlFind'


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def digest(data):return hashlib.sha256(data).hexdigest()
def save(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def require(condition,message):
    if not condition:raise ValueError(message)


def normalized(text):
    # Only BOM/newlines/trailing spaces: never normalize names or expressions.
    return '\n'.join(line.rstrip() for line in text.lstrip('\ufeff').splitlines()).strip()+'\n'


def explicit_xml_filters(text):
    require(HELPER not in text,'XML helper already present; refusing an ambiguous second patch')
    queries=(('GameData.d.quest.(@id == id)','GameData.d.quest', 'id',1),
             ('GameData.d.scr.(@id == scr)','GameData.d.scr','scr',2))
    for old,nodes,value,count in queries:
        require(text.count(old)==count,'Native E4X anchor changed: '+old)
        text=text.replace(old,HELPER+'('+nodes+',"id",'+value+')')
    require(not re.search(r'\.\s*\(\s*@',text),'Unexpected E4X filter remains; inspect before import')
    anchor='      public function Game('
    require(text.count(anchor)==1,'Game constructor absent or ambiguous')
    helper='''      private static function rconnectTravelXmlFind(nodes:XMLList, key:String, expected:*) : XMLList
      {
         var result:XMLList = new XMLList();
         for each(var node:XML in nodes)
         {
            if(node.attribute(key) == expected) result += node;
         }
         return result;
      }

'''
    return text.replace(anchor,helper+anchor,1)


def verify_game_readback(text):
    compact=re.sub(r'\s+','',text)
    require(compact.count(HELPER+'(')==4,'Expected one XML helper and exactly three queries')
    require(compact.count(HELPER+'(GameData.d.quest,"id",id)')==1,'Quest lookup lost its caller id')
    require(compact.count(HELPER+'(GameData.d.scr,"id",scr)')==2,'Script lookup lost its caller key')
    require(not re.search(r'\.\s*\(\s*(?:@|([A-Za-z_]\w*)\s*==\s*\1\s*\))',text),
            'Ambiguous or unexpanded E4X filter survived import')
    # FFDec may rename helper parameters/locals. Verify their relationship,
    # rather than requiring the author's spelling or accepting mere keywords.
    match=re.search(r'private\s+static\s+function\s+'+HELPER+
        r'\((\w+):XMLList,\s*(\w+):String,\s*(\w+):\*\)\s*:\s*XMLList\s*\{',text)
    require(match is not None,'Explicit XML helper signature missing after import')
    level=1;end=match.end()
    while end<len(text) and level:
        if text[end]=='{':level+=1
        elif text[end]=='}':level-=1
        end+=1
    require(level==0,'XML helper readback is truncated')
    body=re.sub(r'\s+','',text[match.end():end-1])
    nodes,key,expected=match.groups()
    comparison=re.search(r'(\w+)\.attribute\('+re.escape(key)+r'\)=='+re.escape(expected),body)
    require(comparison is not None and body.count('.attribute(')==1,'Helper must compare the node attribute to the caller value')
    node=comparison[1]
    require(re.search(r'foreach\((?:var)?'+re.escape(node)+r'(?::XML)?in'+re.escape(nodes)+r'\)',body) is not None,
            'XML helper must traverse the supplied nodes')
    result=re.search(r'var(\w+):XMLList=newXMLList\(\);',body)
    require(result is not None,'XML helper result list missing')
    require(result[1]+'+='+node+';' in body and 'return'+result[1]+';' in body,'XML helper result accumulation changed')
    for marker,count in [('publicstaticvarrconnectTravelBridge:Function',1),
                         ('rconnectTravelBridge("adopt",this,null)',1),
                         ('rconnectTravelBridge("announce",this,',1),
                         ('this.Encounter();',1),('newLand(World.w.gg,this.curLand,',1),
                         ('sceneResetGeneration(this.curLand.id)',1),('sceneNativeCall("prepare",[this.curLand.land])',1)]:
        require(compact.count(marker)==count,'Native travel readback anchor changed: '+marker)
    for field in ('constructorLevel','entryCoord','firstVisit','nativeCreate'):
        require('.'+field in compact,'Travel plan field absent after import: '+field)


def source_files():
    paths=[p for folder in ('src','native-import','tests') for p in (SOURCE/folder).rglob('*.as')]
    paths.append(SOURCE/GAME_REFERENCE)
    require(any(p.is_relative_to(SOURCE/'src') for p in paths),'RConnect overlay sources absent')
    require({p.relative_to(SOURCE/'native-import').as_posix() for p in paths
             if p.is_relative_to(SOURCE/'native-import')}=={'fe/loc/Game.as'},'Only Game may be imported')
    return sorted(paths)


def installation_files():
    # Declared audit scope, including all installed mod binaries. Configs may be
    # changed by a running user game; they are neither inputs nor write targets.
    fixed=[GAME/'pfe.swf',GAME/'application.xml',GAME/'mods/loader-manifest.txt']
    fixed.extend(p for p in (GAME/'DLC/pfe.swf',GAME/'DLC/pfeUI.swf') if p.is_file())
    return sorted(set(fixed+list((GAME/'mods').glob('*/release/*.swf'))))


def inventory(paths,root):return {p.relative_to(root).as_posix():sha(p) for p in paths}


def movie_header(path):
    raw=path.read_bytes()
    require(raw[:3] in (b'CWS',b'FWS'),'Unsupported movie compression')
    body=zlib.decompress(raw[8:]) if raw[:3]==b'CWS' else raw[8:]
    length=(5+4*(body[0]>>3)+7)//8+4
    return raw[3:4]+body[:length]  # version, rectangle, frame rate/count; size may change


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    parser.add_argument('--registry-wait',type=float,default=300)
    args=parser.parse_args()
    out=(ROOT/args.output).resolve()
    require(out.parent==(ROOT/'build/m52').resolve() and not out.exists(),'Use a NEW direct child of build/m52')
    require(sha(GAME/'pfe.swf')==EXPECTED_HOST,'Installed host is no longer the approved BEFC build')
    xml=ET.parse(GAME/'application.xml').getroot()
    content=xml.find('.//{*}initialWindow/{*}content')
    require(content is not None and content.text.strip()=='pfe.swf','application.xml no longer selects root pfe.swf')
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,FFDEC
    from patch_native import swf_tags
    sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
    from test_registry import Registration
    require(JAVA.is_file() and FFDEC.is_file(),'Resolve the current Java/FFDec toolchain first')
    source_bytes={p.relative_to(SOURCE).as_posix():p.read_bytes() for p in source_files()}
    sources={name:digest(data) for name,data in source_bytes.items()}
    installed=inventory(installation_files(),GAME)
    tools={str(p.resolve()):sha(p) for p in (Path(__file__),ROOT/'tools/host_authority/common.py',
        ROOT/'tools/host_authority/patch_native.py',GAME/'mods/ModLoader/tools/test_registry.py',JAVA,FFDEC)}
    out.mkdir()
    for name,data in source_bytes.items():
        target=out/'sources'/name;target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb') as stream:stream.write(data)
    prepared=dict(kind='recovery-native-travel-host',experimental_only=True,compiled=False,
        validated=False,runtime_tested=False,deployed=False,original_sha256=EXPECTED_HOST,
        source_root=str(SOURCE),source_inputs=sources,input_sources=sources,input_sources_root='sources',
        recipe_sha256=sha(__file__),tools=tools,installed_before=installed,
        patched_classes=[PATCHED],representative_classes=list(REPRESENTATIVES),
        audit_limit='Selected normalized sources, bridge/XML anchors, class list, movie header and non-code tags; not all ABC methods or gameplay.')
    save(out/'prepared.json',prepared)
    products={}

    def verify_inputs():
        require(inventory(source_files(),SOURCE)==sources,'Live source set changed during preparation')
        require(inventory([out/'sources'/n for n in sources],out/'sources')==sources,'Frozen source bytes changed')
        require(inventory(installation_files(),GAME)==installed,'Installed game/mod binary set changed')
        require(all(sha(p)==h for p,h in tools.items()),'Recipe or toolchain changed during preparation')
        require(all(sha(p)==h for p,h in products.items()),'Generated import/candidate bytes changed during verification')
        if (out/'original.swf').exists():require(sha(out/'original.swf')==EXPECTED_HOST,'Frozen host changed')

    try:
        with Registration(owner='RConnect / 原生旅行桥隔离编译',resource='game',
             purpose='BEFC Game-only native travel patch; FFDec only, no AIR',run_dir=out,
             evidence=out/'prepared.json',wait=args.registry_wait) as record:
            verify_inputs()
            with (out/'original.swf').open('xb') as stream:stream.write((GAME/'pfe.swf').read_bytes())
            verify_inputs()
            def run(arguments,name):
                verify_inputs()
                # Keep stderr separate: FFDec logger warnings can contain paths
                # or timestamps and must not contaminate the class-list output.
                with (out/name).open('x',encoding='utf-8') as log, (out/(name+'.stderr.log')).open('x',encoding='utf-8') as errors:
                    record.before_launch('FFDec / '+name)
                    process=None
                    try:
                        process=subprocess.Popen([str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,arguments)],
                            cwd=out,stdout=log,stderr=errors)
                        record.child(process.pid)
                        code=process.wait()
                        if code:raise subprocess.CalledProcessError(code,arguments)
                    finally:
                        if process is not None:
                            if process.poll() is None:process.terminate()
                            try:process.wait(timeout=10)
                            except subprocess.TimeoutExpired:process.kill();process.wait()
                        record.child_stopped()
                verify_inputs()
            names=','.join((PATCHED,*REPRESENTATIVES))
            run(['-selectclass',names,'-export','script',out/'before',out/'original.swf'],'export.log')
            relative=Path('fe/loc/Game.as')
            before=(out/'before/scripts'/relative).read_text(encoding='utf-8-sig')
            reference=(out/'sources'/GAME_REFERENCE).read_text(encoding='utf-8-sig')
            require(normalized(before)==normalized(reference),'Actual BEFC Game differs from the overlay reference')
            patched=(out/'sources'/GAME_SOURCE).read_text(encoding='utf-8-sig')
            imported=explicit_xml_filters(patched)
            verify_game_readback(imported)
            target=out/'import'/relative;target.parent.mkdir(parents=True)
            target.write_text(imported,encoding='utf-8',newline='\n')
            import_hash=sha(target)
            products[target]=import_hash
            (out/'native-game.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True),imported.splitlines(True),
                fromfile='BEFC/fe/loc/Game.as',tofile='import/fe/loc/Game.as')),encoding='utf-8')
            run(['-importScript',out/'original.swf',out/'pfe.swf',out/'import'],'import.log')
            products[out/'pfe.swf']=sha(out/'pfe.swf')
            require(sha(target)==import_hash,'Import source changed while compiling')
            run(['-selectclass',names,'-export','script',out/'after',out/'pfe.swf'],'verify.log')
            verify_game_readback((out/'after/scripts'/relative).read_text(encoding='utf-8-sig'))
            representatives={}
            for name in REPRESENTATIVES:
                rel=Path(*name.split('.')).with_suffix('.as')
                a=normalized((out/'before/scripts'/rel).read_text(encoding='utf-8-sig'))
                b=normalized((out/'after/scripts'/rel).read_text(encoding='utf-8-sig'))
                require(a==b,'Representative native class changed: '+name)
                representatives[name]=digest(a.encode('utf-8'))
            before_tags,after_tags=swf_tags(out/'original.swf'),swf_tags(out/'pfe.swf')
            require(len(before_tags)==len(after_tags),'SWF tag count changed')
            changed=[]
            for index,(a,b) in enumerate(zip(before_tags,after_tags)):
                require(a[0]==b[0],'SWF tag kind changed')
                if a!=b:
                    require(a[0] in (72,82),'Non-code SWF tag changed: '+str(index))
                    changed.append(index)
            require(bool(changed),'No code change was produced')
            require(movie_header(out/'original.swf')==movie_header(out/'pfe.swf'),'Native movie header changed')
            for label,path in [('before',out/'original.swf'),('after',out/'pfe.swf')]:
                run(['-dumpAS3',path],label+'-classes.txt')
            classes_a=normalized((out/'before-classes.txt').read_text(encoding='utf-8-sig'))
            classes_b=normalized((out/'after-classes.txt').read_text(encoding='utf-8-sig'))
            require(classes_a==classes_b and bool(classes_a.strip()),'Native class listing changed or empty')
            verify_inputs()
            native=dict(kind='recovery-native-travel-host',experimental_only=True,
                original_sha256=EXPECTED_HOST,candidate_sha256=sha(out/'pfe.swf'),
                sources=sources,import_sources={'fe/loc/Game.as':import_hash},
                representative_normalized_sha256=representatives,changed_code_tags=changed,
                non_code_tags_unchanged=True,loader_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True,
                class_list_sha256=digest(classes_a.encode('utf-8')),e4x_queries_checked=3,
                source_set_unchanged=True,installed_modified=False,compiled=True,validated=True,
                gameplay_verified=False,all_abc_semantics_audited=False,script_sha256=sha(__file__))
            save(out/'native-input.json',native)
            prepared.update(native_input_sha256=sha(out/'native-input.json'),compiled=True,validated=True,
                candidate_sha256=native['candidate_sha256'],non_code_tags_unchanged=True,loader_unchanged=True,
                class_list_unchanged=True,representative_normalized_sha256=representatives,
                all_abc_semantics_audited=False)
            record.outcome='passed';record.note='Game 单类编译及限定静态回读通过；未做原生游戏验证、未部署'
    except BaseException as error:
        prepared.update(validated=False,error=str(error),error_type=type(error).__name__)
        raise
    finally:
        # Keep truthful evidence even if compilation or the shared wait failed.
        try:
            prepared['installed_after']=inventory(installation_files(),GAME)
            prepared['installed_unchanged']=prepared['installed_after']==installed
            prepared['source_set_unchanged']=inventory(source_files(),SOURCE)==sources
        except (OSError,ValueError) as error:
            prepared['final_audit_error']=str(error);prepared['validated']=False
        if not prepared.get('installed_unchanged') or not prepared.get('source_set_unchanged'):
            prepared['validated']=False
        prepared['finished_utc_ms']=int(time.time()*1000)
        save(out/'prepared.json',prepared)
    require(prepared['validated'],'Final audit failed; candidate is not accepted')
    print(json.dumps(dict(output=str(out),candidate_sha256=prepared['candidate_sha256'],
                         native_input_sha256=prepared['native_input_sha256'],runtime_tested=False)))


if __name__=='__main__':main()
