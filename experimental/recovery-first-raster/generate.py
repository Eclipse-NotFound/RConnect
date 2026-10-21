"""Exact recovery11/E159 sparse proposal. Source generation only; no compiler/AIR."""
from pathlib import Path
import difflib, hashlib, json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-11/src'
HOST = ROOT / 'build/m52/recovery-native-travel-host-01/after/scripts'
PINS={
 'rconnect/core/RoomSync.as':'efafed73dda4df38aab2176f791f6b91cf2a6d68ed9ab420e657662e54639961',
 'rconnect/core/MapGeneration.as':'0826f92fa6fd05859e730131da939e7ec74016a2280e69122833a76c45a0b645',
 'rconnect/game/GameBridge.as':'e1cd085795e134ca293a5eb83fe44e22a0bc7edfb172f960a2c6a1e8bdec9260',
 'rconnect/game/WallImpactVisuals.as':'502b77cc7973107614ba0d91373c7774e898fa42413aee2eb1728299e35bd601',
 'fe/graph/Grafon.as':'09ff2387e744acb9716ae6760de2f8a1c49963da76ae97d072d1bcb759ab6ef3'}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def put(name, value):
    p = HERE / name
    assert p.resolve().is_relative_to(HERE)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(value, encoding='utf-8', newline='\n')
def change(text, old, new):
    assert text.count(old) == 1, old[:180]
    return text.replace(old, new, 1)

def repair_closure_increments(s):
    # FFDec emitted unsupported scope lookup pseudo-instructions for these two
    # captured variable increments. Restore only the exact original j++ / i++
    # source, also present in the independently compiled CS Grafon source.
    s=change(s,'''                  var _loc1_:* = §§findproperty(j);
                  var _loc2_:Number = Number(_loc1_.j) + 1;
                  _loc1_.j = _loc2_;''','                  j++;')
    return change(s,'''               _loc1_ = §§findproperty(i);
               _loc2_ = Number(_loc1_.i) + 1;
               _loc1_.i = _loc2_;''','               i++;')

