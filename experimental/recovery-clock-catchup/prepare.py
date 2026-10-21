"""Derive one isolated recovery09 clock change and real-class AS replays; no subprocess."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-09/src/rconnect/game'
PIN='cd58b1286bc913149ac02ad60713e82c251b8e574043444b4f3ccfd6e4a2ebc5'
BASE_BINARY='1507686cd0811f6e6697a663ceed08ed7f85c8562399d50ccc79a891f8503acf'
LOG=ROOT/'build/cooperation/dae70df14b/join.log'
LOG_SHA='14b891469c6ad35a94d5c8d242c0ff9e424c497d53e638ef3a1c47209ac752f0'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def one(s,a,b):
    assert s.count(a)==1,a
    return s.replace(a,b,1)
def write(p,s):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(s.encode('utf-8'))
def method(s,name):
    # These three dependency functions contain no braces inside strings/comments.
    start=s.index('      '+name);brace=s.index('{',start);depth=1;i=brace+1
    while depth:
        if s[i]=='{':depth+=1
        elif s[i]=='}':depth-=1
        i+=1
    return s[start:i]

def sources():
    assert sha(BASE.parents[2]/'RConnectMod.swf')==BASE_BINARY
    assert sha(BASE/'RemoteMotion.as')==PIN
    assert sha(ROOT/'build/m52/recovery-08/src/rconnect/game/RemoteMotion.as')==PIN
    old=(BASE/'RemoteMotion.as').read_text(encoding='utf-8')
    new=one(old,'      private var playbackRate:Number=1;', '''      private var playbackRate:Number=1;
      // Ordinary actor clocks only. Keep calibration debt separate from packet
      // jitter: a series of small offset corrections must not create seconds
      // of catch-up at 1.1x. No receive callback seeks this display cursor.
      private var calibrationDebt:Number=0;
      private var calibrationRate:Number=1;
      private var calibrating:Boolean=false;
      private function actorCalibration():Boolean {return !immediateStart && bufferLimit==0;}
      private function clearCalibration():void {
         calibrationDebt=0;calibrationRate=1;calibrating=false;
      }''')
    new=one(new,'         frames=[];\n         preceding=null;', '         frames=[];\n         clearCalibration();\n         preceding=null;')
    new=one(new,'      public function settle(now:int):Object {','      public function settle(now:int):Object {\n         clearCalibration();')
    new=one(new,'            playbackRate=1;\n            offset=clockOffset;', '            playbackRate=1;clearCalibration();\n            offset=clockOffset;')
    new=one(new,'            if(!immediateStart && correction>Math.max(100,interval*2))cursor+=correction;', '''            if(actorCalibration()) {
               // A teleport or room identity boundary ends the old recovery.
               if(port || last.snap.roomKey!=snap.roomKey || last.snap.roomEpoch!=snap.roomEpoch)
                  clearCalibration();
               else calibrationDebt+=correction;
            } else if(!immediateStart && correction>Math.max(100,interval*2))cursor+=correction;''')
    new=one(new,'         if(rateHeld()) {playbackRate=1;cursor=next;}', '''         var beforeCursor:Number=cursor;
         if(rateHeld()) {
            playbackRate=1;calibrationRate=1;calibrating=false;cursor=next;
         }''')
    new=one(new,'         } else cursor=next+Math.max(-elapsed*.1,Math.min(elapsed*.1,wanted-next));', '''         } else if(actorCalibration()) {
            var ordinary:Number=next+Math.max(-elapsed*.1,Math.min(elapsed*.1,wanted-next));
            // Only real elapsed time may retire debt or change the recovery
            // speed. Repeated RENDER/sample calls at one timestamp stay inert.
            if(elapsed>0)calibrationDebt=Math.min(calibrationDebt,Math.max(0,wanted-next));
            if(!calibrating && calibrationDebt>Math.max(100,interval*2)) {
               calibrating=true;
            }
            if(calibrating && elapsed>0) {
               var ordinaryRate:Number=(ordinary-beforeCursor)/elapsed;
               var desiredCalibrationRate:Number=calibrationDebt>0
                  ?Math.max(ordinaryRate,1+Math.min(.5,calibrationDebt/200)):ordinaryRate;
               var previousRate:Number=calibrationRate;
               calibrationRate+=Math.max(-elapsed*.003,Math.min(elapsed*.003,desiredCalibrationRate-calibrationRate));
               // Integrate a continuous speed ramp, bounded to 0.9--1.5x.
               cursor+=elapsed*(previousRate+calibrationRate)*.5;
               if(calibrationDebt==0 && calibrationRate==ordinaryRate)calibrating=false;
            } else {
               cursor=ordinary;
               if(elapsed>0)calibrationRate=(ordinary-beforeCursor)/elapsed;
            }
         } else cursor=next+Math.max(-elapsed*.1,Math.min(elapsed*.1,wanted-next));''')
    new=one(new,'         cursor=Math.min(cursor,Number(latest.at));', '''         cursor=Math.min(cursor,Number(latest.at));
         if(actorCalibration() && elapsed>0)
            calibrationDebt=Math.max(0,calibrationDebt-Math.max(0,cursor-beforeCursor-elapsed));''')
    return old,new

def trace():
    assert sha(LOG)==LOG_SHA
    rows=[]
    for line in LOG.read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('FLIGHT TIMING08 ROWS '):rows+=json.loads(line.split('ROWS ',1)[1])['rows']
    records=[r for r in rows if r[0]==1 and r[4]==0 and r[6]==2]
    assert len(records)==180 and records[0][7]==1 and records[0][14]==1
    first=records[0]
    # The very first recorded pre-push state has exactly one frame. Its timestamp,
    # arrival and sample clock reconstruct the timing state without private edits.
    seed={'stamp':first[22],'now':first[13],'sampleNow':first[12],
          'x':first[20],'y':first[21],'cursor':first[9],'offset':first[10]}
    compact=[[r[7],r[8],r[11],r[9],r[10],r[15],r[22],r[18],r[1]] for r in records]
    return {'log':str(LOG),'log_sha256':LOG_SHA,'role':'join','round':0,'motion_id':2,
            'seed':seed,'rows':compact,'first_projectile_stamp':84385,
            'first_real_frames_receive_at':45762,'first_display_write_at':46163,
            'scope':'Recorded push/sample order and source-clock scalars; actor coordinates are stationary fixture values, full snapshots were not exported.'}

def derived():
    old,new=sources();t=trace()
    out={'src/rconnect/game/RemoteMotion.as':new,
         'components/rconnect/game/RemoteMotionBefore.as':re.sub(r'\bRemoteMotion\b','RemoteMotionBefore',old),
         'components/rconnect/game/RemoteMotionAfter.as':re.sub(r'\bRemoteMotion\b','RemoteMotionAfter',new),
         'trace.json':json.dumps(t,ensure_ascii=False,indent=2)+'\n'}
    tele=(BASE/'TeleportVisuals.as').read_text(encoding='utf-8')
    weapon=(BASE/'WeaponDisplay.as').read_text(encoding='utf-8')
    out['components/rconnect/game/TeleportVisuals.as']='package rconnect.game { public final class TeleportVisuals {\n'+method(tele,'private static function valid(')+'\n'+method(tele,'public static function split(')+'\n}}\n'
    out['components/rconnect/game/WeaponDisplay.as']='package rconnect.game { public final class WeaponDisplay {\n'+method(weapon,'public static function interpolate(')+'\n}}\n'
    stream=(BASE/'ProjectileFrameStream.as').read_text(encoding='utf-8')
    for suffix in ['Before','After']:
        out['components/rconnect/game/ProjectileFrameStream'+suffix+'.as']=re.sub(r'\bRemoteMotion\b','RemoteMotion'+suffix,
            re.sub(r'\bProjectileFrameStream\b','ProjectileFrameStream'+suffix,stream))
    out['components/ClockTrace.as']='package { public final class ClockTrace {\n'+\
       'public static function data():Object { return '+json.dumps(t,separators=(',',':'))+'; }\n}}\n'
    out['proposal.patch']=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
        fromfile='recovery-09/src/rconnect/game/RemoteMotion.as',tofile='recovery-clock-catchup/src/rconnect/game/RemoteMotion.as'))
    return out

def verify():
    values=derived()
    for name,value in values.items():assert (HERE/name).read_bytes()==value.encode('utf-8'),name
    data=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
    for p,h in data['files'].items():assert sha(HERE/p)==h,p
    for p,h in data['ancestors'].items():assert sha(Path(p))==h,p
    return data

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--verify',action='store_true');args=ap.parse_args()
    if args.verify:verify();print('clock candidate inputs verified; no JVM/AIR');return
    for name,value in derived().items():write(HERE/name,value)
    ancestors={str(p):sha(p) for p in [BASE/'RemoteMotion.as',BASE/'TeleportVisuals.as',BASE/'WeaponDisplay.as',BASE/'ProjectileFrameStream.as',
        BASE.parents[2]/'RConnectMod.swf',LOG]}
    files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*')) if p.is_file() and p.name!='inputs.json' and '__pycache__' not in str(p)}
    write(HERE/'inputs.json',json.dumps({'baseline':'recovery-09','compiled':False,'AIR_started':False,
        'performance_qualified':False,'native_qualified':False,'ancestors':ancestors,'files':files},ensure_ascii=False,indent=2)+'\n')
    verify();print('clock candidate + real-class replay inputs generated; no JVM/AIR')

if __name__=='__main__':main()
