package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.filesystem.*;
   import fe.Res;
   import fixture.LoadingArt;
   import rconnect.ui.RoomEntryView;

   /** Actual RoomEntryView; only the native asset and fe.Res are substitutes. */
   public class LoadingTextChecks extends Sprite {
      private var rows:Array=[],world:Object,view:RoomEntryView,original:LoadingArt,loadCalls:int=0;
      public function LoadingTextChecks(){addEventListener(Event.ADDED_TO_STAGE,begin);}
      private function check(ok:Boolean,label:String):void {
         rows.push({passed:ok,label:label});trace((ok?"PASS ":"FAIL ")+label);
      }
      private function shown(sats:Boolean=false):LoadingArt {
         var parent:DisplayObjectContainer=sats?world.vsats:this;
         var cover:DisplayObjectContainer=parent.getChildByName(sats?"rconnect-room-entry-sats":"rconnect-room-entry") as DisplayObjectContainer;
         if(cover==null)throw new Error("Missing cover");
         return cover.getChildByName("rconnect-native-loading") as LoadingArt;
      }
      private function show():void{view.show(world,stage,"");}
      private function run():void {
         world={main:this,catPause:true,clickReq:1,onPause:false,ggControl:true};
         for each(var key:String in ["visual","vscene","vblack","vsats"]){world[key]=new Sprite();addChild(world[key]);}
         world.vsats.visible=false;
         world.setLoadScreen=function(index:int=-1):void {loadCalls++;throw new Error("Native loading must not be invoked");};
         original=new LoadingArt();original.visible=false;original.x=100;original.y=120;addChild(original);world.vwait=original;
         view=new RoomEntryView();Res.value="正在加载…";show();
         check(shown().progres.text==Res.value,"uninitialized marker resolves through fe.Res in world.main's domain");
         check(original.progres.text=="*gui_loading" && !original.visible,"source asset remains unmodified and hidden");
         check(shown().x==original.x && shown().y==original.y,"localization preserves the native loading placement");

         world.vsats.visible=true;show();
         check(shown().progres.text==Res.value && shown(true).progres.text==Res.value,"scene and SATS copies use the same native localized text");
         check(shown(true).story.visible==original.story.visible && shown(true).skill.visible==original.skill.visible,"localization preserves native child visibility");

         original.progres.text="Loading...";var before:int=Res.calls;Res.value="Unrelated language";show();
         check(shown().progres.text=="Loading..." && shown(true).progres.text=="Loading...","already initialized native text is preserved in both copies");
         check(Res.calls==before,"initialized native text needs no resource lookup");
         original.progres.text="Unpacking 42%";show();
         check(shown().progres.text=="Unpacking 42%","custom progress text is not replaced");
         original.progres.text="error";show();
         check(shown().progres.text=="error","native error text is not replaced");
         original.progres.text="";show();check(shown().progres.text=="","intentional blank text remains blank");
         original.progres.text="*gui_loading 42%";show();
         check(shown().progres.text=="*gui_loading 42%","nonexact marker-like text remains native text");

         original.progres.text="*gui_loading";Res.value="Chargement…";show();
         check(shown().progres.text=="Chargement…" && shown(true).progres.text=="Chargement…","resource changes are honored without hardcoded English or stale text");
         Res.unavailable=true;show();
         check(shown().progres.text=="*gui_loading","resource exception preserves source text instead of breaking the overlay");
         Res.unavailable=false;Res.value="";show();
         check(shown().progres.text=="*gui_loading","empty resource result cannot erase the loading label");
         Res.value=null;show();
         check(shown().progres.text=="*gui_loading","null resource result cannot become a literal null label");
         Res.value="*gui_loading";show();
         check(shown().progres.text=="*gui_loading","unresolved native resource retains its marker without an invented translation");
         world.main=null;show();
         check(shown().progres.text=="*gui_loading","temporarily missing native main does not throw");
         world.main=this;

         check(loadCalls==0 && world.catPause===true && world.clickReq===1 && world.onPause===false && world.ggControl===true,
            "no native loading, input, story-wait or world-pause side effects occur");
         check(original.progres.text=="*gui_loading" && original.parent===this,"fallback tests never change native source ownership or text");
         view.clear();
         check(getChildByName("rconnect-room-entry")==null && world.vsats.getChildByName("rconnect-room-entry-sats")==null,"both overlay layers clear normally");
      }
      private function begin(e:Event):void {
         try{run();}catch(error:Error){check(false,error+" "+error.getStackTrace());}
         var failed:int=0;for each(var row:Object in rows)if(!row.passed)failed++;
         var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         fs.writeUTFBytes(JSON.stringify({passed:failed==0,failed:failed,assertions:rows,functional_only:true,native_runtime:false}));fs.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
