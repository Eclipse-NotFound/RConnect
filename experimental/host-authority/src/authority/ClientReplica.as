package authority {
   import flash.display.MovieClip;
   import flash.display.DisplayObject;
   import flash.utils.getTimer;
   import fe.inter.AuthorityMenus;
   import fe.inter.Stand;
   import fe.inter.AuthorityGUI;
   /** Confirmation-only B1 presentation. No attack(), damage() or object step. */
   public class ClientReplica {
      public var tactics:TacticsBridge;
      public var access:NativeAccess,frames:uint=0,lastTick:uint=0,lastFrame:Object;
      public var displayFrame:Object,clock:PlaybackClock=new PlaybackClock();
      public var scene:ReplicaScene;
      public var peerProfile:Object;
      public var playerApplications:Array=[0,0],projectileApplications:uint=0;
      private var peers:Object={},projectiles:Object={};
      private var endedProjectiles:Object={};
      public var shortProjectileApplications:uint=0;
      private var originalPause:Boolean;
      private var entrySave:Object;
      private var decoder:FrameDelta=new FrameDelta();
      private var satsEpoch:int=-1;
      public var uiMessages:uint=0;
      private var uiSerial:uint=0;
      private var menuSerial:uint=0,menuRevision:uint=0,standSerial:uint=0;
      public var satsRefreshes:uint=0;
      public function ClientReplica(access:NativeAccess) {
         this.access=access;originalPause=access.world.onPause;
         var data:Object={};access.world.saveToObj(data);entrySave=PlainData.nativeCopy(data);
         VisualPose.resolve=access.visualClass;
         access.world.onPause=true;
         scene=new ReplicaScene(access);
      }
      public function apply(frame:Object):void {
         frame=decoder.decode(frame);
         if(frame.tick<lastTick)return;
         lastTick=frame.tick;lastFrame=frame;++frames;
         if(clock.push(frame,getTimer()))present(true);
      }
      public function present(flush:Boolean=false):void {
         var ready:Array=clock.take(getTimer(),flush);
         // Every discrete scene delta is consumed, even if several confirmations
         // arrive during one screen frame. No broken wall or removed unit is lost.
         for each(var confirmed:Object in ready)render(confirmed);
         if(clock.current!=null && clock.fraction>0)render(PoseTween.frame(clock.current,clock.next,clock.fraction));
      }
      private function render(frame:Object):void {
         displayFrame=frame;
         MapState.apply(access,frame.map);
         if(frame.scene!=null && scene.apply(frame.scene)) {
            for each(var old:Object in peers) {
               old.body.loc=access.world.loc;
               if(old.weapon!=null)old.weapon.loc=access.world.loc;
            }
         }
         var present:Boolean=frame.room===access.roomKey();access.world.visual.visible=present;
         CharacterState.apply(access,frame.character);
         if(frame.character!=null)AuthorityGUI.applyModal(access.world.gui,frame.character.modal);
         if(frame.character!=null && frame.character.menu!=null) {
            var menu:Object=frame.character.menu;
            if(menu.revision>menuRevision)AuthorityMenus.refreshStand(access.world.stand as Stand);
            AuthorityMenus.apply(access,menu,menu.serial>menuSerial,menu.revision>menuRevision);
            menuSerial=menu.serial;menuRevision=menu.revision;
         }
         if(frame.character!=null && frame.character.stand!=null && frame.character.stand.serial>standSerial) {
            standSerial=frame.character.stand.serial;
            access.world.stand.onoff(frame.character.stand.active?1:-1);
         }
         if(frame.character!=null)for each(var message:Object in frame.character.messages)if(message.id>uiSerial) {
            if(["infoText","infoEffText","messText"].indexOf(message.key)<0)throw new Error("Unknown native UI feedback");
            access.world.gui[message.key].apply(access.world.gui,message.args);uiSerial=message.id;++uiMessages;
         }
         for each(var state:Object in frame.players) {
            if(state.room===frame.room && present)applyPlayer(state);
            else if(peers[state.id]!=null) {
               peers[state.id].body.remVisual();
               if(peers[state.id].weapon!=null)peers[state.id].weapon.remVisual();
            }
         }
         var active:Object={};
         for each(var p:Object in frame.projectiles)if(p.room===frame.room && present){applyProjectile(p);active[String(p.id)]=true;}
         for each(p in frame.projectileEvents)if(p.ended && p.room===frame.room && present && !active[String(p.id)]) {
            // A fast bullet can be born and hit in one host step. Its final
            // native symbol still gets one source frame, once per lifetime.
            var last:Object=endedProjectiles[p.id];
            if(last==null){endedProjectiles[p.id]={tick:frame.tick};last=endedProjectiles[p.id];++shortProjectileApplications;}
            if(last.tick==frame.tick){applyProjectile(p);active[String(p.id)]=true;}
         }
         for(var endKey:String in endedProjectiles)if(frame.tick-endedProjectiles[endKey].tick>240)delete endedProjectiles[endKey];
         for(var key:String in projectiles)if(!active[key]){
            var clip:DisplayObject=projectiles[key];if(clip.parent!=null)clip.parent.removeChild(clip);delete projectiles[key];
         }
         access.world.gui.setHp();access.world.gui.setMana();access.world.gui.setWeapon();access.world.gui.setPet();
         if(frame.paused && access.world.sats.active && satsEpoch!=frame.pauseEpoch) {
            var sats:Object=access.world.sats,grafon:Object=access.world.grafon;
            // Never photograph the previous SATS screenshot. Temporarily put
            // confirmed actors back in the ordinary scene, then rebuild once.
            sats.offUnits();grafon.onSats(false);
            try {grafon.drawSats();}finally {grafon.onSats(true);}
            sats.getUnits();satsEpoch=frame.pauseEpoch;++satsRefreshes;
         }
         if(!access.world.sats.active)satsEpoch=-1;
      }
      private function applyPlayer(state:Object):void {
         var local:Boolean=state.id==1,rec:Object=peers[state.id];
         if(rec==null) {
            var g:Object;
            if(local)g=access.world.gg;
            else {
               var actor:PlayerActor=access.createPlayer(peerProfile,access.world.loc,state.x,state.y,0);
               g=actor.unit;
               for each(var item:Object in g.childObjs)if(item!=null)item.remVisual();
            }
            rec={body:g,actor:local?null:actor,weaponId:"",weapon:null,weaponEpoch:0};peers[state.id]=rec;
         }
         g=rec.body;if(g.vis.parent==null)g.addVisual();
         NativeFields.apply(g,state.native);
         var pet:Object=scene.petFor(state.id);
         if(g.pet!==pet && g.pet!=null)g.pet.remVisual();
         g.pet=pet;g.childObjs[2]=pet;
         if(pet!=null)g.pets[pet.id]=pet;
         if(local)g.visSel=access.world.gui.vis.selector.visible;
         scene.registerPlayer(g,state.key);
         if(rec.weapon!=null && rec.weapon.vis.parent==null)rec.weapon.addVisual();
         g.setPos(state.x,state.y);g.dx=state.dx;g.dy=state.dy;g.storona=state.direction;
         g.hp=state.hp;g.maxhp=state.maxhp;
         if(local)g.mana=state.mana;
         g.setVisPos();g.vis.scaleX=state.sx;g.vis.scaleY=state.sy;
         VisualPose.apply(g.vis,state.visual);
         ++playerApplications[state.id];
         if(state.weapon!=null) {
            var w:Object=state.weapon;
            if(rec.weaponId!==w.id || rec.weaponEpoch!==state.weaponEpoch) {
               if(rec.weapon!=null)rec.weapon.remVisual();
               if(local && g.currentWeapon!=null)g.currentWeapon.remVisual();
               var Weapon:Class=access.definition("fe.weapon.Weapon");
               rec.weapon=local?g.invent.weapons[w.id]:Weapon["create"](g,w.id,int(w.variant));rec.weapon.loc=access.world.loc;rec.weapon.addVisual();
               if(local)rec.weapon.setPers(g,g.pers);
               rec.weaponId=w.id;
               rec.weaponEpoch=state.weaponEpoch;
               if(local)g.currentWeapon=rec.weapon;
            }
            var v:Object=rec.weapon.vis;
            NativeFields.apply(rec.weapon,w.native);
            rec.weapon.hold=w.hold;
            v.x=w.x;v.y=w.y;v.rotation=w.rotation;v.scaleX=w.sx;v.scaleY=w.sy;
            VisualPose.apply(v as DisplayObject,w.visual);
         } else if(rec.weapon!=null) {
            rec.weapon.remVisual();rec.weapon=null;rec.weaponId="";
            if(local)g.currentWeapon=null;
         }
      }
      private function applyProjectile(state:Object):void {
         if(state.clip=="")return;
         var clip:MovieClip=projectiles[state.id];
         if(clip==null) {
            var ClassRef:Class=access.visualClass(state.clip);
            clip=new ClassRef() as MovieClip;
            if(clip==null)throw new Error("Unsupported projectile display "+state.clip);
            access.world.grafon.visObjs[int(state.layer)].addChild(clip);projectiles[state.id]=clip;
         }
         clip.x=state.x;clip.y=state.y;clip.rotation=state.rotation;
         clip.scaleX=state.sx;clip.scaleY=state.sy;
         if(state.visual!=null)VisualPose.apply(clip,state.visual);
         else if(clip.currentFrame!=state.frame)clip.gotoAndStop(state.frame);else clip.stop();
         ++projectileApplications;
      }
      public function dispose():void {
         for each(var rec:Object in peers) {
            if(rec.weapon!=null)rec.weapon.remVisual();
            if(rec.body!==access.world.gg)rec.body.remVisual();
            if(rec.actor!=null)rec.actor.destroy();
         }
         for each(var clip:DisplayObject in projectiles)if(clip.parent!=null)clip.parent.removeChild(clip);
         scene.dispose();peers={};projectiles={};endedProjectiles={};access.world.onPause=originalPause;
      }
      public function returnToOwnGame():void {
         // Leaving does not turn a confirmation-only replica into a second
         // simulation of the host's world. Rebuild the player's own native
         // journey, carrying only that player's confirmed character/resources.
         var w:Object=access.world;
         entrySave.pers=PlainData.nativeCopy(w.pers.save());entrySave.invent=PlainData.nativeCopy(w.invent.save());
         entrySave.app=PlainData.nativeCopy(w.app.save());entrySave.hardInv=w.hardInv;
         w.loaddata=entrySave;w.loadGame(99);
         Log.write("return-own-game",{control:w.gg.ggControl,hp:w.gg.hp,dead:w.pers.dead,work:w.gg.work,
            room:access.keyFor(w.loc),exit:w.t_exit,die:w.t_die,paused:w.onPause,stat:w.allStat,cat:w.catPause});
      }
   }
}
