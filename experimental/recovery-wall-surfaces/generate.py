"""Exact recovery14 / FD92-import sparse overlay. Source only; no compiler/AIR."""
from pathlib import Path
import difflib, hashlib, json
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-14'
HOST=ROOT/'build/m52/recovery-first-raster-host-03/import/fe/graph/Grafon.as'
WALL='rconnect/game/WallImpactVisuals.as'
GAME='rconnect/game/GameBridge.as'
PINS={
 BASE/'RConnectMod.swf':'225a794040c71f2a55ff433366a7969201ac3a58ffaab0a655cee1e4eefbe5f7',
 BASE/'src'/WALL:'0c0917eac6c417814612183f4951d2d0a37cad5ab2743945b6313d941532d3f5',
 BASE/'src'/GAME:'26bb0f7cd4da7c74c83bd2657575823247196c41a861babf23bb40c17fc3cbf7',
 HOST:'976526e741392904bb2575c7e6c73055cdb589ae177e033ad9fdebcc6faa850d',
}

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def put(name,s):
 p=(HERE/name).resolve();assert p.is_relative_to(HERE)
 p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8',newline='\n')
def one(s,a,b):
 assert s.count(a)==1,(s.count(a),a[:120]);return s.replace(a,b,1)

def wall_overlay(s):
 s=one(s,'      private var active:Object,shadow:BitmapData,bitmap:BitmapData;',
       '      private var active:Object,shadow:BitmapData,bitmap:BitmapData;\n      private var surfaces:WallSurfaceBridge;\n      private var surfaceOrder:Number=0;')
 s=one(s,'      {if(main!=null)domain=main.loaderInfo.applicationDomain;}',
       '''      {
         if(main!=null)domain=main.loaderInfo.applicationDomain;
         surfaces=new WallSurfaceBridge(surfaceChanges,surfaceRaster,surfaceBorn,main);
      }
      public function set networkActive(value:Boolean):void {surfaces.networkActive=value;}
      private function surfaceBorn():Number {return ++surfaceOrder;}
      private function surfaceChanges(loc:Object,list:Object,order:Number):void
      {
         var s:Object=state(loc);
         for(var k:String in list) {
            var incoming:Object=list[k];
            if(!solid(loc,int(incoming.x),int(incoming.y))){discard(loc,k);continue;}
            var cell:Object=s.cells[k],q:Object=s.queued[k],wrote:Boolean=false;
            if(cell==null)cell=s.cells[k]={x:incoming.x,y:incoming.y,values:{},v:0,wire:null};
            if(cell.paintOrder==null)cell.paintOrder={};
            for(var index:String in incoming.values) {
               // A mark can first rasterize long after its native birth. Its
               // old pixels must not supersede a newer accepted local/peer ink.
               // This local-only order never changes wire versions or ACKs.
               if(Number(cell.paintOrder[index])>order)continue;
               cell.paintOrder[index]=order;
               var color:uint=uint(incoming.values[index]);
               if(cell.values[index]===color)continue;
               if(q==null)q=s.queued[k]={x:incoming.x,y:incoming.y,values:{}};
               cell.values[index]=color;q.values[index]=color;wrote=true;
            }
            if(wrote){cell.v=++revision;cell.wire=null;}
         }
      }
      private function surfaceRaster(loc:Object,b:BitmapData,x:int,y:int,clips:Array):void
      {
         if(surfaces.replay(loc,b,x,y,state(loc).cells,clips))dirty=true;
      }''')
 s=one(s,'return loc!=null && get(g,"loc")===loc && get(g,"rconnectRasterPending")!==true',
       'return loc!=null && get(g,"loc")===loc && get(g,"sceneLarge")!==true && get(g,"rconnectRasterPending")!==true')
 s=one(s,'      public function before(loc:Object):void\n      {\n         var b:BitmapData=front(loc);',
       '''      public function before(loc:Object):void
      {
         // Large scenes have no persistent full-surface shadow. Their actual
         // paint passes report bounded changed regions through the host bridge.
         if(get(get(loc,"grafon"),"sceneLarge")===true) {
            if(shadow!=null){shadow.dispose();shadow=null;}
            active=loc;bitmap=null;return;
         }
         var b:BitmapData=front(loc);''')
 s=one(s,'                  x*CELL>=1920 || y*CELL>=1000 || seen[k])return null;',
       '                  seen[k])return null;')
 s=one(s,'         var s:Object=state(loc),b:BitmapData=front(loc),skip:Object=protect?protectedPixels(s):{};',
       '''         var s:Object=state(loc),b:BitmapData=front(loc),skip:Object=protect?protectedPixels(s):{};
         var large:Boolean=get(get(loc,"grafon"),"sceneLarge")===true,painted:Array=large?[]:null;''')
 s=one(s,'               var wrote:Boolean=false;\n               for(var i:int=0;i<c.words.length;i+=2)',
       '               var wrote:Boolean=false,visible:Array=large?[]:null;\n               for(var i:int=0;i<c.words.length;i+=2)')
 s=one(s,'               var wrote:Boolean=false,visible:Array=large?[]:null;',
       '               var wrote:Boolean=false;var visible:Array=large?[]:null;')
 s=one(s,'                  if(cell.values[key]!==color) {cell.values[key]=color;wrote=true;}',
       '''                  if(visible!=null)visible.push(index,color);
                  // Accepted equal-color writes still establish a newer local
                  // order; stale versions and protected pixels already skipped.
                  if(large) {
                     if(cell.paintOrder==null)cell.paintOrder={};
                     cell.paintOrder[key]=++surfaceOrder;
                  }
                  if(cell.values[key]!==color) {
                     cell.values[key]=color;wrote=true;
                  }''')
 s=one(s,'               if(wrote) {cell.v=++revision;cell.wire=null;}',
       '               if(visible!=null && visible.length)painted.push({x:c.x,y:c.y,words:visible});\n               if(wrote) {cell.v=++revision;cell.wire=null;}')
 s=one(s,'         finally {if(b!=null)b.unlock();}\n      }',
       '         finally {if(b!=null)b.unlock();}\n         if(painted!=null && painted.length && surfaces.paint(loc,painted))dirty=true;\n      }')
 s=one(s,'      public function redraw(loc:Object):void\n      {\n         var b:BitmapData=front(loc);if(b==null)return;',
       '''      public function redraw(loc:Object):void
      {
         if(get(get(loc,"grafon"),"sceneLarge")===true) {
            var resident:Array=surfaces.surfaces(loc);
            if(resident!=null)for each(var entry:Object in resident) {
               if(surfaces.replay(loc,entry.nativeBuffers[0],int(entry.x),int(entry.y),state(loc).cells,null))
                  {entry.revision=int(entry.revision)+1;dirty=true;}
            }
            return;
         }
         var b:BitmapData=front(loc);if(b==null)return;''')
 s=one(s,'      public function reset():void\n      {',
       '      public function reset():void\n      {\n         surfaces.reset();surfaceOrder=0;')
 s=one(s,'         rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},sent:{},cursor:0};',
       '         surfaces.restored(loc);\n         rooms[loc]={cells:{},queued:{},pending:null,receipts:{},incoming:{},sent:{},cursor:0};')
 return s

