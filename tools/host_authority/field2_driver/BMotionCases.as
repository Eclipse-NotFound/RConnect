package {
 import flash.system.ApplicationDomain;
 import flash.utils.getQualifiedClassName;
 import flash.utils.getTimer;
 /** Micro experiment only; never a gameplay frame-rate qualification. */
 public final class BMotionCases {
  private var m:Object,d:ApplicationDomain,api:Object,side:String,stage:int=0,at:int,gun:Object;
  public function BMotionCases(mod:Object,root:Object,domain:ApplicationDomain,cfg:Object,role:String,a:Object){m=mod;d=domain;api=a;side=role;at=getTimer();}
  public function input():void {
   var w:Object=m.access.world;for each(var key:String in ["keyLeft","keyRight","keyAttack","keyTele","keyAction"])w.ctr[key]=false;
   if(side=="host" && stage==1){w.ctr.keyAttack=true;w.celX=w.gg.X+400;w.celY=w.gg.Y-25;w.cam.celX=w.cam.vx+w.celX*w.cam.scaleV;w.cam.celY=w.cam.vy+w.celY*w.cam.scaleV;}
  }
  public function step():void {
   if(side=="join"){
    if(api.read("motion-host.json")!=null){api.write("motion-join.json",{done:true});m.leaveSession();api.finish();}return;
   }
   if(stage==2){if(api.read("motion-join.json")!=null && m.role=="")api.finish();return;}
   var C:Object=d.getDefinition("authority.VisualMotionChecks"),g:Object=m.host.actors[0].unit;
   if(stage==0){
    C.run(m.access,api.check);
    m.access.scope.run(m.host.actors[0].context,function():void {
     var Weapon:Object=m.access.definition("fe.weapon.Weapon");g.pers.setForcLevel(30);g.pers.skills.smallguns=100;g.pers.setParameters();
     if(g.currentWeapon!=null)g.currentWeapon.remVisual();gun=Weapon["create"](g,"lmg",0);gun.setPers(g,g.pers);gun.loc=g.loc;gun.hp=gun.maxhp;gun.hold=30;
     g.invent.weapons.lmg=gun;g.invent.cWeaponId="lmg";g.currentWeapon=gun;g.childObjs[0]=gun;gun.addVisual();g.invent.items[gun.ammo].kol=1000;g.loc.base=false;
    });
    report("body",C.benchmark(g.vis,m.access.visualClass,500));report("weapon",C.benchmark(gun.vis,m.access.visualClass,500));stage=1;at=getTimer();return;
   }
   for(var o:Object=g.loc.firstObj;o!=null;o=o.nobj)if(getQualifiedClassName(o)=="fe.weapon::Bullet" && o.owner===g && o.vis!=null){
    report("native-fired-bullet",C.benchmark(o.vis,m.access.visualClass,1000));stage=2;api.write("motion-host.json",{done:true});return;
   }
   if(getTimer()-at>10000){api.check(false,"motion micro observes a real fired bullet");stage=2;api.write("motion-host.json",{done:true});}
  }
  private function report(name:String,result:Object):void {
   var exact:Boolean=true;for each(var row:Object in result.rows)exact=exact && row.equal===true;
   api.check(exact,"guarded and full native pose/pixels agree: "+name,result);
   api.write("motion-"+name+".json",result);
  }
 }
}
