package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;
   /** Bullet.explVis recipes only. The caller owns the per-shot event number
    * and playback clock; receiving a repeated snapshot must not replay this.
    * Never call Bullet.explosion/explRun here: both settle damage and terrain. */
   public class ProjectileExplosionVisuals {
      private static var claimed:Dictionary=new Dictionary(true);
      public static function capture(b:Object,repeat:Boolean=false):Object {
         if(b==null || GameBridge.probe(b,"isExpl")!==true)return null;
         var x:Number=Number(GameBridge.probe(b,"X")),y:Number=Number(GameBridge.probe(b,"Y"));
         if(!isFinite(x) || !isFinite(y))return null;
         var weapon:Object=GameBridge.probe(b,"weap"),custom:*=GameBridge.probe(weapon,"visexpl");
         // A shattering PhisBullet emits before collision clamps X/Y outside
         // the floor/wall. Read that real Part's center, not the corrected body.
         if(!repeat && getQualifiedClassName(b)=="fe.weapon::PhisBullet") {
            var type:int=int(GameBridge.probe(b,"tipDamage"));
            var name:String=type==10?"acidexpl":type==3?"fireexpl":"";
            if(name!="") {
               var emitter:Object=getDefinitionByName("fe.graph.Emitter").arr[name];
               var bitmap:Object=emitter.blit?getDefinitionByName("fe.World").w.grafon.getSpriteList(emitter.blit,1):null;
               var nearest:Object=null,best:Number=1601;
               for(var p:Object=GameBridge.probe(GameBridge.probe(b,"loc"),"firstObj"),guard:int=0;p!=null && guard++<10000;p=GameBridge.probe(p,"nobj")) {
                  if(claimed[p] || getQualifiedClassName(p)!="fe.graph::Part")continue;
                  if(!((emitter.visClass!=null && GameBridge.probe(p,"vClass")===emitter.visClass)
                     || (bitmap!=null && GameBridge.probe(p,"blitData")===bitmap)))continue;
                  var dx:Number=Number(p.X)-x,dy:Number=Number(p.Y)-y,d:Number=dx*dx+dy*dy;
                  if(d<best){best=d;nearest=p;}
               }
               if(nearest!=null){claimed[nearest]=true;x=nearest.X;y=nearest.Y;}
            }
         }
         // isExpl is the native detonation flag, unlike babah or removal. The
         // visual may already be detached when the last simulation step ends.
         return {x:x,y:y,type:int(GameBridge.probe(b,"tipDamage")),
            water:Number(GameBridge.probe(b,"inWater"))>0,
            custom:custom==null?"":String(custom),repeat:repeat,
            ground:repeat?null:BurnVisuals.captureGround(b,x,y)};
      }

      public static function play(main:Object,loc:Object,state:Object):void {
         if(main==null || loc==null || state==null)return;
         var x:Number=Number(state.x),y:Number=Number(state.y);
         if(!isFinite(x) || !isFinite(y))return;
         var custom:String=state.custom==null?"":String(state.custom);
         var water:Boolean=state.water===true,names:Array=[],snd:String="";
         // Optional repeat identifies a later native explRun pulse. Capture
         // itself describes the first detonation; the source's native counter
         // supplies later pulses, never receiver wall-clock guesses.
         var repeat:Boolean=state.repeat===true;
         if(custom!="") {
            if(custom=="sparkle") {
               if(water){names=["explw","bubble"];snd="expl_uw";}
               else{names=["expl","sparkleexpl","iskr"];snd="bale_e";}
            } else names=[custom];
         } else switch(int(state.type)) {
            case 4:
               if(water){names=["explw","bubble"];snd="expl_uw";}
               else{names=["expl","flare","iskr"];snd="expl_e";}
               break;
            case 3:
               if(!water && !repeat){names=["fireexpl","flare","iskr"];snd="fire_e";
                  BurnVisuals.playGround(main,loc,state.ground as Array);}
               break;
            case 6:names=["plaexpl"];snd="exppla_e";break;
            case 7:names=["gas"];if(!repeat)snd="gas_e";break;
            case 8:names=["impexpl"];snd="emp_e";break;
            case 10:
               if(!repeat){names=["acidexpl","acidkap"];snd="acid_e";
                  BurnVisuals.playGround(main,loc,state.ground as Array,"acid");}
               break;
            case 11:names=["iceexpl","snow"];snd="cryo_e";break;
            case 15:names=["balefire","baleblast"];snd="bale_e";break;
            case 19:names=["pinkgas"];if(!repeat)snd="gas_e";break;
         }
         if(names.length==0)return;
         var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         for each(var name:String in names) {
            var options:Object=null;
            if(name=="iskr" || name=="snow")options={kol:16};
            else if(name=="acidkap")options={kol:Math.floor(Math.random()*5+30)};
            else if(name=="bubble")options={kol:30,rx:100,ry:100,rdx:10,rdy:10};
            emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);
         }
         if(snd!="") {
            var sound:Object=main.loaderInfo.applicationDomain.getDefinition("fe.Snd");
            sound.ps(snd,x,y);
         }
         // Ground Part objects are visual only. Native explosion/explGas,
         // loc.budilo and camera impulse are never called on this receiver.
      }
   }
}