def main():
    for rel,digest in PINS.items():assert sha((HOST if rel.startswith('fe/') else BASE)/rel)==digest,rel
    inputs, outputs, patch = {}, {}, []
    def emit(base, rel, text, dest='src'):
        source=base/rel; original=source.read_text(encoding='utf-8-sig')
        inputs[str(source.relative_to(ROOT))]=sha(source)
        put(dest+'/'+rel,text);outputs[dest+'/'+rel]=sha(HERE/dest/rel)
        patch.extend(difflib.unified_diff(original.splitlines(True),text.splitlines(True),
            fromfile=str(source.relative_to(ROOT)),tofile='experimental/recovery-first-raster/'+dest+'/'+rel))

    rel='rconnect/core/RoomSync.as'; s=(BASE/rel).read_text(encoding='utf-8-sig')
    s=change(s,'      private var nativeTravel:NativeTravelPlan;',
        '      private var nativeTravel:NativeTravelPlan;\n      private var firstRaster:FirstRasterGate=new FirstRasterGate();\n      private var nativeFrame:int=0;')
    s=change(s,'      public function reset():void\n      {',
        '      public function reset():void\n      {\n         firstRaster.cancel();')
    s=change(s,'         if(e!=null)game.refreshWorld();', '''         if(e!=null) {
            game.refreshWorld();
            if(firstRaster.awaitingView)try {finishFirstRaster();}catch(error:Error){fail(error);}
         }''')
    s=change(s,'         if(connected())mod.stage.invalidate();','         ++nativeFrame;\n         if(connected())mod.stage.invalidate();')
    s=change(s,'      private function clearNativeEntry():void {', '''      /** Called only by the patched large-scene sceneOpen, after native
       * World.loc assignment. No pause here: exitStep still must reach zero. */
      public function openFirstRaster(w:Object,l:Object,g:Object):Object {
         if(!nativeTravel.matchesWorld(w)) {firstRaster.cancel();return null;}
         if(session.mode!=Session.CONNECTED || blocked || w!==game.world || w==null
            || w.game==null || w.land==null || l==null || g==null
            || nativeTravel.current==null || !nativeTravel.started || !nativeTravel.consumed
            || nativeTravel.current.info.sceneMerged!==true || nativePreviousBarrier>0
            || w.land===nativeStartLand || l!==w.loc || l.land!==w.land
            || String(w.land.act.id)!=String(nativeTravel.current.info.curLandId)
            || String(w.game.curLandId)!=String(nativeTravel.current.info.curLandId)
            || game.isPlayerDead())return null;
         // Existing viewReady means the whole map when culling is disabled.
         // Nonpreload/culling-off cannot finish that condition with one view;
         // retain the ordinary renderer rather than invent a second readiness rule.
         if(g.scenePreload!==true && g.sceneCullRender!==true) {firstRaster.cancel();return null;}
         if(firstRaster.active && !firstRaster.matches(w,l,g,nativeTravel.id)) {
            firstRaster.cancel();return null; // changed native room: ordinary draw
         }
         return firstRaster.open(w,l,g,nativeTravel.id);
      }
      private function finishFirstRaster():void {
         if(!connected() || host() || game.isPlayerDead() || !nativeTravel.matchesWorld(game.world)
            || !firstRaster.matches(game.world,game.loc,game.world==null?null:game.world.grafon,nativeTravel.id)) {
            cancelNativeEntry(true);return;
         }
         if(!firstRaster.ready(game.world,game.loc,game.world.grafon,nativeTravel.id,nativeFrame))return;
         // The natural Camera.calc/sceneTick has now painted the anchored
         // viewport. Restore logical wall marks before exposing that frame.
         game.finishFirstRaster();
         var receipt:Object=firstRaster.complete();
         if(pending!=int(receipt.barrier) || epoch!=int(receipt.epoch))throw new Error("First raster barrier changed");
         send({op:"ack",barrier:pending,travelId:String(receipt.travelId)});
         nativeTravel.finish(String(receipt.travelId));clearNativeEntry();nativeDeadline=0;game.activeTravelId="";
         pending=0;readySent=false;release();
         Log.d("RConnectRoom: first raster ready "+settledKey+" term="+term+" ms="+(getTimer()-barrierStarted));
      }
      private function clearNativeEntry():void {''')
    s=change(s,'      private function cancelNativeEntry(discardBarrier:Boolean=false):void {',
        '      private function cancelNativeEntry(discardBarrier:Boolean=false):void {\n         firstRaster.cancel();')
    s=change(s,'               var completingNative:Boolean=nativeTravel.current!=null && String(msg.travelId)==nativeTravel.id;', '''               if(firstRaster.awaitingView) {
                  if(!firstRaster.sameGrant(int(msg.barrier),int(msg.epoch),String(msg.travelId)))
                     throw new Error("Grant overtook pending first raster");
                  return true; // exact duplicate: never restore/reward twice
               }
               var completingNative:Boolean=nativeTravel.current!=null && String(msg.travelId)==nativeTravel.id;
               var delayedRaster:Boolean=completingNative && firstRaster.active;
               if(delayedRaster)firstRaster.beginRestore(game.world,game.loc,game.world.grafon,nativeTravel.id);''')
    s=change(s,'               send({op:"ack",barrier:pending,travelId:completingNative?nativeTravel.id:""});', '''               if(delayedRaster) {
                  firstRaster.restored(game.world,game.loc,game.world.grafon,nativeTravel.id,pending,epoch,nativeFrame);
                  // No new state machine for ordinary rooms: only this exact
                  // native large destination waits for its next native raster.
                  mod.stage.invalidate();return true;
               }
               send({op:"ack",barrier:pending,travelId:completingNative?nativeTravel.id:""});''')
    s=change(s,'      private function fail(error:Error):void\n      {','      private function fail(error:Error):void\n      {\n         firstRaster.cancel();')
    emit(BASE,rel,s)

    rel='rconnect/core/MapGeneration.as';s=(BASE/rel).read_text(encoding='utf-8-sig')
    s=change(s,'         var cls:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");', '''         var grafon:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
         if("rconnectRasterBridge" in grafon) {
            if(grafon.rconnectRasterBridge!=null)throw new Error("Native first raster hook already owned");
            grafon.rconnectRasterBridge=firstRaster;
         }
         var cls:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Land");''')
    s=change(s,'      private function nativeTravel(phase:String,g:Object,info:Object):Object {', '''      private function firstRaster(w:Object,l:Object,g:Object):Object {
         if(session.rooms==null || session.mode!=Session.CONNECTED)return null;
         return session.rooms.openFirstRaster(w,l,g);
      }
      private function nativeTravel(phase:String,g:Object,info:Object):Object {''')
    emit(BASE,rel,s)

    rel='rconnect/game/GameBridge.as';s=(BASE/rel).read_text(encoding='utf-8-sig')
    s=change(s,'         if(!retained && !_terrain.dirty && (s.wallPaint==null || s.wallPaint.length==0)',
        '         if(!retained && probe(probe(loc,"grafon"),"rconnectRasterPending")!==true\n            && !_terrain.dirty && (s.wallPaint==null || s.wallPaint.length==0)')
    s=change(s,'      public function tileRedrawIfDirty():void','''      /** The native camera has produced the first restored viewport. */
      public function finishFirstRaster():void
      {
         if(probe(probe(loc,"grafon"),"rconnectRasterPending")===true)
            throw new Error("First raster still unpainted");
         _wall.redraw(loc);_satsRasterDirty=true;
      }

      public function tileRedrawIfDirty():void''')
    emit(BASE,rel,s)

    rel='rconnect/game/WallImpactVisuals.as';s=(BASE/rel).read_text(encoding='utf-8-sig')
    s=change(s,'         return loc!=null && get(g,"loc")===loc?get(g,"frontBmp") as BitmapData:null;',
        '         return loc!=null && get(g,"loc")===loc && get(g,"rconnectRasterPending")!==true\n            ?get(g,"frontBmp") as BitmapData:null;')
    emit(BASE,rel,s)

    rel='fe/graph/Grafon.as';s=(HOST/rel).read_text(encoding='utf-8-sig')
    s=change(s,'      private function sceneOpen(value:Location) : void\n      {', '''      // Optional local loading optimization. Older/no RConnect returns null;
      // the native initialization and every ordinary render path stay intact.
      public static var rconnectRasterBridge:Function = null;
      private var rconnectRasterTicket:Object;
      public function get rconnectRasterPending() : Boolean
      {
         return this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true;
      }
      private function rconnectRasterWaiting() : Boolean
      {
         return this.rconnectRasterTicket != null && this.rconnectRasterTicket.waiting === true;
      }
      private function rconnectRasterPainted() : void
      {
         if(this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true
            && !this.rconnectRasterWaiting() && this.sceneResident > 0 && this.sceneViewReady())
         {
            this.rconnectRasterTicket.unpainted = false;
         }
      }
      private function sceneOpen(value:Location) : void
      {
         var ticket:Object = null;
         if(rconnectRasterBridge != null)
         {
            try {
               ticket = rconnectRasterBridge(World.w,value,this);
               if(ticket == null || !(ticket.waiting is Boolean) || !(ticket.unpainted is Boolean))ticket = null;
            }
            catch(error:*) { ticket = null;trace("RConnect first raster fallback: " + error); }
         }
         this.rconnectRasterTicket = ticket;''')
    s=change(s,'         this.drawAllObjs();\n      }\n      \n      private function sceneRender',
        '         this.drawAllObjs();\n         this.rconnectRasterPainted();\n      }\n      \n      private function sceneRender')
    s=change(s,'      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void\n      {',
        '      private function sceneEnsure(left:Number, top:Number, width:Number, height:Number, initial:Boolean = false) : void\n      {\n         if(this.rconnectRasterWaiting())return;')
    s=change(s,'      public function sceneTick() : void\n      {','      public function sceneTick() : void\n      {\n         if(this.rconnectRasterWaiting())return;')
    s=change(s,'         this.sceneCullSurfaces();\n      }\n      \n      public function sceneViewport',
        '         this.sceneCullSurfaces();\n         this.rconnectRasterPainted();\n      }\n      \n      public function sceneViewport')
    s=change(s,'      public function sceneViewReady() : Boolean\n      {',
        '      public function sceneViewReady() : Boolean\n      {\n         if(this.rconnectRasterWaiting())return false;')
    # A later small-room draw must not inherit an abandoned large-room ticket.
    s=change(s,'         sceneStarted = int(getTimer());\n         this.scenePrepare(param1);',
        '         if(!this.sceneRasterizing)this.rconnectRasterTicket = null;\n         sceneStarted = int(getTimer());\n         this.scenePrepare(param1);')
    s=repair_closure_increments(s)
    emit(HOST,rel,s,'native')
    put('proposal.patch',''.join(patch))
    new=HERE/'src/rconnect/core/FirstRasterGate.as';outputs[str(new.relative_to(HERE))]=sha(new)
    put('integration.json',json.dumps(dict(base='recovery-11',host='E159',inputs=inputs,overlays=outputs,
        source_only=True,compiled=False,runtime_tested=False,installation_modified=False,
        scope='join confirmed native shared large scene; no ordinary room change'),ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(dict(overlays=len(outputs),source_only=True),ensure_ascii=False))

if __name__=='__main__':main()