NATIVE_HELPERS='''      // RConnect wall bridge: null means no allocation or callback work.
      public static var rconnectWallBridge:Function = null;
      private var rconnectWallClips:Array = null;
      private var rconnectWallErrors:int = 0;
      private function rconnectWallNotify(kind:String,mark:Object = null,affected:Rectangle = null,token:Object = null) : Object
      {
         if(rconnectWallBridge == null)return null;
         try {return rconnectWallBridge(kind,this,this.loc,this.frontBmp,this.sceneX,this.sceneY,affected,mark,token,this.rconnectWallClips);}
         catch(error:*) {if(this.rconnectWallErrors++ < 4)trace("RConnect wall bridge: " + error);}
         return null;
      }
      /** Clips selected from the original-style pass in a mixed-style chunk. */
      private function rconnectWallBaseClips(bounds:Rectangle,groups:Array) : Array
      {
         var result:Array = [bounds];
         for each(var group:Object in groups)for each(var cut:Rectangle in group.clips)
         {
            var next:Array = [];
            for each(var rect:Rectangle in result)
            {
               var hit:Rectangle = rect.intersection(cut);
               if(hit.isEmpty()){next.push(rect);continue;}
               if(hit.top > rect.top)next.push(new Rectangle(rect.x,rect.y,rect.width,hit.top-rect.top));
               if(hit.bottom < rect.bottom)next.push(new Rectangle(rect.x,hit.bottom,rect.width,rect.bottom-hit.bottom));
               if(hit.left > rect.left)next.push(new Rectangle(rect.x,hit.y,hit.left-rect.left,hit.height));
               if(hit.right < rect.right)next.push(new Rectangle(hit.right,hit.y,rect.right-hit.right,hit.height));
            }
            result = next;
         }
         return result;
      }

'''

