package authority {
   import flash.display.MovieClip;
   import flash.display.DisplayObject;
   /** Confirmation-only B1 presentation. No attack(), damage() or object step. */
   public class ClientReplica {
      public var tactics:TacticsBridge;
      public var access:NativeAccess,frames:uint=0,lastTick:uint=0,lastFrame:Object;
      public var scene:ReplicaScene;
      public var peerProfile:Object;
      public var playerApplications:Array=[0,0],projectileApplications:uint=0;
      private var peers:Object={},projectiles:Object={};
      private var originalPause:Boolean;
      private var decoder:FrameDelta=new FrameDelta();
      private var satsEpoch:int=-1;
      public var satsRefreshes:uint=0;
      public function ClientReplica(access:NativeAccess) {
         this.access=access;originalPause=access.world.onPause;
         VisualPose.resolve=access.visualClass;
         access.world.onPause=true;
         scene=new ReplicaScene(access);
      }
      public function apply(frame:Object):void {
         frame=decoder.decode(frame);
         if(frame.tick<lastTick)return;
         lastTick=frame.tick;lastFrame=frame;++frames;
         MapState.apply(access,frame.map);
         if(frame.scene!=null && scene.apply(frame.scene)) {
            for each(var old:Object in peers) {
               old.body.loc=access.world.loc;
               if(old.weapon!=null)old.weapon.loc=access.world.loc;
            }
         }
         var present:Boolean=frame.room===access.roomKey();access.world.visual.visible=present;
         CharacterState.apply(access,frame.character);
         for each(var state:Object in frame.players) {
            if(state.room===frame.room && present)applyPlayer(state);
            else if(peers[state.id]!=null) {
               peers[state.id].body.remVisual();
               if(peers[state.id].weapon!=null)peers[state.id].weapon.remVisual();
            }
         }
         var active:Object={};
         for each(var p:Object in frame.projectiles)if(p.room===frame.room && present){applyProjectile(p);active[String(p.id)]=true;}
         for(var key:String in projectiles)if(!active[key]){
            var clip:DisplayObject=projectiles[key];if(clip.parent!=null)clip.parent.removeChild(clip);delete projectiles[key];
         }
         access.world.gui.setHp();access.world.gui.setMana();access.world.gui.setWeapon();
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
            access.world.grafon.visObjs[1].addChild(clip);projectiles[state.id]=clip;
         }
         clip.x=state.x;clip.y=state.y;clip.rotation=state.rotation;
         clip.scaleX=state.sx;clip.scaleY=state.sy;clip.gotoAndStop(state.frame);
         ++projectileApplications;
      }
      public function dispose():void {
         for each(var rec:Object in peers) {
            if(rec.weapon!=null)rec.weapon.remVisual();
            if(rec.body!==access.world.gg)rec.body.remVisual();
            if(rec.actor!=null)rec.actor.destroy();
         }
         for each(var clip:DisplayObject in projectiles)if(clip.parent!=null)clip.parent.removeChild(clip);
         scene.dispose();peers={};projectiles={};access.world.onPause=originalPause;
      }
   }
}
