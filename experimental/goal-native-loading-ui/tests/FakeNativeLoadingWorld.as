package {
   public class FakeNativeLoadingWorld {
      public var game:Object={},gg:Object={pers:{dead:false},ggControl:true},loc:Object={};
      public var visual:Object={visible:true},vfon:Object={visible:true},vgui:Object={visible:true};
      public var vblack:Object={visible:true},vscene:Object={visible:false},verror:Object={visible:false};
      public var vwait:Object={visible:false,x:400,y:300,skill:{visible:true,currentFrame:7},
         progres:{visible:true,text:"Loading"},story:{visible:false}};
      public var swfStage:Object={stageWidth:800,stageHeight:600};
      public var pip:Object={active:false,noAct:false},sats:Object={active:false},stand:Object={active:false},gui:Object={guiPause:false};
      public var catPause:Boolean=false,onConsol:Boolean=false,onPause:Boolean=false;
      public var comLoad:int=-1,ng_wait:int=0,t_die:int=0,t_exit:int=0,clickReq:int=0,allStat:int=1;
      public var nativeShows:int=0,nativeFinishes:int=0;

      // RCONNECT_NATIVE_LOADING_UI_BEGIN
      private var rconnectUiOwner:Object;
      private var rconnectUiGame:Object;
      private var rconnectUiPlayer:Object;
      private var rconnectUiWrites:Array;
      private var rconnectUiGeneration:uint;
      public var rconnectLoadingUiFaults:uint;

      /** Display only. Never changes the native clock, pause or player control.
       * The caller must own a local RoomSync.entryPending request, not busy. */
      public function rconnectLoadingView(owner:Object, pending:Boolean) : Object
      {
         try
         {
            return this.rconnectUiViewOwned(owner,pending);
         }
         catch(error:*)
         {
            ++this.rconnectLoadingUiFaults;
            try { this.rconnectUiRestore(); }
            catch(cleanupError:*) { ++this.rconnectLoadingUiFaults; this.rconnectUiWrites = []; }
         }
         return {supported:true,shown:false,reason:"display-fault",faults:this.rconnectLoadingUiFaults};
      }

      private function rconnectUiViewOwned(owner:Object, pending:Boolean) : Object
      {
         if(owner == null)
         {
            return {supported:true,shown:false,reason:"missing-owner",faults:this.rconnectLoadingUiFaults};
         }
         if(!pending)
         {
            if(this.rconnectUiOwner === owner)
            {
               this.rconnectUiRestore();
               this.rconnectUiOwner = null;
               this.rconnectUiGame = null;
               this.rconnectUiPlayer = null;
            }
            return {supported:true,shown:false,reason:"released",faults:this.rconnectLoadingUiFaults};
         }
         if(this.rconnectLoadingUiFaults > 0)
         {
            return {supported:true,shown:false,reason:"display-fault",faults:this.rconnectLoadingUiFaults};
         }
         if(this.rconnectUiOwner != null && this.rconnectUiOwner !== owner)
         {
            return {supported:true,shown:false,reason:"different-owner",faults:this.rconnectLoadingUiFaults};
         }
         if(this.rconnectUiOwner == null)
         {
            this.rconnectUiOwner = owner;
            this.rconnectUiGame = this.game;
            this.rconnectUiPlayer = this.gg;
         }
         var reason:String = this.rconnectUiBlocked();
         if(reason != "")
         {
            this.rconnectUiRestore();
            return {supported:true,shown:false,reason:reason,faults:this.rconnectLoadingUiFaults};
         }
            // Keep the actual native instance and its selected illustration.
            // No allocation, reparenting, random choice or timeline restart.
            this.rconnectUiWrite(this.visual,"visible",false);
            this.rconnectUiWrite(this.vfon,"visible",false);
            this.rconnectUiWrite(this.vgui,"visible",false);
            this.rconnectUiWrite(this.vwait,"visible",true);
            this.rconnectUiWrite(this.vwait,"x",this.swfStage.stageWidth / 2);
            this.rconnectUiWrite(this.vwait,"y",this.swfStage.stageHeight / 2);
            this.rconnectUiWrite(this.vwait.skill,"visible",true);
            this.rconnectUiWrite(this.vwait.progres,"visible",true);
            this.rconnectUiWrite(this.vwait.progres,"text",Res.guiText("loading"));
            return {supported:true,shown:true,reason:"local-entry",generation:this.rconnectUiGeneration,
               nativeWait:this.vwait,faults:this.rconnectLoadingUiFaults};
      }

      private function rconnectUiBlocked() : String
      {
         if(this.game !== this.rconnectUiGame || this.gg !== this.rconnectUiPlayer)
         {
            return "identity-changed";
         }
         if(this.gg == null || this.loc == null || this.game == null || this.vwait == null || this.gg.pers == null)
         {
            return "no-world";
         }
         if(this.comLoad >= 0 || this.ng_wait > 0 || this.t_die > 0 || this.gg.pers.dead)
         {
            return "native-load-or-death";
         }
         if(this.allStat != 1)
         {
            return "native-state";
         }
         if(this.catPause || this.vscene.visible || this.clickReq != 0 || this.vwait.story.visible)
         {
            return "native-story";
         }
         if(this.onConsol || this.verror.visible || this.pip != null && this.pip.active ||
            this.sats != null && this.sats.active || this.stand != null && this.stand.active ||
            this.gui != null && this.gui.guiPause)
         {
            return "native-overlay";
         }
         if(this.t_exit > 20)
         {
            return "native-fade";
         }
         return "";
      }

      private function rconnectUiWrite(target:Object, key:String, value:*) : void
      {
         if(target[key] === value)
         {
            return;
         }
         if(this.rconnectUiWrites == null)
         {
            this.rconnectUiWrites = [];
         }
         // A native display writer first revokes this ledger. This is not a
         // saved whole-screen snapshot restored over a later native owner.
         for each(var old:Object in this.rconnectUiWrites)
         {
            if(old.target === target && old.key == key)
            {
               if(target[key] !== old.written)
               {
                  throw new Error("Native loading display ownership changed");
               }
               target[key] = value;
               old.written = value;
               return;
            }
         }
         var entry:Object = {target:target,key:key,before:target[key],written:value,generation:this.rconnectUiGeneration};
         target[key] = value;
         this.rconnectUiWrites.push(entry);
      }

      private function rconnectUiRestore(keepNativeWait:Boolean = false) : void
      {
         if(this.rconnectUiWrites == null)
         {
            return;
         }
         for(var i:int = this.rconnectUiWrites.length - 1; i >= 0; --i)
         {
            var entry:Object = this.rconnectUiWrites[i];
            try
            {
               // MainMenu may already have handed the native wait to newGame.
               // Never undo that incoming owner, even for an equal-value write.
               if(keepNativeWait && (entry.target === this.vwait ||
                  entry.target === this.vwait.skill || entry.target === this.vwait.progres))
               {
                  continue;
               }
               if(entry.generation == this.rconnectUiGeneration && entry.target[entry.key] === entry.written)
               {
                  entry.target[entry.key] = entry.before;
               }
            }
            catch(error:*)
            {
               ++this.rconnectLoadingUiFaults;
            }
         }
         this.rconnectUiWrites.length = 0;
      }

      /** Called BEFORE each native writer, including same-value writes. */
      private function rconnectUiNativeDisplay(keepNativeWait:Boolean = false) : void
      {
         try { this.rconnectUiRestore(keepNativeWait); }
         catch(error:*) { ++this.rconnectLoadingUiFaults; this.rconnectUiWrites = []; }
         ++this.rconnectUiGeneration;
      }

      /** Native exitStep has completed its original sound/input/fade changes.
       * Keep only the display on-screen until this exact request is released. */
      private function rconnectUiAfterExitDisplay() : void
      {
         if(this.rconnectUiOwner != null)
         {
            this.rconnectLoadingView(this.rconnectUiOwner,true);
         }
      }
      // RCONNECT_NATIVE_LOADING_UI_END
      // Native fixture operations reproduce only the reviewed display boundary.
      // They do not emulate the game or qualify native story/SATS execution.
      public function nativeShow():void {
         rconnectUiNativeDisplay();nativeShows++;
         vgui.visible=vfon.visible=visual.visible=vscene.visible=false;
         vwait.visible=true;catPause=false;clickReq=0;
      }
      public function nativeExit16():void {
         t_exit=16;rconnectUiNativeDisplay();nativeFinishes++;
         vwait.visible=false;vwait.story.visible=false;clickReq=0;
         vgui.visible=vfon.visible=visual.visible=true;
         gg.ggControl=true;pip.noAct=false;
         rconnectUiAfterExitDisplay();
      }
      public function nativeScene():void {
         rconnectUiNativeDisplay();catPause=true;visual.visible=false;vscene.visible=true;
      }
      public function nativeSceneEnd():void {
         rconnectUiNativeDisplay();catPause=false;visual.visible=true;vscene.visible=false;
      }
      public function nativeRoom():void {
         rconnectUiNativeDisplay();loc={};
      }
      public function nativeResize(width:int,height:int):void {
         rconnectUiNativeDisplay();swfStage.stageWidth=width;swfStage.stageHeight=height;
         vwait.x=width/2;vwait.y=height/2;
      }
      public function nativeNewIdentity():void {
         rconnectUiNativeDisplay();game={};gg={pers:{dead:false},ggControl:false};
      }
      public function nativeMenuNewGame():void {
         vwait.visible=true;vwait.progres.text="加载中";
         rconnectUiNativeDisplay(true);allStat=-1;game={};
      }
   }
}
