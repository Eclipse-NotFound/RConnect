"""Check text provenance, unchanged methods, and fixture bounds; no runtime."""
from pathlib import Path
import ast, hashlib, json, re, zlib, base64
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-02/src'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig')

def masked(s):
    return re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27',
                  lambda m:' '*len(m.group()),s)

def methods(s):
    clean=masked(s);out={}
    for m in re.finditer(r'\b(?:public|private)\s+(?:static\s+)?function\s+(\w+)\(',clean):
        a=clean.index('{',m.end());b=a+1;depth=1
        while depth:depth+=(clean[b]=='{')-(clean[b]=='}');b+=1
        assert m[1] not in out,m[1]
        out[m[1]]=s[m.start():b]
    return out

def main():
    for name in ('prepare.py','check_static.py'):ast.parse(read(HERE/name))
    inputs=json.loads(read(HERE/'inputs.json'))
    for rel,h in inputs['base_inputs'].items():assert sha(BASE/rel)==h,rel
    for rel,h in inputs['overlay'].items():assert sha(HERE/'src'/rel)==h,rel
    for rel,h in inputs['components'].items():assert sha(HERE/'components'/rel)==h,rel
    before=read(BASE/'rconnect/game/WallImpactVisuals.as')
    after=read(HERE/'src/rconnect/game/WallImpactVisuals.as')
    old=methods(before);new=methods(after)
    untouched=set(old)-{'decode','reset'}
    for name in untouched:assert old[name]==new[name],name
    a=old['decode'].index('               var words:Array=RoomCodec.unpack')
    b=old['decode'].index('               seen[k]=true;',a)
    assert new['decode'].replace('               var words:Array=decodeWords(String(c.d));\n               if(words==null)return null;\n',old['decode'][a:b])==old['decode']
    assert new['reset'].replace('\n         wordCache=new Dictionary();wordOrder=[];wordCount=0;wordChars=0;','')==old['reset']
    for suffix,source in [('Before',before),('After',after)]:
        fixture=read(HERE/('components/rconnect/game/Wall'+suffix+'.as'))
        fixture=fixture.replace('class Wall'+suffix,'class WallImpactVisuals').replace('function Wall'+suffix+'(','function WallImpactVisuals(')
        fixture=fixture.replace('      public function decode(','      private function decode(')
        if suffix=='After':fixture=fixture.replace('      public function cacheStats():Object {return {entries:wordOrder.length,words:wordCount,chars:wordChars};}\n','')
        assert fixture==source,suffix
    codec=read(HERE/'components/rconnect/net/RoomCodec.as').replace('\n         DecodeCounter.calls++;','')
    assert codec==read(BASE/'rconnect/net/RoomCodec.as')
    assert read(HERE/'components/rconnect/net/BinaryMessageCodec.as')==read(BASE/'rconnect/net/BinaryMessageCodec.as')
    for folder in ('src','components'):
        for p in (HERE/folder).rglob('*.as'):
            s=masked(read(p));stack=[];pairs={')':'(',']':'[','}':'{'}
            for c in s:
                if c in '([{':stack.append(c)
                elif c in ')]}':assert stack and stack.pop()==pairs[c],str(p)
            assert not stack,str(p)
            methods(read(p))
    checks=read(HERE/'components/RecoveryWallDecodeChecks.as');run=checks[checks.index('      private function run():void'):]
    sites=len(re.findall(r'\b(?:check|equal|pair|bounded)\(',run))
    # Three loops contain assertions: 14 malformed payloads, 3 coercion cases,
    # 8 invalid envelopes. Remaining loops only construct fixtures or fill cache.
    expected=sites+2*(14-1)+3*(3-1)+2*(8-1);assert expected==120 and inputs['expected_component_assertions']==expected
    dense=[]
    for i in range(1600):dense.extend([i,200])
    dense_chars=len(base64.b64encode(zlib.compress(json.dumps(dense,separators=(',',':')).encode())))
    assert dense_chars*12<131072 and 3200*11>32768
    n=700;spaces=[]
    for i in range(80000):n=(n*1664525+1013904223)&0xffffffff;spaces.append(' \t\r\n'[n>>30])
    padded_chars=len(base64.b64encode(zlib.compress((''.join(spaces)+'[0,700]').encode())))
    assert padded_chars*13>131072 and padded_chars<131072
    result={'unchanged_methods':sorted(untouched),'outer_decode_checks_preserved':True,'reset_only_adds_cache_clear':True,
      'fixture_source_transform_verified':True,'expected_normal_assertions':expected,'assertions_executed':0,
      'python_fixture_sizes_only':{'dense_constant_encoded_chars':dense_chars,'padded_encoded_chars':padded_chars},
      'compiled':False,'runtime_tested':False}
    (HERE/'static-checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'unchanged_methods':len(untouched),'expected_assertions':expected,'runtime_tested':False}))

if __name__=='__main__':main()
