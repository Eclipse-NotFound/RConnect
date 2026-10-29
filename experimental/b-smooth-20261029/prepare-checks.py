"""Rebuild only the external B observer; freeze installed reference algorithms."""
from pathlib import Path
import argparse, json, os, shutil, subprocess, sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent; RC=HERE.parents[1]
sys.path.insert(0,str(RC/'tools/host_authority/field2_driver'))
import run as r

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--parent',default='prepared-clientenv-installed-02.json');a=ap.parse_args()
    if Path(a.out).name!=a.out or not a.out.startswith('prepared-smooth-') or not a.out.endswith('.json'):raise ValueError('New preparation basename required')
    work=RC/'build/ab/b-field2-runtime-01';game=work/'game'
    if Path(a.parent).name!=a.parent or not a.parent.startswith('prepared-') or not a.parent.endswith('.json'):raise ValueError('Explicit parent preparation basename required')
    oldpath=work/a.parent;old=r.read(oldpath)
    baseline=RC/'build/ab/b-clientenv-bridge-07-build'
    build=r.read(baseline/'build-input.json');r.verify_files(baseline,build['sources'])
    if build['source_id']!='5854ef397c1e96cf24d8b637f32cdc24589502d91fe86cce892a3189b75041dd':raise ValueError('Wrong frozen reference')
    output=work/a.out;folder=work/('driver-'+Path(a.out).stem)
    if output.exists() or folder.exists():raise FileExistsError(output)
    with r.Registration(owner='RConnect B / smooth checks',purpose='Compile external equivalence checks only',run_dir=folder,evidence=output,wait=600) as reg:
        mutable={'pfe.swf','mods/rconnect/release/rconnectmod.swf','mods/rconnect/release/config.txt'}
        r.verify_files(game,{k:v for k,v in old['files'].items() if k.lower() not in mutable})
        for role,seed in old['seeds'].items():
            if r.sha(work/(role+'-save0.sol'))!=seed['sha256']:raise ValueError('Copied seed changed')
        folder.mkdir()
        for pattern in ('BStartupDriverMod.as','B*Cases.as','B*Checks.as','B*Inputs.as','B*Trace.as'):
            for source in r.HERE.glob(pattern):shutil.copy2(source,folder/source.name)
        source=folder/'BStartupDriverMod.as';text=source.read_text(encoding='utf-8')
        anchor='     BDeltaPrefixChecks.run(domain,check);'
        if text.count(anchor)!=1:raise ValueError('Driver seam changed')
        source.write_text(text.replace(anchor,anchor+'\n     BSmoothChecks.run(domain,check);'),encoding='utf-8')
        shutil.copy2(HERE/'BSmoothChecks.as',folder/'BSmoothChecks.as')
        oldpose=baseline/'src/authority/PoseTween.as';oldhealth=baseline/'src/authority/HealthBarPose.as';oldvisual=baseline/'src/authority/VisualPose.as'
        text=oldpose.read_text(encoding='utf-8').split('      private static function close(')[0]+'   }\n}\n'
        text=text.replace('package authority {','package {').replace('class PoseTween','class BSmoothReferenceChecks')
        (folder/'BSmoothReferenceChecks.as').write_text(text,encoding='utf-8')
        text=oldhealth.read_text(encoding='utf-8').replace('package authority {','package {').replace('class HealthBarPose','class BHealthReferenceChecks')
        text=text.replace('VisualPose.','V.').replace('PoseTween.','BSmoothReferenceChecks.')
        seam='   public final class BHealthReferenceChecks {'
        text=text.replace(seam,seam+'\n      private static var V:Object;\n      public static function bind(value:Object):void {V=value;}')
        (folder/'BHealthReferenceChecks.as').write_text(text,encoding='utf-8')
        text=oldvisual.read_text(encoding='utf-8').replace('package authority {','package {').replace('class VisualPose','class BVisualReferenceChecks')
        text=text.replace('Timing.','T.').replace('PixelSurface.','S.').replace('VectorDraw.','D.')
        seam='   public final class BVisualReferenceChecks {'
        text=text.replace(seam,seam+'\n      private static var T:Object,S:Object,D:Object;\n      public static function bind(t:Object,s:Object,d:Object):void {T=t;S=s;D=d;}')
        (folder/'BVisualReferenceChecks.as').write_text(text,encoding='utf-8')
        swf=folder/'BStartupDriverMod.swf'
        command=[str(r.JAVA),'-Xmx512m','-jar',str(r.SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(r.SDK/'frameworks'),'-source-path='+str(folder),'-swf-version=38','-debug=true','-optimize=true','-output='+str(swf),str(source)]
        r.save(folder/'input.json',dict(parent=str(oldpath),parent_sha256=r.sha(oldpath),reference={str(p):r.sha(p) for p in (oldpose,oldhealth,oldvisual)},command=command))
        with (folder/'build.log').open('x',encoding='utf-8') as log:
            reg.before_launch('external observer compiler');p=subprocess.Popen(command,env=dict(os.environ,AIR_HOME=str(r.SDK)),stdout=log,stderr=subprocess.STDOUT);reg.child(p.pid)
            try:
                if p.wait()!=0:raise RuntimeError('Observer compilation failed; log retained')
            finally:
                if p.poll() is None:p.terminate();p.wait()
                reg.child_stopped()
        target=game/'mods/BStartupDriver/release/BStartupDriverMod.swf';shutil.copy2(swf,target)
        files=dict(old['files'])
        for name in files:
            if name.lower()=='mods/bstartupdriver/release/bstartupdrivermod.swf':files[name]=r.sha(target)
        helpers={p.name:r.sha(p) for p in folder.glob('*.as') if p.name!='BStartupDriverMod.as'}
        updated=dict(old,files=files,driver=r.sha(source),helpers=helpers,compiler_command=command,parent_preparation=oldpath.name,parent_sha256=r.sha(oldpath),smooth_reference=str(baseline))
        r.save(output,updated);reg.outcome='passed'
    print(output)
if __name__=='__main__':main()
