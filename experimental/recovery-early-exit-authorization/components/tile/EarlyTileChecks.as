package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.*;
   import fe.loc.Tile;
   import rconnect.game.NativeTileState;
   /** Real recovery16 serializer/restorer. Rendering changes below are explicit
    * inputs; this does not execute Location.tileKontur or certify other mods. */
   public class EarlyTileChecks extends Sprite {
      private var rows:Array=[];
      public function EarlyTileChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void{rows.push({passed:ok,label:label});}
      private function room():Object{return {spaceX:1,spaceY:1,space:[[new Tile(0,0)]]};}
      private function run():void {
         var source:Object=room(),target:Object=room(),tile:Tile=source.space[0][0],n:String;
         tile.shelf=true;tile.hp=21;tile.front="destroyed";
         var before:Object=NativeTileState.capture(source),derived:Array=["kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4"];
         check(before!=null && before.names.indexOf("shelf")>=0,"early checkpoint keeps authoritative shelf");
         for each(n in derived)check(before.names.indexOf(n)>=0,"transport still retains derived "+n);
         for each(n in derived)tile[n]=7;
         var after:Object=NativeTileState.capture(source);
         check(JSON.stringify(before)!=JSON.stringify(after),"eight renderer-derived changes are not falsely declared byte-identical");
         NativeTileState.restore(target,JSON.parse(JSON.stringify(before)),function(t:Object,x:int,y:int):void{});
         check(target.space[0][0].shelf===true && target.space[0][0].hp==21 && target.space[0][0].front=="destroyed","prepaint restore retains platform health and destruction state");
         check(target.space[0][0].kont1==0 && target.space[0][0].pont4==0,"prepaint values survive transport without inventing postpaint contours");
         NativeTileState.restore(target,JSON.parse(JSON.stringify(after)),function(t:Object,x:int,y:int):void{});
         check(target.space[0][0].shelf===true && target.space[0][0].kont1==7 && target.space[0][0].pont4==7,"postpaint contour values also round-trip, shelf is never excluded");
         tile.shelf=false;var changed:Object=NativeTileState.capture(source);
         check(JSON.stringify(changed)!=JSON.stringify(after),"shelf false-to-true difference cannot be hidden as a render-only field");
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var r:Object in rows)if(!r.passed)failed++;
         var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         f.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));f.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
