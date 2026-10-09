"""Read-only RV source study: keep the proposed change entirely in RConnect.

Does not write/build/deploy RealisticVision. Produces a reviewable diff and a
deterministic bit-cache equivalence check; no runtime/FPS claim is made.
"""
from pathlib import Path
import difflib, hashlib, json, random
ROOT=Path(__file__).resolve().parents[2]
source=ROOT.parent/'RealisticVision/src/RealisticVisionMod.as'
out=ROOT/'build/m51/vision-cache-proposal-01'
out.mkdir(parents=True,exist_ok=False)
original=source.read_text(encoding='utf-8-sig')
proposed=original
def replace(before,after):
    global proposed
    assert proposed.count(before)==1,before
    proposed=proposed.replace(before,after)
replace('      private var sharedRooms:Dictionary',
        '      // Packed local subcell history; brightness is still sampled each call.\n'
        '      private var explorationBits:Array;\n      private var sharedRooms:Dictionary')
replace('         this.fullySeen = new Array(n);',
        '         this.fullySeen = new Array(n);\n         this.explorationBits = new Array(n);')
replace('bits = "ffffffffffffffff";\n               else\n',
        'bits = "ffffffffffffffff";\n               else if(this.explorationBits[i] != null) bits = this.explorationBits[i];\n               else\n')
replace('                     bits += EXP_HEX.charAt(nibble);\n                  }\n               }',
        '                     bits += EXP_HEX.charAt(nibble);\n                  }\n                  this.explorationBits[i] = bits;\n               }')
for line in [
    '                           this.seenSub[(ty * FOG_SUB + (sy == 0 ? 0 : FOG_SUB-1)) * this.subW + (tx * FOG_SUB + (sx == 0 ? 0 : FOG_SUB-1))] = 1;',
    '                  this.seenSub[(ty * FOG_SUB + sy) * this.subW + (tx * FOG_SUB + sx)] = 1;']:
    replace(line,line+'\n'+line[:len(line)-len(line.lstrip())]+'this.explorationBits[tx + ty * this.spaceX] = null;')
patch=''.join(difflib.unified_diff(original.splitlines(True),proposed.splitlines(True),
    fromfile='a/src/RealisticVisionMod.as',tofile='b/src/RealisticVisionMod.as'))
(out/'RealisticVisionMod.proposed.as').write_text(proposed,encoding='utf-8')
(out/'exploration-cache.patch').write_text(patch,encoding='utf-8')

hexchars='0123456789abcdef'
def native_bits(subcells):
    return ''.join(hexchars[sum((1<<q) if subcells[b+q]==1 else 0 for q in range(4))] for b in range(0,64,4))
rng=random.Random(51023)
comparisons=0
for room in range(5):
    seen=[[0]*64 for _ in range(72)]
    full=[False]*72;explored=[False]*72;cache=[None]*72
    for step in range(240):
        index=rng.randrange(72)
        # The two partial visibility write sites invalidate that one tile.
        for _ in range(rng.randrange(1,8)):seen[index][rng.randrange(64)]=1
        cache[index]=None
        if step%17==0:full[index]=True;seen[index]=[1]*64
        explored[index]=bool(rng.randrange(2))
        classic=step%23<6
        for i in range(72):
            expected='f'*16 if full[i] or classic and explored[i] else native_bits(seen[i])
            if full[i] or classic and explored[i]:actual='f'*16
            else:
                if cache[i] is None:cache[i]=native_bits(seen[i])
                actual=cache[i]
            assert expected==actual,(room,step,i)
            # Brightness is recomputed by the unchanged native expression.
            light=hexchars[rng.randrange(16)]
            assert light+expected==light+actual
            comparisons+=1
report=dict(status='proposal-only',original_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
    proposed_sha256=hashlib.sha256(proposed.encode()).hexdigest(),comparisons=comparisons,
    changes='6 local additions: cache field/reset/read/write and 2 partial-history invalidations',
    scope='local history encoding only; light/FOV/paint/100 ms publication unchanged',
    boundary='Python deterministic equivalence model, not compiled AIR or native runtime validation',
    actual_source_unchanged=hashlib.sha256(source.read_bytes()).hexdigest())
(out/'equivalence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
