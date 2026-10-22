"""Offline source/byte checks only. This is not an AS3 compiler or runtime test."""
import base64,json,random,re,struct,zlib
from prepare import HERE,ROOT,DIGITS,sha,read,text,verify,write
def base64_bytes(s,fast):
 if len(s)==0 or len(s)%4:return None
 out=bytearray()
 for i in range(0,len(s),4):
  codes=[ord(x) for x in s[i:i+4]]
  if fast:values=[DIGITS.find(chr(c)) if c<128 else -1 for c in codes]
  else:values=[DIGITS.find(x) for x in s[i:i+4]]
  a,b,c,d=values;pc=codes[2]==61;pd=codes[3]==61
  if (a<0 or b<0 or (c<0 and not pc) or (d<0 and not pd) or (pc and not pd)
      or ((pc or pd) and i+4!=len(s)) or (pc and b&15) or (pd and not pc and c&3)):return None
  if fast and not pc:out.extend(struct.pack('>H',(a<<10)|(b<<4)|(c>>2)))
  else:
   out.append(((a<<2)|(b>>4))&255)
   if not pc:out.append(((b<<4)|(c>>2))&255)
  if not pd:out.append(((c<<6)|d)&255)
 return bytes(out)
def main():
 verify();checks=[]
 def check(ok,label):assert ok,label;checks.append(label)
 table=[int(x) for x in re.search(r'REVERSE:Vector\.<int> = new <int>\[([^]]+)\]',text(HERE/'src/rconnect/net/WallCellCodec.as')).group(1).split(',')]
 check(len(table)==128 and all((table[i] if i<128 else -1)==DIGITS.find(chr(i)) for i in range(65536)),
   'All 65536 UTF-16 code units retain alphabet classification; table is bounded at 128')
 check(all(struct.pack('>H',(a<<10)|(b<<4)|(c>>2))==bytes([((a<<2)|(b>>4))&255,((b<<4)|(c>>2))&255])
   for a in range(64) for b in range(64) for c in range(64)),
   'All 262144 first-three-digit combinations retain the exact first two bytes')
 alphabet=DIGITS+'=\x00\t\n \x7f\x80\xff\u0100\ud800\uffff'
 rng=random.Random(20261022);corpus=[''.join(rng.choice(alphabet) for _ in range(rng.randrange(0,40))) for _ in range(12000)]
 corpus.extend(base64.b64encode(bytes(rng.randrange(256) for _ in range(n))).decode() for n in range(1025))
 check(all(base64_bytes(s,False)==base64_bytes(s,True) for s in corpus),'13025 deterministic valid/malformed Base64 byte-stream models agree')
 summary=read(ROOT/'experimental/recovery-socket-batch-review/summary.json')
 totals={role:{k:sum(s[k] for s in values['stages']) for k in ('batches','messages','full','fast','multiple_full_batches')} for role,values in summary['roles'].items()}
 check(totals['join']==dict(batches=823,messages=1640,full=240,fast=648,multiple_full_batches=0),'Actual seven-stage join counts independently summed: 823 batches, 240 full, zero multiple-full')
 packet_sizes=[]
 for count,seeds in ((1200,range(151,156)),(1000,range(121,127))):
  sizes=[]
  for seed in seeds:
   n=seed;raw=bytearray(struct.pack('>H',count))
   for i in range(count):
    n=(n^(n<<13))&0xffffffff;n=(n^(n>>17))&0xffffffff;n=(n^(n<<5))&0xffffffff;raw.extend(struct.pack('>HI',i,n))
   encoded=base64.b64encode(zlib.compress(raw)).decode();sizes.append(4+len(encoded))
   check(base64_bytes(encoded,True)==zlib.compress(raw),'Representative binary cell bytes agree: '+str(seed))
  packet_sizes.append(dict(cells=len(sizes),pixels_per_cell=count,chars=sum(sizes),per_cell_chars=sizes))
 check(all(40000<=s['chars']<=48000 for s in packet_sizes),'Synthetic five/six-cell packets fit observed scale and unchanged 48k envelope (Python zlib; AS sizes still asserted)')
 check(text(HERE/'components/WallDecodeChecks.as').count('check(')==text(ROOT/'experimental/recovery-wall-encode/components/WallEncodeChecks.as').count('check(')+18,
   'Source adds 17 semantic checks plus one corpus bound check; successful runtime expected 67, ancestor 49')
 result=dict(static_checks=checks,passed=True,as_compiled=False,air_run=False,expected_runtime_checks=67,
  evidence=dict(socket_summary_sha256=sha(ROOT/'experimental/recovery-socket-batch-review/summary.json'),run=summary['run'],totals=totals,
   representative_python_zlib=packet_sizes),performance_qualified=False)
 write('static-result.json',json.dumps(result,indent=2)+'\n');print(json.dumps({'static_checks':len(checks),'passed':True,'as_compiled':False,'expected_runtime_checks':67}))
if __name__=='__main__':main()
