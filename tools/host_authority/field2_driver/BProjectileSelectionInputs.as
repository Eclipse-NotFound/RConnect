package {
   import flash.system.ApplicationDomain;
   /** Small external input replay. Call after loading the candidate, before
    * the real two-player controls cases. No game state or private fields. */
   public final class BProjectileSelectionInputs {
      private static function hint(id:int=11):Object {
         return {id:id,a:101,b:102,t:0.5,x:210,y:410,room:"test-room",epoch:1,roomEpoch:1};
      }
      private static function frame(seq:int,buttons:int,pick:Object=null):Object {
         return {session:"pick-test",player:1,room:"test-room",roomEpoch:1,epoch:1,weaponEpoch:1,
            seq:seq,buttons:buttons,aimX:999,aimY:777,actions:[],projectilePick:pick};
      }
      public static function run(domain:ApplicationDomain,check:Function):void {
         var Commands:Class=domain.getDefinition("authority.Commands") as Class;
         var Selection:Object=domain.getDefinition("authority.ProjectileSelection");
         var c:Object=new Commands("pick-test",1,"test-room"),p:Object=hint(),out:Object;
         check(Selection.valid(p),"projectile input: adjacent presentation interpolation accepted");
         check(c.accept(frame(1,128,p),1000)=="","projectile input: initial Q edge accepted");
         p.id=999;p.x=999;
         check(c.accept(frame(2,128,hint(22)),1001)=="" && c.accept(frame(3,0,hint(33)),1002)=="",
            "projectile input: held and release packets accepted before native consume");
         out=c.consume(1003);
         check((out.pressed&128)!=0 && (out.buttons&128)!=0 && out.projectilePick.id==11 && out.projectilePick.x==210,
            "projectile input: first edge picture is immutable and survives held/release packets",out);
         check(c.accept(frame(4,128,hint(44)),1004)=="","projectile input: next physical Q edge accepted");
         out=c.consume(1005);
         check(out.projectilePick!=null && out.projectilePick.id==44,"projectile input: a new edge can select another projectile",out);
         c.accept(frame(5,128,hint(55)),1006);out=c.consume(1007);
         check(out.projectilePick==null && (out.pressed&128)==0,"projectile input: held Q does not replay selection",out);
         c.accept(frame(6,0),1008);c.accept(frame(7,128),1009);out=c.consume(1010);
         check(out.projectilePick==null && (out.pressed&128)!=0,"projectile input: an empty new click does not reuse an older target",out);
         c.accept(frame(8,0),1011);c.accept(frame(9,128,hint(66)),1012);out=c.consume(1513);
         check(out.projectilePick==null && out.buttons==0,"projectile input: missing-input lease expires the pending pick",out);
         c.clear();c.accept(frame(10,128,hint(77)),2000);c.retarget("another-room",2);out=c.consume(2001);
         check(out.projectilePick==null && out.buttons==0,"projectile input: room retarget clears pending pick",out);
         var invalid:Array=[],bad:Object;
         bad=hint();bad.t=NaN;invalid.push(bad);
         bad=hint();bad.t=1.01;invalid.push(bad);
         bad=hint();bad.b=104;invalid.push(bad);
         bad=hint();bad.id=0;invalid.push(bad);
         bad=hint();bad.x=Infinity;invalid.push(bad);
         bad=hint();bad.epoch=0;invalid.push(bad);
         var all:Boolean=true;for each(bad in invalid)all=all && !Selection.valid(bad);
         check(all,"projectile input: invalid IDs, fractions, coordinates and nonadjacent frames rejected");
         bad=hint();bad.b=0;bad.t=0;
         check(Selection.valid(bad),"projectile input: discrete or paused picture needs only its presentation ID");
         c=new Commands("pick-test",1,"test-room");bad=hint();bad.t=NaN;
         check(c.accept(frame(1,128,bad),2000)=="projectile-pick" && c.accept(frame(1,128,hint()),2001)=="",
            "projectile input: rejected metadata does not consume sequence or Q edge");
      }
   }
}
