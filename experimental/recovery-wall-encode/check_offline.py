"""Source and corpus checks only. Does not execute AS or assume a speed benefit."""
import ast,base64,json,re,struct,zlib
from prepare import HERE,ROOT,BASE,sha,read,write,verify

def main():
    verify();rows=[]
    def check(v,label):
        rows.append(dict(passed=bool(v),label=label));assert v,label
    check(sha(BASE/'RConnectMod.swf')=='1177eb1ae9b227bcf3c0eb39dedad92b63ac16dcb7ffb0b421ea0a2024bfddb1','Exact recovery13 binary and source inputs')
    check((HERE/'src/rconnect/net/RoomCodec.as').exists() is False,'No RoomCodec protocol override')
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8-sig'),str(p))
    check(True,'All Python parses without subprocess launch')
    old=(BASE/'src/rconnect/game/WallImpactVisuals.as').read_text(encoding='utf-8-sig')
    new=(HERE/'src/rconnect/game/WallImpactVisuals.as').read_text(encoding='utf-8')
    for limit in ('MAX_CELLS:int=64','MAX_WIRE:int=48000','WORD_CACHE_ENTRIES:int=128',
                  'WORD_CACHE_WORDS:int=131072','WORD_CACHE_CHARS:int=524288'):
        check(limit in old and limit in new,'Unchanged '+limit)
    check('if(c.v!==undefined)c.wire=wire;' in new,'Unversioned queued cells remain uncached')
    check('var words:Array=decodeWords(String(c.d));' in new,'Pending prediction uses same validated old/new format decoder')
    data=read(HERE/'components/natural-payloads.json')
    check(len(data['payloads'])==82 and len(data['missOrder'])==1276,'Exact historical natural corpus and order')
    all_match=True;max_chars=0
    for item in data['payloads']:
        words=json.loads(zlib.decompress(base64.b64decode(item['data'])))
        raw=struct.pack('>H',len(words)//2)+b''.join(struct.pack('>HI',*words[i:i+2]) for i in range(0,len(words),2))
        encoded='!W1:'+base64.b64encode(zlib.compress(raw)).decode('ascii')
        back=zlib.decompress(base64.b64decode(encoded[4:]));count=struct.unpack_from('>H',back)[0]
        decoded=[v for i in range(count) for v in struct.unpack_from('>HI',back,2+6*i)]
        all_match=all_match and decoded==words and len(back)==2+6*count and count<=1600
        max_chars=max(max_chars,len(encoded))
    check(all_match,'Python format cross-check round-trips all natural offset/uint pairs (not AS execution)')
    check(max_chars<=13340,'All historical new format texts fit explicit per-cell bound')
    source=(HERE/'components/WallEncodeChecks.as').read_text(encoding='utf-8')
    starts=list(re.finditer(r'private function (\w+)\(',source));counts={}
    for i,m in enumerate(starts):counts[m[1]]=len(re.findall(r'\bcheck\(',source[m.end():starts[i+1].start() if i+1<len(starts) else len(source)]))
    actual=counts['naturalCases']+counts['cacheCases']+counts['negativeCases']+counts['pixelCases']+2*counts['transportCases']+counts['benchmark']-1
    check(actual==49,'49 normal AS checks prepared; includes two-side transport loops and excludes catch-all failures')
    check('var order:Array=["old","new","new","old"]' in source and 'if(phase<8)return' in source,
          'Two ABBA rounds use same eight full-corpus encode/cold-decode blocks')
    check('ms:getTimer()-begin' in source and 'resetOutsideTiming:true' in source,
          'Timing excludes fixture creation and cache reset; includes actual production encode/decode')
    profile=read(HERE/'profile-review.json')
    check(len(profile['error_regex_matches'])==2 and all(x['profile_data'] for x in profile['error_regex_matches']),
          'Profile Error regex hits are allocations data in two diagnostic lines, original results unchanged')
    output=dict(passed=True,checks=len(rows),failed=0,assertions=rows,as_checks_prepared=49,
                as_checks_executed=False,JVMStarted=False,AIRStarted=False,performance_qualified=False)
    write('offline-result.json',json.dumps(output,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in output.items() if k!='assertions'},ensure_ascii=False))
if __name__=='__main__':main()
