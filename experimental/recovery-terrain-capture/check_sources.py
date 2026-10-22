"""Pure Python source equivalence audit, not AS execution or runtime qualification."""
import hashlib,json,re
from prepare import HERE,ROOT,BASE,REL,OLD,NEW,planned,sha

def method(source,name):
    match=re.search(r'\bfunction\s+'+name+r'\s*\(',source);assert match,name
    start=source.index('{',match.start());depth=1;at=start+1
    # The relevant sources have no brace-containing strings in these methods.
    while depth:
        depth+=(source[at]=='{')-(source[at]=='}');at+=1
    return source[match.start():at]

def main():
    checks=[]
    def check(ok,label):
        checks.append(dict(passed=bool(ok),label=label));assert ok,label
    files,inputs=planned()
    for name,raw in files.items():check((HERE/name).read_bytes()==raw,'exact generated '+name)
    before=(BASE/'src'/REL).read_text('utf-8-sig');after=(HERE/'src'/REL).read_text('utf-8-sig')
    check(after.count(NEW)==1 and after.replace(NEW,OLD)==before,'only capture guard differs in full production class')
    for name in ('matchesTile','matchesDynamicTile','state','dynamicState','enter','hostPatch','report','finishReports','apply','settle','acknowledge','checkpoint','restoreCheckpoint'):
        check(method(before,name)==method(after,name),'unchanged entire '+name)
    check('var native:Tile=t as Tile;' in method(after,'capture') and 'old.p===native.phis && old.h===native.hp' in method(after,'capture'),'native-only strict two-field damage observer')
    check('} else if(matchesTile(t,old)) continue;' in method(after,'capture'),'dynamic fallback keeps old comparison')
    check(method(before,'capture').replace(OLD,NEW)==method(after,'capture'),'capture damage accumulation and observed assignment unchanged')
    comp=(HERE/'components/TerrainCaptureChecks.as').read_text('utf-8')
    expected=0;counts={}
    for name in ('basic','visualFields','permissions','prediction','closing','settlement','checkpoint','dynamicFallback','largeSetup','measure','largeVerify'):
        text=method(comp,name)
        n=len(re.findall(r'\bcheck\(',text))+len(re.findall(r'\bsame\(',text))+len(re.findall(r'\breport\(p,|\breport\(bench,',text))
        if name=='visualFields':n+=40 # Four checks in eleven iterations, rather than one.
        if name=='measure':n*=4
        counts[name]=n;expected+=n
    check(expected==154,'planned 154 runtime assertions including 11 visual fields and ABBA')
    check('same(p.a.checkpoint(p.ra),p.b.checkpoint(p.rb)' in comp and 'NativeRoomState.scalars' in comp,'complete checkpoint and native scalar comparison present')
    check('a.calls,b.calls' in comp and 'frontDamage=1' in comp and 'currentHp=NaN' in comp,'getter order, side effects, NaN counterexamples present')
    timing=method(comp,'measure');start=timing.index('start:int=getTimer()');end=timing.index('var elapsed:int=getTimer()-start;')
    timed=timing[start:end]
    check('sync.report(loc)' in timed and all(s not in timed for s in ('check(','same(','JSON','new ')),'timed loop excludes setup/assertions/serialization')
    check('pair(240,125)' in comp and 'for(var i:int=0;i<5;i++)' in timing,'30000 identical native cells and five scans per slot')
    check('performance_qualified:false' in comp and 'native_game:false' in comp,'component explicitly not native game or performance qualification')
    for p in HERE.glob('*.py'):compile(p.read_text('utf-8'),str(p),'exec')
    meta=json.loads((HERE/'inputs.json').read_text('utf-8-sig'))
    check(all(sha(HERE/n)==h for n,h in meta['sources'].items()),'all recorded AS inputs match')
    result=dict(passed=len(checks),failed=0,checks=checks,expected_runtime_assertions=expected,
        assertion_plan=counts,compiled=False,runtime_tested=False)
    (HERE/'static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    manifest=dict(inputs=inputs,compiled=False,runtime_tested=False,expected_runtime_assertions=expected,
        files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='source-manifest.json' and '__pycache__' not in p.parts})
    (HERE/'source-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k not in ('checks','assertion_plan')}))
if __name__=='__main__':main()
