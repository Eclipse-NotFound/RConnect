package authority {
   import flash.display.MovieClip;
   import flash.display.DisplayObject;
   import flash.utils.getTimer;
   import fe.inter.AuthorityMenus;
   import fe.inter.Stand;
   import fe.inter.AuthorityGUI;
   /** Confirmed world playback with bounded own movement prediction. No local
    * attack(), damage() or object step. */
   public class ClientReplica {
      public var tactics:TacticsBridge;
      public var access:NativeAccess,frames:uint=0,lastTick:uint=0,lastFrame:Object;
      public var displayFrame:Object,clock:PlaybackClock=new PlaybackClock();
      public var scene:ReplicaScene;
      public var prediction:MovementPrediction=new MovementPrediction();
      public var sound:SessionSound;
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
      private var predicted:Boolean=false;
      public var satsRefreshes:uint=0;
      // Optional diagnostic observer; receives the actual applied discrete
      // confirmation before any display interpolation. Unset during play.
      public var confirmed:Function;
      public function projectileDisplay(id:uint):DisplayObject {return projectiles[id] as DisplayObject;}
      public function weaponDisplay(player:int):DisplayObject {var peer:Object=peers[player];return peer==null || peer.weapon==null?null:peer.weapon.vis as DisplayObject;}
      public function ClientReplica(access:NativeAccess,vision:SharedVision=null) {
         this.access=access;originalPause=access.world.onPause;
         var data:Object={};access.world.saveToObj(data);entrySave=PlainData.nativeCopy(data);
         VisualPose.resolve=access.visualClass;
         access.world.onPause=true;
         scene=new ReplicaScene(access,vision);
         sound=new SessionSound(access);
      }
      public function apply(frame:Object):void {
         var began:int=Timing.start();
         frame=decoder.decode(frame);
         Timing.end("client.decode",began);
         if(frame.tick<lastTick)return;
         lastTick=frame.tick;lastFrame=frame;++frames;
         prediction.confirm(frame,getTimer());
         if(clock.push(frame,getTimer()))present(true);
      }
      public function present(flush:Boolean=false):void {
         var began:int=Timing.start();
         var ready:Array=clock.take(getTimer(),flush);
         // Every discrete scene delta is consumed, even if several confirmations
         // arrive during one screen frame. No broken wall or removed unit is lost.
         for each(var state:Object in ready){render(state);if(confirmed!=null)confirmed(state);}
         if(clock.current!=null && clock.fraction>0)render(PoseTween.frame(clock.current,clock.next,clock.fraction),true);
         predict();
         if(displayFrame!=null)scene.light(displayFrame.paused===true);
         scene.pointer();
         Timing.end("client.present",began);
      }
      public function submitted(input:Object):void {prediction.record(input,getTimer());predict();}
      private function predict():void {
         var replaying:Boolean=displayFrame!=null && displayFrame.timeControl!=null && displayFrame.timeControl.phase=="replay";
         var state:Object=replaying?null:prediction.sample(getTimer(),displayFrame,scene.terrainRevision,SharedPause.requested(access.world));
         if(state!=null){applyPlayer(state,true);predicted=true;}
         // A new combat/pause request must remove the previous visual lead even
         // when no new confirmed frame arrived in this screen frame.
         else if(predicted && displayFrame!=null && displayFrame.players[1].room===displayFrame.room){applyPlayer(displayFrame.players[1],true);predicted=false;}
      }
      private function render(frame:Object,interpolated:Boolean=false):void {
         var began:int=Timing.start(),part:int=began;
         if(access.view!=null)access.view.prepare();
         displayFrame=frame;
         if(!interpolated)MapState.apply(access,frame.map);
         if(!interpolated && access.time!=null)access.time.present(frame.timeControl);
         if(interpolated && frame.scene!=null)scene.interpolate(frame.scene);
         if(!interpolated && frame.scene!=null && scene.apply(frame.scene)) {
            for each(var old:Object in peers) {
               old.body.loc=access.world.loc;
               if(old.weapon!=null)old.weapon.loc=access.world.loc;
            }
         }
         Timing.end("client.sceneAndMap",part);part=Timing.start();
         var present:Boolean=frame.room===access.roomKey();access.world.visual.visible=present;
         if(!interpolated) {
         CharacterState.apply(access,frame.character);
         access.world.grafon.warShadow();
         Timing.end("client.character",part);
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
         }
         for each(var state:Object in frame.players) {
            if(state.room===frame.room && present)applyPlayer(state,interpolated);
            else if(peers[state.id]!=null) {
               peers[state.id].body.teleObj=null;
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
            var clip:DisplayObject=projectiles[key];if(clip.parent!=null)clip.parent.removeChild(clip);
            VisualPose.dispose(clip);delete projectiles[key];
         }
         var managed:Array=[];
         for each(var peer:Object in peers){managed.push(peer.body.vis);if(peer.weapon!=null)managed.push(peer.weapon.vis);}
         for each(var projectile:DisplayObject in projectiles)managed.push(projectile);
         scene.prune(managed);
         if(!interpolated){access.world.gui.setHp();access.world.gui.setMana();access.world.gui.setWeapon();access.world.gui.setPet();}
         if(!interpolated && access.weapons!=null && frame.character!=null)access.weapons.present(frame.character.msw);
         if(!interpolated)sound.apply(frame);
         if(frame.paused && access.world.sats.active && satsEpoch!=frame.pauseEpoch) {
            var sats:Object=access.world.sats,grafon:Object=access.world.grafon;
            // Never photograph the previous SATS screenshot. Temporarily put
            // confirmed actors back in the ordinary scene, then rebuild once.
            sats.offUnits();grafon.onSats(false);
            try {grafon.drawSats();}finally {grafon.onSats(true);}
            sats.getUnits();satsEpoch=frame.pauseEpoch;++satsRefreshes;
         }
         if(!access.world.sats.active)satsEpoch=-1;
         Timing.end("client.render",began);
      }
      private function applyPlayer(state:Object,interpolated:Boolean=false):void {
         var local:Boolean=state.id==1,rec:Object=peers[state.id];
         if(rec==null) {
            var g:Object;
            if(local)g=access.world.gg;
            else {
               var actor:PlayerActor=access.createPlayer(peerProfile,access.world.loc,state.x,state.y,0);
               g=actor.unit;
               for each(var item:Object in g.childObjs)if(item!=null)item.remVisual();
            }
            rec={body:g,actor:local?null:actor,weaponId:"",weapon:null,weaponEpoch:0,held:null,action:null};peers[state.id]=rec;
         }
         g=rec.body;if(g.vis.parent==null)g.addVisual();
         if(state.held==null)g.teleObj=null;
         else {
            // Native GUI reads teleObj for the label, held mass and throw arrow.
            // This detached native Obj is a read-only UI reference: no display,
            // collision, chain membership or second telekinesis simulation.
            if(rec.held==null){var Held:Class=access.definition("fe.Obj");rec.held=new Held();}
            NativeFields.apply(rec.held,state.held);rec.held.loc=access.world.loc;g.teleObj=rec.held;
         }
         if(state.action==null)g.actionObj=null;
         else {
            if(rec.action==null) {
               var ActionOwner:Class=access.definition("fe.Obj"),Interaction:Class=access.definition("fe.serv.Interact");
               rec.action=new ActionOwner();rec.action.loc=access.world.loc;
               rec.action.inter=new Interaction(rec.action);
            }
            rec.action.loc=access.world.loc;rec.action.inter.loc=access.world.loc;
            rec.action.X=state.action.X;rec.action.Y=state.action.Y;rec.action.nazv=state.action.nazv;
            rec.action.inter.actionText=state.action.actionText;g.actionObj=rec.action.inter;
         }
         if(interpolated)NativeFields.motion(g,state.native);else NativeFields.apply(g,state.native);
         if(g.vis.parent!==access.world.grafon.visObjs[int(g.sloy)])access.world.grafon.visObjs[int(g.sloy)].addChild(g.vis);
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
               // Native redraw/UI consumers also inspect the actor's weapon,
               // including the remote actor. Keep its reference and child slot
               // on the confirmed object, not the entry profile's old gun.
               g.currentWeapon=rec.weapon;g.childObjs[0]=rec.weapon;
            }
            var v:Object=rec.weapon.vis;
            if(!interpolated)NativeFields.apply(rec.weapon,w.native);
            // Layer can change when the owner ducks behind/comes out of cover.
            // Creation used the local constructor's layer, before confirmation.
            if(w.attached) {if(v.parent!==access.world.grafon.visObjs[int(w.layer)])access.world.grafon.visObjs[int(w.layer)].addChild(v as DisplayObject);}
            else if(v.parent!=null)v.parent.removeChild(v);
            rec.weapon.hold=w.hold;
            v.x=w.x;v.y=w.y;v.rotation=w.rotation;v.scaleX=w.sx;v.scaleY=w.sy;
            VisualPose.apply(v as DisplayObject,w.visual);
         } else if(rec.weapon!=null) {
            rec.weapon.remVisual();rec.weapon=null;rec.weaponId="";
            g.currentWeapon=null;g.childObjs[0]=null;
         }
      }
      private function applyProjectile(state:Object):void {
         if(state.clip=="")return;
         var clip:MovieClip=projectiles[state.id];
         if(clip==null) {
            var ClassRef:Class=access.visualClass(state.clip);
            clip=new ClassRef() as MovieClip;
            if(clip==null)throw new Error("Unsupported projectile display "+state.clip);
            projectiles[state.id]=clip;
         }
         // Native drawLoc replaces the display layers after terrain damage.
         // A live bullet can still be attached to a detached old layer; test
         // the actual current parent, not merely whether parent is non-null.
         if(clip.parent!==access.world.grafon.visObjs[int(state.layer)])access.world.grafon.visObjs[int(state.layer)].addChild(clip);
         clip.x=state.x;clip.y=state.y;clip.rotation=state.rotation;
         clip.scaleX=state.sx;clip.scaleY=state.sy;
         if(state.visual!=null)VisualPose.apply(clip,state.visual);
         else if(clip.currentFrame!=state.frame)clip.gotoAndStop(state.frame);else clip.stop();
         ++projectileApplications;
      }
      public function dispose():void {
         sound.dispose();
         for each(var rec:Object in peers) {
            rec.body.teleObj=null;
            rec.body.actionObj=null;
            if(rec.weapon!=null)rec.weapon.remVisual();
            if(rec.body!==access.world.gg)rec.body.remVisual();
            if(rec.actor!=null)rec.actor.destroy();
         }
         for each(var clip:DisplayObject in projectiles){if(clip.parent!=null)clip.parent.removeChild(clip);VisualPose.dispose(clip);}
         scene.dispose();peers={};projectiles={};endedProjectiles={};access.world.onPause=originalPause;
      }
      public function prepareReturn():void {if(access.weapons!=null)access.weapons.carryState(entrySave.game);}
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
