"""Source/corpus/bit-layout checks only. Python timing is never an AIR estimate."""
import ast,base64,collections,json,re,struct,zlib
from prepare import HERE,ROOT,BASE,ANCESTOR,CODEC,WALL,TABLE,OLD,NEW,sha,read,text,write,verify
def main():
    verify();rows=[]
    def check(v,label):
        rows.append({'passed':bool(v),'label':label});assert v,label
    for p in HERE.glob('*.py'):ast.parse(text(p))
    check(True,'All Python parses; no process launch')
    old=text(BASE/'src'/CODEC);new=text(HERE/'src'/CODEC)
    check(new.replace(TABLE,'').replace(NEW,OLD)==old,'Only alphabet constant and Base64 tail change in exact18 codec')
    check(new.split('public static function unpack',1)[1]==old.split('public static function unpack',1)[1],
        'Complete receiving validation and decoding remain exact source bytes')
    check(new.split('bytes.compress()',1)[0].replace(TABLE,'')==old.split('bytes.compress()',1)[0],
        'Enumeration/key/color checks, Number coercion, sort, uint serialization are unchanged')
    check('bytes.compress();bytes.position=0;' in new and 'if(bytes.length>MAX_COMPRESSED)' in new,
        'Native zlib call and compressed bound remain before Base64 conversion')
    nums=[int(x) for x in re.findall(r'\d+',TABLE.split('new <uint>[',1)[1])]
    check(bytes(nums)==b'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/', 'All 64 literal ASCII codes match existing alphabet')
    def encode(raw):
        out=bytearray()
        for i in range(0,len(raw),3):
            q=raw[i:i+3];a=q[0];b=q[1] if len(q)>1 else 0;c=q[2] if len(q)>2 else 0
            word=(nums[a>>2]<<24)|(nums[((a&3)<<4)|(b>>4)]<<16)|((nums[((b&15)<<2)|(c>>6)] if len(q)>1 else 61)<<8)|(nums[c&63] if len(q)>2 else 61)
            out.extend(struct.pack('>I',word))
        return bytes(out)
    # Independent standard-library Base64 oracle over raw grouping/boundaries.
    probes=[bytes([a]) for a in range(256)]
    probes += [bytes([a,b]) for a in range(256) for b in range(256)]
    probes += [bytes([a,b,c]) for a in range(0,256,7) for b in range(0,256,11) for c in range(0,256,13)]
    check(all(encode(p)==base64.b64encode(p) for p in probes),'Bounded Python bit-layout oracle: all 1/2-byte tails and 17760 triple probes')
    corpus=read(HERE/'components/natural-payloads.json')
    check(len(corpus['payloads'])==82 and len(corpus['missOrder'])==1276,'Natural corpus remains exactly 82 payloads/1276 recorded decode misses')
    check(sha(HERE/'components/natural-payloads.json')==sha(ANCESTOR/'components/natural-payloads.json'),'Natural fixture bytes preserved')
    seen=set();coverage=set();pixels=[]
    for item in corpus['payloads']:
        words=json.loads(zlib.decompress(base64.b64decode(item['data'])));pixels.append(len(words)//2)
        raw=struct.pack('>H',len(words)//2)+b''.join(struct.pack('>HI',*words[i:i+2]) for i in range(0,len(words),2))
        packed=zlib.compress(raw);seen.add(len(packed)%3);coverage.update(packed)
        assert encode(packed)==base64.b64encode(packed)
    check(True,'Python grouping oracle is byte-identical for all 82 naturally sourced maps; not AIR zlib execution')
    source=text(HERE/'components/WallBase64Checks.as');starts=list(re.finditer(r'private function (\w+)\(',source));counts={}
    for i,m in enumerate(starts):counts[m[1]]=len(re.findall(r'\bcheck\(',source[m.end():starts[i+1].start() if i+1<len(starts) else len(source)]))
    inherited=counts['naturalCases']+counts['cacheCases']+counts['negativeCases']+counts['pixelCases']+2*counts['transportCases']+counts['benchmark']-1
    check(inherited==49,'All 49 original whole-WallImpactVisuals semantic checks retained on exact18 classes')
    check(counts['base64Cases']==14,'14 additional exact-byte/padding/coercion/rejection checks prepared')
    check('if(phase<24)return' in source and 'rounds:6,repetitions:3' in source and 'var order:Array=["old","new","new","old"]' in source,
        'Six ABBA groups measure full uncached production packed, not just Base64')
    # CPU stacks only. Avoid allocation tables and avoid printing giant lines.
    log=ROOT/'build/cooperation/a6a7e27789/host.log';stacks=collections.Counter()
    def walk(o):
        if isinstance(o,dict):
            if isinstance(o.get('stacks'),dict):stacks.update({k:v for k,v in o['stacks'].items() if 'WallCellCodec$/pack' in k})
            for k,v in o.items():
                if k!='allocations':walk(v)
        elif isinstance(o,list):
            for v in o:walk(v)
    for line in text(log).splitlines():
        if '"stacks"' in line:walk(json.loads('{'+line.split('{',1)[1]))
    check(sum(stacks.values())==499,'Recorded host profile confirms 499 inclusive pack CPU samples')
    profile={'run':'a6a7e27789','host_log_sha256':sha(log),'pack_inclusive_samples':sum(stacks.values()),
      'reap_below_pack_samples':sum(v for k,v in stacks.items() if '[reap]' in k),
      'sample_stack_counts':stacks.most_common(),'predicted_cpu_saving':None,'native_performance_claim':False}
    write('profile-review.json',json.dumps(profile,indent=2)+'\n')
    result={'assertions':rows,'checks':len(rows),'failed':0,'prepared_AS_checks':63,'AS_executed':False,'JVM_AIR_started':False,
        'python_grouping_probes':len(probes),'natural_pixels':{'min':min(pixels),'max':max(pixels)},
        'python_zlib_remainders':sorted(seen),'python_compressed_byte_coverage':len(coverage),
        'performance_qualified':False,'inputs_manifest_sha256':sha(HERE/'inputs.json')}
    write('offline-result.json',json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'checks':len(rows),'failed':0,'AS_prepared':63,'AS_executed':False,'profile_pack_samples':499}))
if __name__=='__main__':main()
