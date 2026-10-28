package {
 import flash.system.ApplicationDomain;
 public final class BFieldCases {
  private var test:Object;
  private var m:Object,r:Object,d:ApplicationDomain,c:Object,a:Object,side:String,done:Boolean=false;
  public function BFieldCases(m:Object,r:Object,d:ApplicationDomain,c:Object,role:String,a:Object){
   if(c.scenario=="visualfield")test=new BVisualFieldCases(m,r,d,c,role,a);
   else if(c.scenario=="ui")test=new BUiCases(m,r,d,c,role,a);
   else if(c.scenario=="controls")test=new BGrabCases(m,r,d,c,role,a);
   else if(c.scenario=="darkteleport")test=new BDarkTeleportCases(m,r,d,c,role,a);
   else if(c.scenario=="textmotion"){BTextInterpolationChecks.run(m,d,a.check);test=new BTextMotionCases(m,r,d,c,role,a);}
   else if(c.scenario=="terrainlive")test=new BTerrainCases(m,r,d,c,role,a);
   else if(c.scenario=="motion")test=new BMotionCases(m,r,d,c,role,a);
   else if(c.scenario=="security"){this.m=m;this.r=r;this.d=d;this.c=c;this.a=a;side=role;}
   else throw new Error("Unknown external fixture "+c.scenario);
  }
  public function input():void {if(test!=null)test.input();}
  public function step():void {
   if(test!=null){test.step();return;}
   if(side=="host" && !done){done=true;BSecurityChecks.run(m.host,a.check);a.write("security-done.json",{done:true});}
   if(a.read("security-done.json")!=null)test=new BSecurityLiveCases(m,r,d,c,side,a);
  }
 }
}
