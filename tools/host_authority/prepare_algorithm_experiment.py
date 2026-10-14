"""Prepare an isolated algorithm experiment; production and installed files stay untouched."""
import argparse, re, shutil
from pathlib import Path
from common import ROOT, EXPERIMENT, inside_build, save, sha

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',required=True);a=ap.parse_args()
    out=inside_build(ROOT/a.output)
    if out.exists():raise FileExistsError(out)
    out.mkdir(parents=True)
    for part in ('src','stubs'):shutil.copytree(EXPERIMENT/part,out/part)
    authority=out/'src/authority'
    source=(authority/'NativeFields.as').read_text(encoding='utf-8')
    source=source.replace('class NativeFields','class AlternativeFields')
    old='var scalar:Boolean=item is Number?isFinite(item):item is String || item is Boolean;'
    if source.count(old)!=1:raise ValueError('Native field seam changed')
    source=source.replace(old,'var kind:String=typeof item;\n            var scalar:Boolean=kind=="number"?isFinite(item):kind=="string" || kind=="boolean";')
    (authority/'AlternativeFields.as').write_text(source,encoding='utf-8')
    scene=(authority/'SceneSnapshot.as').read_text(encoding='utf-8')
    names=re.findall(r'"([A-Za-z0-9_]+)"',re.search(r'TILE:Array=\[(.*?)\];',scene,re.S).group(1))
    condition=' &&\n            '.join('value.'+name+'===before['+str(i)+']' for i,name in enumerate(names))
    values=','.join('value.'+name for name in names)
    terrain='''package authority {
   /** Fixed schema, direct property reads; every tile and field is still examined. */
   public final class TerrainScan {
      public static function capture(value:Object,before:Array):Array {
         if(before!=null && CONDITION)return before;
         return [VALUES];
      }
   }
}
'''.replace('CONDITION',condition).replace('VALUES',values)
    (authority/'TerrainScan.as').write_text(terrain,encoding='utf-8')
    shutil.copy2(Path(__file__).parent/'algorithm_profile/AlgorithmProfile.as',authority/'AlgorithmProfile.as')
    p=authority/'Probe.as';s=p.read_text(encoding='utf-8')
    old='FieldProfile.run(access,check);PoseProfile.run(access,check);'
    if s.count(old)!=1:raise ValueError('Profile seam changed')
    p.write_text(s.replace(old,'AlgorithmProfile.run(access,check);'),encoding='utf-8')
    save(out/'experiment.json',dict(purpose='typeof scalar classification and direct terrain reads',production_sha256={p.relative_to(EXPERIMENT).as_posix():sha(p) for p in EXPERIMENT.rglob('*.as')},tile_schema=names))
    print(out)
if __name__=='__main__':main()
