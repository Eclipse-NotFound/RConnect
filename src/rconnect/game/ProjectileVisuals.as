package rconnect.game {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   /** Pure display copies: no Bullet, collision, damage or ammunition changes. */
   public class ProjectileVisuals {
      private var seen:Dictionary=new Dictionary(true),active:Array=[],errors:Object={};
      public static function capture(b:Object):Object {
         if(b==null || GameBridge.probe(b,"vis")==null)return null;
         return {cls:getQualifiedClassName(b.vis),x:b.begx,y:b.begy,ex:b.X,ey:b.Y,
            dx:b.dx,dy:b.dy,ddy:b.ddy,rot:b.rot,vel:b.vel,spring:b.spring,
            ended:b.babah || !b.in_chain,blend:b.vis.blendMode};
      }
      public function receive(owner:Object,guns:Array,main:Object,player:Boolean=false):void {
         if(owner==null || guns==null)return;
         var slots:Object=seen[owner];if(slots==null)slots=seen[owner]={};
         for each(var gun:Object in guns) {
            var key:String=String(gun.slot)+":"+String(gun.id)+":"+String(gun.variant)+":"+String(gun.stream),last:int=int(slots[key]);
            for each(var event:Object in gun.events) {
               if(int(event.seq)<=last)continue;
               last=int(event.seq);var s:Object=event.flight;if(s==null)continue;
               try {
                  var cls:Class=main.loaderInfo.applicationDomain.getDefinition(String(s.cls)) as Class;
                  var vis:DisplayObject=new cls() as DisplayObject;
                  if(vis==null)continue;
                  if(vis is MovieClip)(vis as MovieClip).play();
                  vis.blendMode=String(s.blend);vis.rotation=Number(s.rot)*180/Math.PI;
                  vis.x=Number(s.x);vis.y=Number(s.y);
                  var world:Object=GameBridge.probe(owner,"loc");
                  var layer:DisplayObjectContainer=main.loaderInfo.applicationDomain.getDefinition("fe.World").w.grafon.visObjs[2] as DisplayObjectContainer;
                  if(layer==null)continue;
                  layer.addChild(vis);vis.visible=true;
                  active.push({vis:vis,s:s,at:getTimer(),loc:world,last:0});
                  if(active.length>160)remove(0);
                  if(player) {
                     var w:Object=GameBridge.probe(owner,"currentWeapon"),v:MovieClip=GameBridge.probe(w,"vis") as MovieClip;
                     if(v!=null)for each(var label:Object in v.currentLabels)if(label.name=="shoot"){v.gotoAndPlay("shoot");break;}
                  }
               } catch(e:*) {if(!errors[String(s.cls)]){errors[String(s.cls)]=true;Log.d("RConnectGame: projectile visual "+s.cls+" failed: "+e);}}
            }
            slots[key]=last;
         }
      }
      public function tick(loc:Object):void {
         var now:int=getTimer();
         for(var i:int=active.length-1;i>=0;i--) {
            var a:Object=active[i],s:Object=a.s,v:DisplayObject=a.vis;
            var age:Number=(now-int(a.at))/1000,frames:Number=age*30;
            if(a.loc!==loc || age>(s.ended?0.16:2.5) || v.parent==null){remove(i);continue;}
            var x:Number=Number(s.x)+Number(s.dx)*frames;
            var y:Number=Number(s.y)+Number(s.dy)*frames+Number(s.ddy)*frames*frames/2;
            if(s.ended) {var p:Number=Math.min(1,age/0.08);x=Number(s.x)+(Number(s.ex)-Number(s.x))*p;y=Number(s.y)+(Number(s.ey)-Number(s.y))*p;}
            else {
               // Stop cosmetic projectiles at the first native solid tile too.
               var tile:Object=loc.getAbsTile(x,y);
               if(tile==null || (tile.phis==1 && x>=tile.phX1 && x<=tile.phX2 && y>=tile.phY1 && y<=tile.phY2)){remove(i);continue;}
            }
            v.x=x;v.y=y;
            var laser:Object=GameBridge.probe(v,"laser");
            if(laser!=null && int(s.spring)>=2)laser.scaleX=Math.sqrt((x-s.x)*(x-s.x)+(y-s.y)*(y-s.y))/100;
            else if(int(s.spring)==1 && Number(s.vel)>100)v.scaleX=Number(s.vel)/100;
            v.alpha=s.ended?Math.max(0,1-age/0.16):1;
         }
      }
      private function remove(i:int):void {var v:DisplayObject=active[i].vis;if(v.parent!=null)v.parent.removeChild(v);active.splice(i,1);}
      public function reset():void {while(active.length)remove(active.length-1);seen=new Dictionary(true);}
      public function get count():int {return active.length;}
   }
}
