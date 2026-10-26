"""Merge reviewed B190 overlays against the same frozen source, fail on overlap."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, tempfile, re

ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);ap.add_argument('--security',action='store_true');ap.add_argument('--motion-experiment',action='store_true');ap.add_argument('--grab-selection',action='store_true');ap.add_argument('--terrain-bounds',action='store_true');a=ap.parse_args()
if a.terrain_bounds and (not a.security or not a.grab_selection or a.motion_experiment):raise ValueError('Terrain bounds overlay requires the exact field21 feature set')
base=ROOT/'build/ab/b190-field9-build';out=(ROOT/a.output).resolve()
if not out.is_relative_to((ROOT/'build/ab').resolve()) or out.exists():raise ValueError('New isolated build/ab destination required')
manifest=json.loads((base/'build-input.json').read_text(encoding='utf-8'))
for name,digest in manifest['sources'].items():
 if hashlib.sha256((base/name).read_bytes()).hexdigest()!=digest:raise ValueError('Frozen source mismatch: '+name)
out.mkdir(parents=True)
for folder in ['src','stubs']:shutil.copytree(base/folder,out/folder)
overlays=['b-field-controls','b-field-ui-fixes','b-field-sync-fixes']+(['b-field-security'] if a.security else [])+(['b-field-motion-fixes'] if a.motion_experiment else [])
receipt=[]
for overlay in overlays:
 for path in sorted((ROOT/'experimental'/overlay/'src').rglob('*.as')):
  name=path.relative_to(ROOT/'experimental'/overlay);target=out/name;original=base/name
  # First measure the guarded importer without changing runtime call sites.
  if a.motion_experiment and overlay=='b-field-motion-fixes' and name.as_posix()=='src/authority/ClientReplica.as':continue
  target.parent.mkdir(parents=True,exist_ok=True)
  if not target.exists():shutil.copy2(path,target)
  elif target.read_bytes()==original.read_bytes():shutil.copy2(path,target)
  else:
   inputs=[]
   for label,p in [('current',target),('base',original),('overlay',path)]:
    normalized=out/('_merge-'+label+'.txt');normalized.write_text(p.read_text(encoding='utf-8-sig'),encoding='utf-8',newline='\n');inputs.append(str(normalized))
   result=subprocess.run(['git','merge-file','--stdout',*inputs],capture_output=True)
   if result.returncode and overlay=='b-field-security' and name.as_posix()=='src/authority/PlayerActor.as':
    merged=result.stdout.decode('utf-8');blocks=re.findall(r'(?ms)^<<<<<<< .*?^>>>>>>> .*?\n',merged)
    if len(blocks)==1 and 'sight.withCursorLight' in blocks[0] and 'security.player(actor,stepNative)' in blocks[0]:
     merged=merged.replace(blocks[0],'''               try {
                  var stepNative:Function=function():void {
                     sight.withCursorLight(input.aimX,input.aimY,function():void {
                        PlayerPointer.run(actor,input,function():void {unit.step();});
                     });
                  };
                  if(security!=null)security.player(actor,stepNative);else stepNative();
               }
''')
     result=subprocess.CompletedProcess(result.args,0,merged.encode('utf-8'),result.stderr)
   if result.returncode:
    (out/(target.stem+'-conflict.txt')).write_bytes(result.stdout)
    raise RuntimeError('Review conflicting overlay '+overlay+': '+str(name))
   target.write_bytes(result.stdout)
  receipt.append({'overlay':overlay,'path':name.as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
if a.security:
 actor=out/'src/authority/PlayerActor.as';text=actor.read_text(encoding='utf-8')
 assert text.count('actionText:interaction.actionText')==1
 actor.write_text(text.replace('actionText:interaction.actionText','actionText:security!=null?security.capture(interaction,id).actionText:interaction.actionText'),encoding='utf-8')
if a.grab_selection:
 secondary=ROOT/'build/ab/b190-field14-build'
 secondary_manifest=json.loads((secondary/'build-input.json').read_text(encoding='utf-8'))
 for name,digest in secondary_manifest['sources'].items():
  if hashlib.sha256((secondary/name).read_bytes()).hexdigest()!=digest:raise ValueError('Field14 source changed: '+name)
 for path in sorted((ROOT/'experimental/b-field-grab-selection/src').rglob('*.as')):
  name=path.relative_to(ROOT/'experimental/b-field-grab-selection');target=out/name;original=secondary/name
  if not original.exists():
   if target.exists():raise ValueError('New selection class collision')
   shutil.copy2(path,target)
  else:
   inputs=[]
   for label,p in [('current',target),('base',original),('overlay',path)]:
    normalized=out/('_merge-'+label+'.txt');normalized.write_text(p.read_text(encoding='utf-8-sig'),encoding='utf-8',newline='\n');inputs.append(str(normalized))
   result=subprocess.run(['git','merge-file','--stdout',*inputs],capture_output=True)
   if result.returncode:
    (out/(target.stem+'-selection-conflict.txt')).write_bytes(result.stdout)
    raise RuntimeError('Selection merge requires review: '+str(name))
   target.write_bytes(result.stdout)
  receipt.append({'overlay':'b-field-grab-selection','base_source':secondary_manifest['source_id'],'path':name.as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
if a.terrain_bounds:
 secondary=ROOT/'build/ab/b190-field21-build'
 secondary_manifest=json.loads((secondary/'build-input.json').read_text(encoding='utf-8'))
 for name,digest in secondary_manifest['sources'].items():
  if hashlib.sha256((secondary/name).read_bytes()).hexdigest()!=digest:raise ValueError('Field21 source changed: '+name)
 name=Path('src/authority/SceneSnapshot.as')
 target=out/name;original=secondary/name;path=ROOT/'experimental/b-field-terrain-bounds-fix'/name
 if target.read_text(encoding='utf-8-sig')!=original.read_text(encoding='utf-8-sig'):raise ValueError('Terrain bounds base differs from reviewed field21')
 shutil.copy2(path,target)
 receipt.append({'overlay':'b-field-terrain-bounds-fix','base_source':secondary_manifest['source_id'],'path':name.as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
stamp=out/'src/authority/BuildInfo.as';text=stamp.read_text(encoding='utf-8')
text=text.replace(manifest['source_id'],'__SOURCE_HASH__');stamp.write_text(text,encoding='utf-8')
version=out/'src/RConnectMod.as';text=version.read_text(encoding='utf-8').replace('B3-0.1-field3','B3-0.1-field4');version.write_text(text,encoding='utf-8')
if a.motion_experiment:
 text=version.read_text(encoding='utf-8').replace('B3-0.1-field4','B3-0.1-motion-experiment')
 anchor='public class RConnectMod'
 assert anchor in text
 # Link component checks without invoking or scheduling them in gameplay.
 point=text.index('{',text.index(anchor))+1
 text=text[:point]+'\n      public static const motionExperimentChecks:Class=authority.VisualMotionChecks;\n'+text[point:]
 version.write_text(text,encoding='utf-8')
(out/'assembly.json').write_text(json.dumps({'baseline':str(base),'baseline_source':manifest['source_id'],'overlays':receipt},indent=2),encoding='utf-8')
print(out)
