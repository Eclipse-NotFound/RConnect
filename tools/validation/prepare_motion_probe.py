"""Make a fast-motion diagnostic from the retained real-network fixture.

This is a diagnostic: its measurements cannot replace the existing density gate.
The source uses bounded, known motion on native actors, not receiver-side movement.
"""
import json
from pathlib import Path
from prepare_motion_transport import ROOT, sha


def main():
    original = ROOT / 'tests/SmoothNetworkTestDoc.as'
    destination = ROOT / 'tests/FastMotionNetworkTestDoc.as'
    source = original.read_text(encoding='utf-8-sig')
    def replace(old, new, count=1):
        nonlocal source
        assert source.count(old) == count, (old, source.count(old))
        source = source.replace(old, new)
    replace('SmoothNetworkTestDoc','FastMotionNetworkTestDoc',2)
    replace('smooth-network','fast-motion-network',4)
    replace('baseX=mod.game.gg.X;baseY=mod.game.gg.Y;',
            'baseX=Math.max(80,Math.min(Number(mod.game.loc.limX)-800,Number(mod.game.gg.X)));baseY=mod.game.gg.Y;')
    replace('elapsed*.03','offset(elapsed)',2)
    replace('      private function drive(e:Event):void {',
            '''      // 500 px/s on the straight segments, reversing within a 400px
      // corridor. No native source or remote actor can travel out of the room.
      private function offset(elapsed:int):Number {
         var phase:Number=(elapsed%1600)*.5;return phase<=400?phase:800-phase;
      }
      private function drive(e:Event):void {''')
    replace('body:remote.vis.osn.body.currentFrame,source:',
            'peerX:remote.X,enemyX:merc.X,localX:mod.game.gg.X,body:remote.vis.osn.body.currentFrame,source:')
    replace('var errors:Array=[],stalls:int=0,repeated:int=0,last:int=-1,distinct:Object={};',
            'var errors:Array=[],stalls:int=0,repeated:int=0,last:int=-1,distinct:Object={},straight:int=0;')
    replace('for each(var row:Object in trace){errors.push(Math.abs(Number(row[field])-.03));if(row[field]<.001)stalls++;',
            '''for each(var row:Object in trace){
                     var start:Number=baseX+(field=="enemy"?150:(host?60:0));
                     var x:Number=Number(row[field=="enemy"?"enemyX":"peerX"]);
                     // Turning points legitimately slow down. Compare velocity
                     // only on the straight interior of the known source path.
                     if(x>start+60 && x<start+340 && row.dt<=100){
                        straight++;errors.push(Math.abs(Math.abs(Number(row[field]))-.5));
                        if(Math.abs(Number(row[field]))<.001)stalls++;
                     }''')
    replace('check(stalls<=trace.length*.08 && p95<.02,field+" continuous movement stalls="+stalls+" p95Error="+p95.toFixed(4));',
            '''Log.d("FAST MOTION METRIC "+JSON.stringify({role:host?"host":"join",field:field,
                     frames:trace.length,straight:straight,stalls:stalls,p95VelocityError:p95,diagnosticOnly:true}));
                  check(straight>=15,field+" sufficient straight-segment motion samples="+straight);''')
    replace('Log.d("SMOOTH TCP TRACE "','Log.d("FAST MOTION TRACE "')
    replace('Log.d("SMOOTH TCP SOURCE "','Log.d("FAST MOTION SOURCE "')
    replace('if(!host){check(faded[0],"zebra faint pixels survive actual final scene");check(faded[1],"alicorn faint pixels survive actual final scene");}',
            'if(!host)Log.d("FAST MOTION CAMOUFLAGE "+JSON.stringify(faded));')
    assert not destination.exists(), destination
    destination.write_text(source,encoding='utf-8')
    record = ROOT / 'build/m52/motion-fast-01/probe-source.json'
    assert not record.exists()
    record.write_text(json.dumps(dict(original=str(original.relative_to(ROOT)),original_sha256=sha(original),
        probe=str(destination.relative_to(ROOT)),probe_sha256=sha(destination),
        recipe_sha256=sha(Path(__file__)),diagnostic_only=True),indent=2),encoding='utf-8')
    print(destination)


if __name__=='__main__':main()
