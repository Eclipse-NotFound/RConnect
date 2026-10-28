package {
 import flash.display.Sprite;
 import flash.desktop.NativeApplication;
 import flash.filesystem.File;
 import flash.filesystem.FileMode;
 import flash.filesystem.FileStream;
 import rconnect.game.ProjectilePlayback;
 public class ProjectileSampleChecks extends Sprite {
  private var checks:Array=[];
  public function ProjectileSampleChecks() {
   var result:Object={passed:false,checks:checks};
   try {run();result.passed=true;}catch(error:*){result.error=String(error);}
   var f:FileStream=new FileStream();f.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
   f.writeUTFBytes(JSON.stringify(result));f.close();NativeApplication.nativeApplication.exit(result.passed?0:1);
  }
  private function ok(value:Boolean,label:String):void{if(!value)throw new Error(label);checks.push(label);}
  private function point(t:int,x:Number,sx:Number=1):Object{return {at:t,x:x,y:x/2,sx:sx,sy:1,a:1,rot:0,f:2,ls:sx,lf:3};}
  private function run():void{
   for each(var cls:String in ["visbullmg","visbulplasma","visbullightning","visbullightning2","visbulflame","visbulflame2","visbuldflame","visbullaser"]){
    var shot:Object={cls:cls,frames:[point(100,0,1),point(140,80,3)],end:180};
    var before:String=JSON.stringify(shot),reuse:Object={},sample:Object=ProjectilePlayback.sample(shot,120,reuse);
    ok(sample===reuse&&sample.x==40&&sample.y==20&&sample.sx==2&&sample.ls==2,cls+" confirmed midpoint");
    ok(sample.f==2&&sample.lf==3&&JSON.stringify(shot)==before,cls+" native frames and source immutable");
    ok(ProjectilePlayback.sample(shot,99)==null&&ProjectilePlayback.sample(shot,180)==null,cls+" native lifetime retained");
    ok(ProjectilePlayback.sample(shot,170).x==80,cls+" never extrapolate");
   }
   var flip:Object={frames:[point(100,0),point(140,80,-1)],end:180};
   ok(ProjectilePlayback.sample(flip,120).sx==1,"flip stays authored; never shrink through zero");
   var angle:Object={frames:[point(100,0),point(140,80)],end:180};angle.frames[0].rot=179;angle.frames[1].rot=-179;
   ok(ProjectilePlayback.sample(angle,120).rot==180,"short angle crossing");
   ok(ProjectilePlayback.sample(angle,120).x==ProjectilePlayback.sample(angle,120).x,"paused cursor stable");
  }
 }
}
