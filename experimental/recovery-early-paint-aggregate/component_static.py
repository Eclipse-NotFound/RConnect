"""Bounded observer source checks; actual AS compilation/AIR belongs to root."""
from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent
EXPECTED=38
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    helper=(HERE/'tests/PaintTimingBuffer.as').read_text(encoding='utf-8')
    component=(HERE/'tests/PaintTimingBufferChecks.as').read_text(encoding='utf-8')
    checks=[]
    def check(ok,label):assert ok,label;checks.append(label)
    check('LIMIT:int=32' in helper,'important row cap remains 32')
    check('buckets=[bucket("target"),bucket("unbound"),bucket("other")]' in helper,'exactly three fixed room categories')
    check('if(rows.length>=LIMIT){overflow=true;detach();return;}' in helper,'important overflow rejects and detaches')
    check('var stable:Boolean=clocks && residents' in helper and 'v.completed===true' in helper,'only valid completed identity-preserving work can aggregate')
    check('&& sameWorld && sameGame && sameRenderer && sameLoc' in helper,'all identities required before aggregation')
    check('started>=lastFinished && wallStart>=lastWall' in helper,'interval and cross-call clocks must be monotonic')
    check('b.calls++;b.totalMs+=duration;b.maxMs=Math.max' in helper,'positive and zero stable work retained')
    check('if(bucketRooms[index]!==l)b.roomChanges++' in helper,'room transitions retained in fixed state')
    check('phase:"observer-error"' in helper,'malformed callbacks leave important evidence')
    check(helper.index('if(stable)')<helper.index('new Dictionary') if 'new Dictionary' not in helper else
          'if(l!=null && rows.length<LIMIT)' in helper,'object identity dictionary used only under important row cap')
    body=helper.split('      private function receive(',1)[1].split('      public function finish(',1)[0]
    check(all(token not in body for token in ('Log.','JSON.','FileStream','BitmapData')),'callback performs no logging serialization screenshot or file work')
    check(len(re.findall(r'^\s+check\(',component,re.M))==EXPECTED,'38 explicit component assertions')
    check('i<1000' in component and 'i<33' in component,'positive/zero repetition and 32/33 boundary covered')
    check('r.buckets[1].roomChanges==19' in component,'bounded room changes covered')
    value=dict(expected=EXPECTED,passed=len(checks),checks=checks,
       files={p.relative_to(HERE).as_posix():sha(p) for p in (HERE/'tests/PaintTimingBuffer.as',HERE/'tests/PaintTimingBufferChecks.as')},
       compiled=False,air_started=False,performance_qualified=False)
    print(json.dumps(value,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