def host_overlay(s):
 s=one(s,'      public static var rconnectRasterBridge:Function = null;',NATIVE_HELPERS+'      public static var rconnectRasterBridge:Function = null;')
 s=one(s,'"sceneMaskCursor","m"];','"sceneMaskCursor","m","rconnectWallClips"];')
 s=one(s,'      private function sceneApply(kind:String, args:Array) : void\n      {\n         var stamp:Array;',
       '      private function sceneApply(kind:String, args:Array) : void\n      {\n         var wallMark:Array = null;\n         var wallToken:Object = null;\n         var stamp:Array;')
 s=one(s,'            this.sceneMarks.push([kind,args,stamp,affected]);',
       '''            wallMark = [kind,args,stamp,affected];
            this.sceneMarks.push(wallMark);
            if(rconnectWallBridge != null)this.rconnectWallNotify("mark",wallMark,affected);''')
 s=one(s,'''                  if(kind == "decal")
                  {
                     this.sceneApplyCompactDecal(args,affected);
                  }
                  else
                  {
                     this.sceneApplyRegionAction(kind,args,affected);
                  }
                  ++entry.revision;''',
       '''                  wallToken = rconnectWallBridge != null && wallMark != null ? this.rconnectWallNotify("before",wallMark,affected) : null;
                  try
                  {
                     if(kind == "decal")
                     {
                        this.sceneApplyCompactDecal(args,affected);
                     }
                     else
                     {
                        this.sceneApplyRegionAction(kind,args,affected);
                     }
                  }
                  finally {if(wallToken != null)this.rconnectWallNotify("after",wallMark,affected,wallToken);}
                  ++entry.revision;''')
 s=one(s,'      private function sceneRestoreMarks() : void\n      {\n         var item:Array;',
       '      private function sceneRestoreMarks() : void\n      {\n         var wallToken:Object;\n         var item:Array;')
 s=one(s,'               this.sceneApplyRegionAction(String(item[0]),item[1],item.length > 3 ? item[3] as Rectangle : null);',
       '''               wallToken = rconnectWallBridge != null ? this.rconnectWallNotify("before",item,item.length > 3 ? item[3] as Rectangle : null) : null;
               try {this.sceneApplyRegionAction(String(item[0]),item[1],item.length > 3 ? item[3] as Rectangle : null);}
               finally {if(wallToken != null)this.rconnectWallNotify("after",item,item.length > 3 ? item[3] as Rectangle : null,wallToken);}''')
 s=one(s,'''         finally
         {
            this.sceneStamp = null;
         }
      }
      
      private function sceneSats()''',
       '''         finally
         {
            this.sceneStamp = null;
         }
         if(rconnectWallBridge != null)this.rconnectWallNotify("raster");
      }
      
      private function sceneSats()''')
 s=one(s,'private function sceneRegionDrawPass(style:Object) : void\n      {\n         var prior:Boolean;',
       'private function sceneRegionDrawPass(style:Object,wallClips:Array = null) : void\n      {\n         var savedWallClips:Array = this.rconnectWallClips;\n         var prior:Boolean;')
 s=one(s,'         prior = this.sceneRegionPassActive;\n         this.sceneRegionPassActive = true;',
       '         prior = this.sceneRegionPassActive;\n         this.sceneRegionPassActive = true;\n         this.rconnectWallClips = wallClips;')
 s=one(s,'            this.sceneRegionPassActive = prior;\n            this.sceneRasterRegion = null;',
       '            this.sceneRegionPassActive = prior;\n            this.sceneRasterRegion = null;\n            this.rconnectWallClips = savedWallClips;')
 s=one(s,'            this.sceneRegionDrawPass(firstGroup ? groups[0].style : original);',
       '            this.sceneRegionDrawPass(firstGroup ? groups[0].style : original,rconnectWallBridge != null ? (firstGroup ? groups[0].clips : this.rconnectWallBaseClips(viewport,groups)) : null);')
 s=one(s,'               this.sceneRegionDrawPass(group.style);',
       '               this.sceneRegionDrawPass(group.style,rconnectWallBridge != null ? group.clips : null);')
 # Both region preload and initial viewport copy only clip from a wider draw.
 assert s.count('this.sceneRegionDrawPass(style);')==2
 s=s.replace('this.sceneRegionDrawPass(style);','this.sceneRegionDrawPass(style,rconnectWallBridge != null ? [clip] : null);')
 s=one(s,'               group = job.groups[job.group];',
       '               group = job.groups[job.group];\n               this.rconnectWallClips = rconnectWallBridge != null ? group.clips : null;')
 return s

