package {
   public class AcidRoomFixture {
      public var active:Boolean=true;
      public var spaceX:int=12,spaceY:int=12;
      public var reads:int=0,dangerCalls:int=0;
      private var tiles:Object={};
      public function setTile(x:int,y:int,phis:int=1,shelf:Boolean=false,zForm:int=0,phY1:Number=NaN):void {
         tiles[x+":"+y]={phis:phis,shelf:shelf,zForm:zForm,phY1:isNaN(phY1)?y*40:phY1};
      }
      public function getTile(x:int,y:int):Object {
         reads++;
         var t:Object=tiles[x+":"+y];return t==null?{phis:0,shelf:false,zForm:0,phY1:y*40}:t;
      }
      public function budilo(...args):void {dangerCalls++;throw new Error("AI wake must not run");}
      public function hitTile(...args):void {dangerCalls++;throw new Error("Terrain damage must not run");}
      public function damage(...args):void {dangerCalls++;throw new Error("Damage must not run");}
   }
}
