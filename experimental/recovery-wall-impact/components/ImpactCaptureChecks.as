package {
   import flash.display.BitmapData;
   import flash.display.Sprite;
   import flash.display.MovieClip;
   import fe.World;
   import fe.graph.Part;
   import fe.weapon.Bullet;
   import rconnect.game.EnergyImpactVisuals;
   import rconnect.game.BallisticImpactVisuals;
   import rconnect.game.RemoteMotion;
   public class ImpactCaptureChecks {
      private static var location:Object;
      public static function run(check:Function):void {
         var source:EnergyImpactVisuals=new EnergyImpactVisuals(),loc:Object={active:true},w:Object={loc:loc,flare:"plasma"};
         location=loc;
         var b:Bullet=bullet(w,"plasma"),p:Part=part(new flPlasma(),100,100);
         b.nobj=p;p.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,1000);var wire:Array=source.capture(w);
         check(wire.length==1 && wire[0].cls=="flPlasma" && wire[0].frames[0].x==100,"stationary actual Part is captured at exact native coordinates");
         source.observeWeapon(w,1001);
         check(source.capture(w).length==1,"same native Part cannot become two events");
         var layer:Sprite=new Sprite(),clock:RemoteMotion=new RemoteMotion();
         World.w={grafon:{visObjs:[layer,layer,layer,layer,layer]}};
         var main:Object={loaderInfo:{applicationDomain:{getDefinition:function(name:String):Object {
            if(name=="fe.World")return World;
            if(name=="flPlasma")return flPlasma;
            if(name=="visualFlame")return visualFlame;
            throw new Error("Unexpected native boundary "+name);
         }}}};
         var receiver:EnergyImpactVisuals=new EnergyImpactVisuals(),channel:Object={};
         receiver.receive(channel,wire,loc,main,0,0,clock);receiver.tick(loc,1000);
         check(layer.numChildren==1 && layer.getChildAt(0)!==p.vis,"receiver creates distinct cosmetic clip without native Part");
         p.in_chain=false;source.observeWeapon(w,1034);wire=source.capture(w);clock.sourceTime=1200;
         receiver.receive(channel,wire,loc,main,0,0,clock);receiver.tick(loc,1200);receiver.tick(loc,1201);
         check(layer.numChildren==0,"native end retires copied flash");
         receiver.receive(channel,wire,loc,main,0,0,clock);receiver.tick(loc,1202);
         check(layer.numChildren==0,"repeated completed energy packet cannot resurrect it");
         source.reset();receiver.reset();
         // A same-position ambient flash is not proof that a flying bullet hit.
         b=bullet(w,"plasma");b.babah=false;p=part(new flPlasma(),100,100);b.nobj=p;p.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,2000);check(source.capture(w).length==0,"unhit bullet does not claim nearby ambient flash");
         source.reset();b.babah=true;b.tilehit=false;
         source.observeWeapon(w,2010);check(source.capture(w).length==0,"expired bullet cannot claim same-position fresh ambient flash");
         source.reset();b.tilehit=true;p.mliv=3;p.liv=1;
         source.observeWeapon(w,2020);check(source.capture(w).length==0,"new collision cannot claim old stationary impact");
         source.reset();p.liv=3;b.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,2030);b.nobj=p;
         source.observeWeapon(w,2031);check(source.capture(w).length==0,"ended bullet cannot steal a later neighbouring hit");
         source.reset();var ph:fe.weapon.PhisBullet=new fe.weapon.PhisBullet();
         ph.weap=w;ph.loc=loc;ph.flare="plasma";ph.babah=true;ph.explRadius=0;ph.tilehit=true;
         ph.X=ph.Y=100;ph.parr=[];ph.nobj=p;loc.firstObj=ph;
         source.observeWeapon(w,2040);check(source.capture(w).length==0,"PhisBullet override does not invent a configured but absent flare");
         source.reset();b=bullet(w,"plasma");var b2:Bullet=bullet(w,"plasma");
         p=part(new flPlasma(),100,100);var p2:Part=part(new flPlasma(),100,100);
         b.nobj=b2;b2.nobj=p;p.nobj=p2;p2.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,2050);check(source.capture(w).length==2,"overlapping real shots each capture one fresh flare");
         source.reset();w.flare="flame";b=bullet(w,"flame");
         p=part(new visualFlame(),110,91);p.mliv=15;p.liv=14;b.nobj=p;p.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,3000);wire=source.capture(w);
         check(wire.length==1 && wire[0].frames[0].x==110 && wire[0].frames[0].y==91,"moving impact keeps actual jittered native position");
         var extra:Part=part(new visualFlame(),100,100);extra.mliv=extra.liv=15;p.nobj=extra;extra.nobj=null;
         p.X=108;p.vis.x=108;source.observeWeapon(w,3034);wire=source.capture(w);
         check(wire.length==1 && wire[0].frames.length==2 && wire[0].frames[1].x==108,"later burning Part is not added to an already captured flame hit");
         source.reset();b=bullet(w,"flame");p=part(new visualFlame(),100,100);p.mliv=15;p.liv=12;b.nobj=p;p.nobj=null;loc.firstObj=b;
         source.observeWeapon(w,4000);check(source.capture(w).length==0,"old nearby flame is not accepted as a new impact");
         source.reset();p.liv=15;b.tilehit=false;b.parr=[];
         source.observeWeapon(w,4100);check(source.capture(w).length==0,"flame lifetime ending without collision creates no hit");
         source.reset();b.tilehit=true;p.X=p.vis.x=150;
         source.observeWeapon(w,4200);check(source.capture(w).length==0,"distant flame is not claimed by this collision");
         source.reset();
         // Verify the real ballistic association and >50-particle grouping with
         // data-boundary Parts; random native sprite drawing is tested in-game.
         var atlas:BitmapData=new BitmapData(1,1),other:BitmapData=new BitmapData(1,1);
         World.w={grafon:{getSpriteList:function(name:String,index:int):BitmapData {return name=="sprBlood"?atlas:other;}}};
         var hit:Object={babah:true,explRadius:0,vel:10,loc:loc,parr:[{blood:1}],tilehit:false,
                         tipDecal:0,vis:null,X:100,Y:100,dx:10,dy:0};
         var previous:Part=null;loc.firstObj=null;
         for(var i:int=0;i<73;i++) {p=part(new MovieClip(),100,100);p.blitData=atlas;p.mliv=p.liv=30;
            if(previous==null)loc.firstObj=p;else previous.nobj=p;previous=p;}
         previous.nobj=null;BallisticImpactVisuals.reset();var captured:Object=BallisticImpactVisuals.capture(hit,5000);
         check(captured!=null && captured.groups.length==2 && captured.groups[0].count+captured.groups[1].count==73,"overlapping pellets retain all 73 actual particles without 50-particle truncation");
         check(BallisticImpactVisuals.capture(hit,5001)==null,"claimed ballistic Parts are not captured again");
         BallisticImpactVisuals.reset();loc.firstObj=null;
         check(BallisticImpactVisuals.capture(hit,5002)==null,"first ended ballistic sample with no native particles remains empty");
         loc.firstObj=p;
         check(BallisticImpactVisuals.capture(hit,5003)==null,"old ended ballistic bullet cannot claim later fresh particles");
         BallisticImpactVisuals.reset();hit.parr=[];
         check(BallisticImpactVisuals.capture(hit,5002)==null,"expiry cannot invent collision from nearby particles");
         atlas.dispose();other.dispose();BallisticImpactVisuals.reset();
      }
      private static function bullet(w:Object,flare:String):Bullet {
         var b:Bullet=new Bullet();b.weap=w;b.loc=w.loc;b.babah=true;b.flare=flare;b.explRadius=0;
         b.X=b.Y=100;b.tilehit=true;b.parr=[];return b;
      }
      private static function part(v:MovieClip,x:Number,y:Number):Part {
         var p:Part=new Part();p.loc=location;p.vis=v;p.in_chain=true;p.X=v.x=x;p.Y=v.y=y;p.mliv=p.liv=3;p.sloy=3;
         return p;
      }
   }
}
