package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.text.TextField;
   import flash.utils.getQualifiedClassName;
   /** Both real weapons, then a native player-placed proximity mine. */
   public final class FriendlyProbe extends Probe {
      private var tick:uint=0,ready:Boolean=false,phase:int=0,hp:Array=[],mine:Object,mineHP:Number=0;
      private var digitRefs:Object={},digitSamples:Array=[0,0],digitWrong:int=0,digitFirst:Object,observing:Boolean=false;
      public function FriendlyProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(!host && value.type=="friendly-baseline")hp=value.hp;
         if(!host && value.type=="friendly-digits")digitRefs[value.tick]=value;
      }
      private function digit(vis:Object):Object {
         var c:Object=vis.transform.colorTransform;
         return {text:vis.numb.text,color:vis.numb.textColor,frame:MovieClip(vis).currentFrame,
            x:vis.x,y:vis.y,sx:vis.scaleX,sy:vis.scaleY,alpha:vis.alpha,
            tint:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset]};
      }
      private function digitsSource(s:HostSession):void {
         var now:int=s.runtime.tick,owner:int=now>=110 && now<170?0:now>=190 && now<240?1:-1;
         if(owner<0)return;
         var values:Array=[],p:Object=s.actors[0].unit.loc.firstObj;
         while(p!=null) {
            if(p.vis is MovieClip && "numb" in p.vis && p.vis.numb is TextField && p.vis.parent!=null && p.vis.currentFrame==2)
               values.push({key:s.sceneId(p),value:digit(p.vis)});
            p=p.nobj;
         }
         if(values.length>0)s.link.send({type:"friendly-digits",tick:now,owner:owner,values:values});
      }
      private function digitsConfirmed(f:Object):void {
         var ref:Object=digitRefs[f.tick];if(ref==null)return;delete digitRefs[f.tick];
         for each(var record:Object in ref.values) {
            ++digitSamples[ref.owner];var rec:Object=RConnectMod.instance.replica.scene.effects.records[record.key];
            var ok:Boolean=rec!=null && rec.clip.parent!=null && "numb" in rec.clip;
            if(ok) {
               var actual:Object=digit(rec.clip),expected:Object=record.value;
               ok=actual.text===expected.text && Number(actual.text)>0 && actual.color===expected.color && actual.frame==expected.frame;
               for each(var field:String in ["x","y","sx","sy","alpha"])ok=ok && Math.abs(actual[field]-expected[field])<.001;
               for(var i:int=0;i<8;i++)ok=ok && actual.tint[i]===expected.tint[i];
            }
            if(!ok){++digitWrong;if(digitFirst==null)digitFirst={tick:f.tick,owner:ref.owner,expected:record,actual:actual,missing:rec==null};}
         }
      }
      override public function input(frame:Object,session:HostSession):Object {
         if(host && session!=null)tick=session.runtime.tick;
         frame.buttons=host && (tick>=30 && tick<45 || tick>=110 && tick<130) || !host && tick>=190 && tick<210?Commands.FIRE:0;
         frame.actions=[];frame.aimX=host?700:400;frame.aimY=access.world.gg.Y-40;return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;tick=replica.lastTick;
            if(!observing){observing=true;replica.confirmed=digitsConfirmed;}
            if(tick>430) {
               check(replica.lastFrame.friendlyFire,"join receives the host's enabled friendly-fire rule");
               check(hp.length==2 && replica.lastFrame.players[0].hp<hp[0] && replica.lastFrame.players[1].hp<hp[1],
                  "join confirms real friendly damage below each original native health baseline",{before:hp,after:[replica.lastFrame.players[0].hp,replica.lastFrame.players[1].hp]});
               check(replica.lastFrame.spawnsByPlayer[0]>0 && replica.lastFrame.spawnsByPlayer[1]>0,"friendly damage comes from both players' native projectiles");
               check(digitSamples[0]>0 && digitSamples[1]>0 && digitWrong==0,
                  "both directions of friendly fire preserve native damage text, position, color and scale",
                  {samples:digitSamples,wrong:digitWrong,first:digitFirst});
               SceneChecks.picture(access,"friendly-fire.png");finish();
            }
            return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=a.unit.loc;
         tick=session.runtime.tick;
         if(!ready) {
            var publish:Function=session.runtime.afterStep;
            session.runtime.afterStep=function():void{digitsSource(session);publish();};access.world.showHit=1;
            ready=true;var fy:Number=Math.floor((room.limY-120)/40)*40-1,row:int=int((fy+1)/40);
            for each(var u:Object in room.units)if(u!=null && !u.player){u.disabled=true;u.remVisual();}
            for(var x:int=6;x<29;x++)for(var y:int=row-6;y<=row;y++) {
               var t:Object=room.space[x][y];t.phis=y==row?1:0;t.visi=t.t_visi=1;t.water=0;t.shelf=false;t.diagon=t.stair=0;t.door=t.trap=null;
               t.phX1=x*40;t.phX2=(x+1)*40;t.phY1=y*40;t.phY2=(y+1)*40;
               if(t.phis==0){t.front=t.back=t.zad="";t.vid=t.vid2=t.zForm=0;}
            }
            room.black=false;
            for each(var actor:PlayerActor in session.actors) {
               access.scope.run(actor.context,function():void {actor.unit.pers.healAll();actor.unit.pers.setParameters();actor.unit.hp=actor.unit.maxhp;});
               actor.unit.setLocPos(actor.id==0?400:700,fy);actor.unit.dx=actor.unit.dy=0;
               actor.unit.currentWeapon.hold=50;actor.unit.currentWeapon.precision=actor.unit.currentWeapon.deviation=0;
               actor.unit.pers.jammedMult=0;actor.unit.skin=0;actor.unit.invulner=false;
            }
            hp=[a.unit.hp,b.unit.hp];session.combat.enabled=false;session.link.send({type:"friendly-baseline",hp:hp.concat()});
         }
         if(phase==0 && tick>75) {
            phase=1;check(b.unit.hp==hp[1] && session.runtime.spawnsByPlayer[0]>0,"disabled friendly fire lets actual native bullets pass without teammate damage",{before:hp[1],after:b.unit.hp});
            session.combat.enabled=true;
         }
         if(phase==1 && tick>170) {phase=2;check(b.unit.hp<hp[1],"host native gun damages the real joining player when enabled",{before:hp[1],after:b.unit.hp});}
         if(phase==2 && tick>240) {
            phase=3;check(a.unit.hp<hp[0],"join input damages the real host through its native weapon",{before:hp[0],after:a.unit.hp});
            session.combat.enabled=false;
            access.scope.run(a.context,function():void {
               var Weapon:Class=access.definition("fe.weapon.Weapon"),w:Object=Weapon["create"](a.unit,"mine",0);
               a.unit.invent.items.mine.kol=3;w.setPers(a.unit,a.unit.pers);w.lvl=0;w.addVisual();
               var old:Object=a.unit.currentWeapon;a.unit.currentWeapon=w;a.unit.celX=a.unit.X+30;a.unit.celY=a.unit.Y;
               w.step();w.attack(true);w.step();w.remVisual();a.unit.currentWeapon=old;
               for each(var placed:Object in room.units)if(getQualifiedClassName(placed)=="fe.unit::Mine" && placed.rconnectOwner===a.unit)mine=placed;
               if(mine!=null){mine.setPos(b.unit.X+10,b.unit.Y);mine.dx=mine.dy=0;mine.fixed=true;mine.reloadTime=0;mine.oduplenie=0;mine.otschet=0;}
            });
            check(mine!=null && mine.rconnectOwner===a.unit,"native WThrow preserves the mine's actual placer");mineHP=b.unit.hp;
         }
         if(phase==3 && tick>280) {
            phase=4;check(mine!=null && mine.sost<3 && b.unit.hp==mineHP,"disabled friendly fire prevents a teammate triggering the placed mine");session.combat.enabled=true;
         }
         if(phase==4 && tick>415) {
            phase=5;check(mine!=null && mine.sost>=3 && b.unit.hp<mineHP,"enabled friendly fire lets the teammate trigger and take native mine blast damage",{before:mineHP,after:b.unit.hp,state:mine==null?-1:mine.sost});
            check(access.world.gg===a.unit && access.scope.depth==0,"friendly hits and mine sensing restore the host's native context");
         }
         if(tick>450)finish();
      }
   }
}
