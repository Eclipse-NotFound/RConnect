"""Compare every corresponding native test image, including alpha, without tolerance."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image,ImageChops

ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('candidate',type=Path)
    ap.add_argument('--kinds',default='Harness,Destruction,Coverage,Scene,Field')
    ap.add_argument('--label',default='all');args=ap.parse_args()
    out=(ROOT/args.candidate).resolve();assert out.parent==ROOT/'build/m52'
    target=out/'native'/('pixel-comparison-'+args.label+'.json');assert not target.exists()
    rows=[];missing=[]
    for kind in args.kinds.split(','):
        folders=[out/'native/evidence'/role/kind for role in ('control','candidate')]
        for folder in folders:assert json.loads((folder/'receipt.json').read_text())['passed']
        names=[{p.name for p in f.glob('*.png')} for f in folders]
        missing.extend([kind+'/'+n for n in names[0]^names[1]])
        for n in sorted(names[0]&names[1]):
            a,b=[f/n for f in folders]
            with Image.open(a) as src,Image.open(b) as dst:
                x,y=src.convert('RGBA'),dst.convert('RGBA');same=x.size==y.size and x.tobytes()==y.tobytes()
                boxes=[]
                if not same and x.size==y.size:boxes=[band.getbbox() for band in ImageChops.difference(x,y).split()]
                rows.append(dict(name=kind+'/'+n,size=x.size,equal=same,control=sha(a),candidate=sha(b),difference_boxes=boxes))
    result=dict(passed=bool(rows) and not missing and all(r['equal'] for r in rows),missing=missing,images=rows,
        prepared_sha256=sha(out/'native/prepared.json'),comparator_sha256=sha(Path(__file__)))
    target.write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(dict(passed=result['passed'],pairs=len(rows),equal=sum(r['equal'] for r in rows),missing=missing,
        differences=[r['name'] for r in rows if not r['equal']])))
    raise SystemExit(0 if result['passed'] else 1)
if __name__=='__main__':main()
