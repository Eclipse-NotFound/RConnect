package rconnect.core
{
   import flash.display.DisplayObject;
   import flash.events.MouseEvent;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   import flash.utils.Dictionary;
   import fe.inter.RConnectTravelAccess;
   import rconnect.game.GameBridge;

   /** Entry-side restrictions, before the native handler can spend a scroll,
    * refill a floor or synchronously run a challenge script. */
   public class TravelGuard
   {
      private static var changed:Array=[];
      private static var permitUntil:int=0;
      private static var travelState:Object;
      private static var storyOriginal:Dictionary=new Dictionary();
      private var mod:RConnectMod;
      public function TravelGuard(m:RConnectMod)
      {mod=m;m.stage.addEventListener(MouseEvent.CLICK,click,true,100000);}
      private function click(e:MouseEvent):void
      {
         if(mod.session.mode!=Session.CONNECTED && !mod.session.rooms.busy)return;
         var page:Object=GameBridge.probe(GameBridge.probe(mod.game.world,"pip"),"currentPage");
         if(RConnectTravelAccess.blocked(page,e.target as DisplayObject))
         {e.stopImmediatePropagation();mod.session.rooms.notice("请由宿主发起全队换图");}
      }
      public static function clear():void
      {
         for each(var s:Object in changed)try {s.o.action=s.action;s.o.active=s.active;s.o.is_act=s.is_act;s.o.actionText=s.text;}catch(e:*){}
         changed=[];
      }
      public static function allowTravel():void {permitUntil=getTimer()+15000;}
      public static function endTravel():void {permitUntil=0;}
      public static function reset():void
      {
         clear();permitUntil=0;travelState=null;
         for(var o:Object in storyOriginal)for(var k:String in storyOriginal[o])o[k]=storyOriginal[o][k];
         storyOriginal=new Dictionary();
      }
      private static function suppress(o:Object,k:String,value:*):void
      {
         if(o==null)return;
         var old:Object=storyOriginal[o];if(old==null)old=storyOriginal[o]={};
         if(!old.hasOwnProperty(k))old[k]=o[k];o[k]=value;
      }
      /** A grouped challenge runs its scripts and waves on the host only. */
      public static function mirrorStory(room:Object):void
      {
         if(room==null)return;
         var prob:Object=GameBridge.probe(room,"prob");
         if(prob!=null)
         {
            for each(var k:String in ["inScript","outScript","closeScript","alarmScript"])suppress(prob,k,null);
            suppress(prob,"onWave",false);
         }
         for each(var area:Object in room.areas)if(scripted(area))suppress(area,"enabled",false);
         for each(var script:Object in room.land.scripts)
            if(GameBridge.probe(GameBridge.probe(script,"owner"),"loc")===room)suppress(script,"running",false);
      }
      public static function guardTravel(game:GameBridge,rooms:RoomSync):void
      {
         if(game.world==null || game.gg==null || game.isPlayerDead())return;
         var w:Object=game.world,g:Object=w.game;
         if(int(w.t_exit)>0)
         {
            if(getTimer()<permitUntil || travelState==null)return;
            for(var k:String in travelState)g[k]=travelState[k];
            w.t_exit=0;w.pip.noAct=false;game.gg.controlOn();w.cam.dblack=0;w.vblack.alpha=0;
            rooms.notice("请由宿主发起全队换图");
         }
         else
         {
            travelState={};
            for each(k in ["curLandId","curCoord","missionId","crea"])travelState[k]=g[k];
         }
      }
      public static function update(game:GameBridge,joining:Boolean):void
      {
         clear();if(!joining || game.loc==null)return;
         mirrorStory(game.loc);
         var arrays:Array=[game.loc.objs,game.loc.units,game.loc.acts];
         for each(var list:Array in arrays)if(list!=null)for each(var o:Object in list)
         {
            var inter:Object=GameBridge.probe(o,"inter");
            if(inter==null && GameBridge.probe(o,"action")!=null)inter=o;
            if(inter==null)continue;
            var owner:Object=GameBridge.probe(inter,"owner");
            if(GameBridge.probe(inter,"prob")!=null || ["probreturn","exit"].indexOf(String(GameBridge.probe(inter,"allact")))>=0
               || (owner!=null && getQualifiedClassName(owner).indexOf("CheckPoint")>=0) || scripted(inter))
            {
               changed.push({o:inter,action:inter.action,active:inter.active,is_act:inter.is_act,text:inter.actionText});
               inter.action=0;inter.active=false;inter.is_act=false;
               inter.actionText="请由宿主带队进入";
            }
         }
      }
      private static function scripted(o:Object):Boolean
      {
         for each(var k:String in ["scrDie","scrAlarm","scrAct","scrOpen","scrClose","scrTouch","scrOver","scrOut"])
            if(GameBridge.probe(o,k)!=null)return true;
         var q:*=GameBridge.probe(o,"questId");return q!=null && String(q)!="";
      }
      public static function restricted(loc:Object):Boolean
      {
         if(loc==null)return false;
         if(GameBridge.probe(loc,"prob")!=null || String(GameBridge.probe(loc,"landProb"))!="")return true;
         var xml:XML=GameBridge.probe(GameBridge.probe(loc,"room"),"xml") as XML;
         if(xml!=null && xml.scr.length()>0)return true;
         for each(var list:Array in [loc.units,loc.objs,loc.areas])if(list!=null)for each(var o:Object in list)
            if(scripted(o) || scripted(GameBridge.probe(o,"inter")))return true;
         return false;
      }
      public static function returnTo(game:GameBridge,room:Object):void
      {follow(game,{landX:room.landX,landY:room.landY,landZ:room.landZ,landProb:room.landProb});}
      public static function follow(game:GameBridge,info:Object,mirror:Boolean=false):void
      {
         var land:Object=game.world.land,prob:String=String(info.landProb || "");
         if(prob!="" || String(land.prob)!="")
         {
            // Random maps only prebuild the challenges selected locally. The
            // host may have selected a different one from the same native pool.
            if(prob!="" && land.probs[prob]==null)
            {
               land.buildProb(prob);
               if(land.probs[prob]==null)throw new Error("Missing native challenge: "+prob);
               var made:Object=land.probs[prob][0][0][0];
               made.setObjects();made.preStep();if(made.prob!=null)made.prob.prepare();
            }
            if(mirror)
            {
               mirrorStory(game.loc);
               if(prob!="" && land.probs[prob]!=null)mirrorStory(land.probs[prob][0][0][0]);
            }
            land.gotoProb(prob);
            if(String(land.prob)!=prob)throw new Error("Challenge entry failed: "+prob);
         }
         else
         {
            var target:Object;
            try {target=land.locs[int(info.landX)][int(info.landY)][int(info.landZ)];}catch(e:*){}
            if(target==null)throw new Error("Missing destination room");
            if(mirror)mirrorStory(target);
            land.locX=int(info.landX);land.locY=int(info.landY);land.locZ=int(info.landZ);
            land.ativateLoc();land.setGGToSpawnPoint();
         }
         game.refreshWorld();
         if(info.x!=null && info.y!=null){game.gg.setPos(Number(info.x),Number(info.y));game.gg.setVisPos();}
      }
   }
}