def main():
 assert all(sha(p)==h for p,h in PINS.items()),'Pinned source or binary changed'
 before=(BASE/'src'/WALL).read_text(encoding='utf-8-sig');after=wall_overlay(before)
 native=HOST.read_text(encoding='utf-8-sig');newnative=host_overlay(native)
 game=(BASE/'src'/GAME).read_text(encoding='utf-8-sig')
 newgame=one(game,'public function set presentationNetworkActive(value:Boolean):void {_presentation.retainUnsent=value;}',
                  'public function set presentationNetworkActive(value:Boolean):void {_presentation.retainUnsent=value;_wall.networkActive=value;}')
 put('src/'+WALL,after);put('native/fe/graph/Grafon.as',newnative);put('src/'+GAME,newgame)
 patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='recovery14/'+WALL,tofile='wall-surfaces/'+WALL))
 patch+=''.join(difflib.unified_diff(native.splitlines(True),newnative.splitlines(True),fromfile='FD92/fe/graph/Grafon.as',tofile='wall-surfaces/fe/graph/Grafon.as'))
 patch+=''.join(difflib.unified_diff(game.splitlines(True),newgame.splitlines(True),fromfile='recovery14/'+GAME,tofile='wall-surfaces/'+GAME))
 put('proposal.patch',patch)
 put('inputs.json',json.dumps({'base':str(BASE),'host_source':str(HOST),'originals':{str(p):sha(p) for p in [BASE/'RConnectMod.swf',BASE/'src'/WALL,BASE/'src'/GAME,HOST]},'overlays':{str(p.relative_to(HERE)):sha(p) for folder in ['src','native'] for p in (HERE/folder).rglob('*.as')},'recipe_sha256':sha(__file__),'compiled':False,'air_started':False},indent=2)+'\n')
 print('Prepared isolated wall surfaces overlay only; no JVM/AIR')
if __name__=='__main__':main()
