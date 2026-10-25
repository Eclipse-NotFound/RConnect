"""Exact LAD two-compiler build with shared registration/memory guard; root runs it."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, shutil, subprocess, sys
from xml.sax.saxutils import escape
if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
GAME = ROOT.parents[1]
SOURCE = HERE.with_name('goal-ordinary-lamp-first-raster-candidate')
LAD = GAME/'mods/LightAndDarkness'
TOOLS = GAME/'mods/Sandevistan/build/tools'
SDK = TOOLS/'flexsdk'
AIR = TOOLS/'airsdk/frameworks/libs/air/airglobal.swc'
JAVA = Path('D:/Program Files/Adobe Animate 2024/jre/bin/java.exe')
FFJAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
FFDEC = TOOLS/'ffdec/ffdec-cli.jar'
STUBS = ('fe/unit/Unit.as','fe/weapon/Bullet.as','fe/loc/Box.as','fe/loc/Tile.as')
sys.path.insert(0, str(ROOT/'tools/validation'))
from runtime_memory import snapshot, wait_owned
from run_security_terminals import installation
sys.path.insert(0, str(GAME/'mods/ModLoader/tools'))
from test_registry import Registration


class NotReady(RuntimeError):
    pass


def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return json.loads(Path(p).read_text('utf-8-sig'))
def save(p, v): Path(p).write_text(json.dumps(v, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def inventory(p): return {f.relative_to(p).as_posix():sha(f) for f in sorted(Path(p).rglob('*.as'))}


def source_module():
    assert sha(SOURCE/'prepare.py') == '0aeff76d9c4bfb1ba97af147f7f5392014a559ccbe4f093bf34bf24578597646'
    assert sha(SOURCE/'source-manifest.json') == '09db44feae814b4c08a0d9153cc52bae03459a2606a7e510b8622cf17e4449c6'
    assert sha(SOURCE/'FROZEN.json') == '35d4613fe2a0c90430f0df29f86fe068aa68e8e776cb1e7e76f204b42c8fa951'
    spec=importlib.util.spec_from_file_location('ordinary_lamp_product_source',SOURCE/'prepare.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def checked_inputs(current=True):
    recipe=read(HERE/'recipe.json');assert recipe['kind']=='ordinary-lamp-two-compiler-recipe-v1'
    frozen=read(HERE/'FROZEN.json')
    assert {p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='FROZEN.json'}==frozen['files']
    assert recipe['java']==str(JAVA) and recipe['ffdec_java']==str(FFJAVA) and recipe['sdk']==str(SDK)
    assert not any(os.environ.get(name) for name in ('JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS')), 'Unexpected Java option environment'
    for path,digest in recipe['inputs'].items(): assert sha(path)==digest,path
    meta=source_module().verify()
    assert inventory(LAD/'build/stubs')==recipe['stubs'] and set(recipe['stubs'])==set(STUBS)
    assert meta['candidate_lad_sources']==recipe['sources'] and len(recipe['sources'])==23
    assert recipe['limits']==dict(start_commit_bytes=1024**3,minimum_commit_bytes=512*1024**2,compile_seconds=300,class_seconds=180)
    if current:
        now=installation();assert len(now)==22 and now==recipe['installation_at_preparation']
        assert now['mods/LightAndDarkness/release/LightAndDarknessMod.swf']==meta['base_lad_product_sha256']
    return recipe


def target(value, fresh=False):
    out=(ROOT/Path(value)).resolve()
    assert out.parent==ROOT/'build/m52' and out.name.startswith('goal-ordinary-lamp-product-'),out
    if fresh: assert not out.exists(),out
    return out


def config(sources, libraries):
    paths=''.join('<path-element>'+escape(str(p))+'</path-element>' for p in sources)
    libs=''.join('<path-element>'+escape(str(p))+'</path-element>' for p in libraries)
    return '<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player><compiler><source-path>'+paths+'</source-path><external-library-path>'+libs+'</external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>'


def configurations(out):
    return {'stubs.xml':config([out/'stubs'],[AIR]),
            'candidate.xml':config([out/'src'],[AIR,out/'host-signatures.swc'])}


def commands(out):
    def compiler(name,args):
        return list(map(str,[JAVA,'-Xmx768m','-Dsun.io.useCanonCaches=false','-Djava.util.Arrays.useLegacyMergeSort=true',
            '-jar',SDK/'lib'/name,'+flexlib='+str(SDK/'frameworks')]+args))
    return [compiler('compc.jar',['-load-config='+str(out/'config/stubs.xml'),
                '-include-classes=fe.unit.Unit,fe.weapon.Bullet,fe.loc.Box,fe.loc.Tile','-output='+str(out/'host-signatures.swc')]),
            compiler('mxmlc.jar',['-load-config='+str(out/'config/candidate.xml'),'-swf-version=32','-use-network=false',
                '-static-link-runtime-shared-libraries=true','-includes=lad.native.LadLampTarget',
                '-output='+str(out/'LightAndDarknessMod.swf'),str(out/'src/LightAndDarknessDoc.as')])]


def class_command(out):
    return list(map(str,[FFJAVA,'-Xmx512m','-jar',FFDEC,'-dumpAS3',out/'LightAndDarknessMod.swf']))


def class_list(path):
    values=[]
    for line in Path(path).read_text('utf-8-sig').splitlines():
        if not line.strip() or line.startswith('Picked up '):continue
        name=line.split()[0].replace('\\','/')
        if name.startswith('scripts/') and name.endswith('.as'):name=name[8:-3].replace('/','.')
        else:name=name.replace('::','.')
        values.append(name)
    assert len(values)==len(set(values)), 'Duplicate class entries'
    return sorted(values)


def run_java(out, name, command, record, row, seconds, listing=False):
    memory=snapshot();save(out/(name+'-memory-before.json'),memory)
    assert memory['free_commit_bytes']>=1024**3,'Less than 1 GiB commit headroom before '+name
    row.update(name=name,command=command,pid=None,exit_code=None,reaped=False)
    process=None
    stdout=out/('classes.txt' if listing else name+'.log')
    with stdout.open('w',encoding='utf-8') as log, (out/(name+'-stderr.log')).open('w',encoding='utf-8') as errors:
        try:
            record.before_launch('LAD Java / '+name)
            process=subprocess.Popen(command,cwd=out,stdout=log,stderr=errors,
                                     creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            row['pid']=process.pid;save(out/(name+'-process.json'),row);record.child(process.pid)
            row['exit_code']=wait_owned(process,seconds,out/(name+'-memory.json'))
        finally:
            try:
                if process is not None:
                    if process.poll() is None: process.kill()
                    process.wait(timeout=15)
                    row['process_returncode']=process.returncode;row['reaped']=process.poll() is not None
            finally:
                save(out/(name+'-process.json'),row)
                record.child_stopped()
    assert row['exit_code']==0 and row['reaped'],name+' failed; original output preserved'


def verify(output):
    out=target(output)
    if not (out/'build.json').is_file(): raise NotReady('Actual LAD compilation receipt is absent')
    recipe=checked_inputs(current=False);meta=read(out/'prepared.json');result=read(out/'build.json')
    assert meta['recipe_sha256']==sha(HERE/'recipe.json') and meta['builder_sha256']==sha(__file__)
    assert meta['source_manifest_sha256']==sha(SOURCE/'source-manifest.json')
    assert meta['sources']==recipe['sources']==inventory(out/'src')
    assert meta['stubs']==recipe['stubs']==inventory(out/'stubs')
    for name,text in configurations(out).items():assert (out/'config'/name).read_text('utf-8')==text
    assert meta['installation_before']==recipe['installation_at_preparation']==result['installation_before']==result['installation_after']
    assert all(result[key] is True for key in ('passed','compiled','class_check_passed','installation_unchanged','inputs_unchanged','copies_unchanged','all_children_reaped'))
    assert result['air_started'] is False and result['installed'] is False
    assert len(result['commands'])==2 and [r['command'] for r in result['commands']]==commands(out)
    assert result['class_probe']['command']==class_command(out)
    for row in result['commands']+[result['class_probe']]:
        name=row['name'];assert row['exit_code']==0 and row['reaped'] and type(row['pid']) is int
        assert read(out/(name+'-process.json'))==row
        assert read(out/(name+'-memory-before.json'))['free_commit_bytes']>=1024**3
        memory=read(out/(name+'-memory.json'))
        assert memory['pid']==row['pid'] and memory['reason'] is None and memory['exit_code']==0 and memory['process_returncode']==0
        assert memory['minimum_commit_bytes']==512*1024**2
        assert all(v['free_commit_bytes']>=512*1024**2 for v in memory['rows'])
    actual=class_list(out/'classes.txt');expected=sorted(name[:-3].replace('/','.') for name in recipe['sources'])
    assert actual==expected==result['classes'] and not any(c.startswith('fe.') or 'test' in c.lower() for c in actual)
    assert sha(out/'LightAndDarknessMod.swf')==result['candidate_sha256']
    for name,digest in result['artifacts'].items():assert sha(out/name)==digest,name
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',nargs='?')
    group=parser.add_mutually_exclusive_group();group.add_argument('--check',action='store_true');group.add_argument('--verify',action='store_true')
    parser.add_argument('--registry-wait',type=float,default=900)
    args=parser.parse_args()
    if args.verify:
        if not args.output:parser.error('output required for --verify')
        result=verify(args.output);print(json.dumps(dict(passed=True,candidate_sha256=result['candidate_sha256'])));return
    recipe=checked_inputs()
    if args.check:
        if args.output:target(args.output,True)
        print(json.dumps(dict(ready=True,sources=23,stubs=4,installation=len(recipe['installation_at_preparation']),
                             compiler_commands=2,class_probe_commands=1,compiled=False,air_started=False)));return
    if not args.output:parser.error('output required for actual build')
    out=target(args.output,True);before=installation();out.mkdir()
    result=dict(kind='ordinary-lamp-product-build-v1',passed=False,compiled=False,class_check_passed=False,
                air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
                installation_before=before,commands=[],class_probe={})
    try:
        for label,origin,files in [('src',SOURCE/'lad/src',recipe['sources']),('stubs',LAD/'build/stubs',recipe['stubs'])]:
            for name in files:
                dest=out/label/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(origin/name,dest)
        (out/'config').mkdir()
        for name,text in configurations(out).items():(out/'config'/name).write_text(text,encoding='utf-8')
        save(out/'prepared.json',dict(recipe_sha256=sha(HERE/'recipe.json'),builder_sha256=sha(__file__),
            source_manifest_sha256=sha(SOURCE/'source-manifest.json'),sources=recipe['sources'],stubs=recipe['stubs'],installation_before=before))
        with Registration(owner='RConnect / LAD ordinary first raster',resource='game',
                purpose='isolated LAD compc+mxmlc and read-only class audit; no AIR',run_dir=out,evidence=out/'build.json',wait=args.registry_wait) as record:
            for name,command in zip(('compc','mxmlc'),commands(out)):
                checked_inputs();assert inventory(out/'src')==recipe['sources'] and inventory(out/'stubs')==recipe['stubs']
                row={};result['commands'].append(row);run_java(out,name,command,record,row,300)
            result['compiled']=True;checked_inputs()
            run_java(out,'classes',class_command(out),record,result['class_probe'],180,True)
            actual=class_list(out/'classes.txt');expected=sorted(name[:-3].replace('/','.') for name in recipe['sources'])
            assert actual==expected and not any(c.startswith('fe.') or 'test' in c.lower() for c in actual),actual
            result.update(class_check_passed=True,classes=actual,candidate_sha256=sha(out/'LightAndDarknessMod.swf'))
            checked_inputs();assert inventory(out/'src')==recipe['sources'] and inventory(out/'stubs')==recipe['stubs']
            result['passed']=True;record.outcome='passed';record.note='LAD compiled and exact 23-class audit passed; no AIR/runtime/performance qualification'
    except BaseException as error:
        result['stop_reason']=type(error).__name__+': '+repr(error);raise
    finally:
        try:
            result['installation_after']=installation();result['installation_unchanged']=result['installation_after']==before
            checked_inputs(current=False);result['inputs_unchanged']=True
        except BaseException as error:
            result['inputs_unchanged']=False;result['finalization_error']=type(error).__name__+': '+repr(error)
        result['copies_unchanged']=inventory(out/'src')==recipe['sources'] and inventory(out/'stubs')==recipe['stubs']
        rows=result['commands']+([result['class_probe']] if result['class_probe'] else [])
        result['all_children_reaped']=all(row.get('pid') is None or row.get('reaped') is True for row in rows)
        if not all(result.get(k) is True for k in ('installation_unchanged','inputs_unchanged','copies_unchanged','all_children_reaped')):result['passed']=False
        result['artifacts']={p.relative_to(out).as_posix():sha(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='build.json'}
        save(out/'build.json',result)
    verify(out)
    print(json.dumps(dict(passed=True,candidate_sha256=result['candidate_sha256'],output=str(out))))


if __name__=='__main__':
    main()
