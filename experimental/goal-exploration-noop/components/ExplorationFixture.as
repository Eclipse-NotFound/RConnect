package {
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.utils.Dictionary;
   import rconnect.game.ExplorationSync;
   import rconnect.game.ControlExplorationSync;

   /** Two separate fixtures drive the real full classes through public APIs.
    * The optional display API is a recording double, not real RV. */
   public class ExplorationFixture {
      public var mod:RConnectMod=new RConnectMod();
      public var sync:Object,clock:int=10000,settings:Object={enabled:"1"};
      public var carrier:ExplorationCarrier=new ExplorationCarrier();
      public var apiState:Object;
      public var rooms:Array=[];
      public var token:Object;
      public var peer:String="peer-A";
      public function ExplorationFixture(candidate:Boolean) {
         mod.stage=new ExplorationStage();mod.main=new Sprite();carrier.name="RVExplorationAPI";
         mod.main.addChild(carrier);
         var self:ExplorationFixture=this;
         mod.config={getValue:function(key:String):* {return self.settings.enabled;},
            setValue:function(key:String,v:*):void {self.settings.enabled=v;},save:function():void {}};
         mod.game={world:{game:{}},gg:{},loc:null,
            refreshWorld:function():void {},isTransitioning:function():Boolean {return false;},
            readWorldInfo:function():Object {return {curLandId:"test",locId:self.mod.game.loc.id,
               curCoord:"0,0",landStage:self.mod.game.loc.keyStage};}};
         enter(room("A"));replaceAPI("ok");
         var now:Function=function():int{return self.clock;};
         sync=candidate?new ExplorationSync(mod,now):new ControlExplorationSync(mod,now);
         token=sync.packet();
      }
      public function room(id:String):Object {
         var loc:Object={id:id,keyStage:1,spaceX:2,spaceY:2,active:true,retDark:false,space:[],
            grafon:{lightBmp:new BitmapData(5,5,true,0xff000000)}};
         for(var x:int=0;x<2;x++){loc.space[x]=[];for(var y:int=0;y<2;y++)loc.space[x][y]={visi:0,t_visi:0};}
         rooms.push(loc);return loc;
      }
      public function enter(loc:Object):void {mod.game.loc=loc;mod.game.world.loc=loc;}
      public function replaceAPI(mode:String):void {
         var state:Object={mode:mode,calls:0,rooms:new Dictionary(),references:[],inputs:[]};
         apiState=state;
         carrier.api={version:1,active:function(loc:Object):Boolean {return state.mode!="inactive";},
            capture:function(loc:Object):Array {return null;},
            merge:function(loc:Object,rows:Array):Boolean {
               state.calls++;state.references.push(rows);state.inputs.push(rows.concat());
               if(state.mode=="false-once"){state.mode="ok";return false;}
               if(state.mode=="throw-once"){state.mode="ok";throw new Error("expected optional merge failure");}
               state.rooms[loc]=ExplorationSync.unionRows(state.rooms[loc] as Array,rows);
               return true;
            }};
      }
      public function message(rows:Array,to:String=null):Object {
         return {v:1,room:token.room,cols:token.cols,height:token.height,epoch:peer,
            to:to==null?token.epoch:to,rows:rows.concat()};
      }
      public function delta(changes:Array):Object {
         var p:Object=message([]);delete p.rows;p.changes=changes;return p;
      }
      public function render():void {mod.stage.dispatchEvent(new Event(Event.RENDER));}
      public function advance():void {clock+=1100;}
      public function renew():void {advance();token=sync.packet();}
      public function view():Object {
         var loc:Object=mod.game.loc,bmp:BitmapData=loc.grafon.lightBmp;
         var pixels:Array=[];for(var y:int=0;y<5;y++)for(var x:int=0;x<5;x++)pixels.push(bmp.getPixel32(x,y));
         var rows:Array=apiState.rooms[loc] as Array;
         return {displayRows:rows==null?null:rows.concat(),pixels:pixels,received:sync.received,
            nativeVisi:loc.space[1][1].visi,nativeTarget:loc.space[1][1].t_visi};
      }
      public function packetView():Object {
         advance();var p:Object=sync.packet();
         if(p==null)return null;
         return {v:p.v,room:p.room,cols:p.cols,height:p.height,epochPresent:p.epoch.length>0,
            toPeer:p.to==peer,rows:p.rows,changes:p.changes};
      }
      public function close():void {for each(var loc:Object in rooms)loc.grafon.lightBmp.dispose();}
   }
}
