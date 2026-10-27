from pathlib import Path
import shutil,argparse
ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser();ap.add_argument('--revision',default='01',choices=['01','02','03']);args=ap.parse_args()
base=ROOT/'build/ab/b190-field22-source'
source=ROOT/('build/ab/b190-scalar'+args.revision+'-source')
out=ROOT/('build/ab/b190-scalar'+args.revision+'-check-source')
if out.exists():raise FileExistsError(out)
shutil.copytree(source,out)
for name in ('NativeFields','VisualPose','FrameDelta'):
    text=(base/f'src/authority/{name}.as').read_text(encoding='utf-8').replace(name,'Reference'+name)
    (out/f'src/authority/Reference{name}.as').write_text(text,encoding='utf-8')
for path in (Path(__file__).parent/'tests').glob('*.as'):shutil.copy2(path,out/'src/authority'/path.name)
doc=out/'src/RConnectDoc.as'
doc.write_text(doc.read_text(encoding='utf-8').replace('import flash.display.Sprite;', 'import flash.display.Sprite;\n   import authority.VisualMotionChecks;').replace('public static const ENTRY:', 'public static const CHECK:Class=VisualMotionChecks;\n      public static const ENTRY:'),encoding='utf-8')
print(out)
