package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import rconnect.game.*;

   /** Expected RED: two equality assertions expose an unsafe deferred design.
    * No game, TCP, animation library or timing benchmark is executed here. */
   public final class PositionAliasCounterexample extends Sprite {
      private var assertions:Array=[],failed:int=0,evidence:Object={};
      public function PositionAliasCounterexample(){addEventListener(Event.ADDED_TO_STAGE,start);}
      private function check(ok:Boolean,label:String):void {
         assertions.push({passed:ok,label:label});if(!ok)failed++;
         trace((ok?"PASS ":"FAIL ")+label);
      }
      private function equal(a:*,b:*):Boolean {
         if(a===b)return true;if(a is Number&&b is Number&&isNaN(a)&&isNaN(b))return true;
         if(a==null||b==null||typeof a!=typeof b||typeof a!="object"||(a is Array)!=(b is Array))return false;
         var ak:Array=[],bk:Array=[],k:String;for(k in a)ak.push(k);for(k in b)bk.push(k);ak.sort();bk.sort();
         if(ak.join("|")!=bk.join("|"))return false;
         for each(k in ak)if(!equal(a[k],b[k]))return false;return true;
      }
      private function snap(stamp:int,x:Number,f:Number,stopped:Boolean=false):Object {
         return {sampleTime:stamp,x:x,y:20,aimX:x+100,aimY:40,roomKey:"fixture",roomEpoch:1,
            weapons:[{slot:0,id:"lmg",variant:1,stream:1,rot:0,ox:2,oy:3,
               display:{x:x,y:4,r:0,sx:1,sy:1}}],
            visual:{anim:"run",pose:{blit:{f:f,first:0,length:16,ret:0,loop:true,df:1,st:stopped,stab:false}}}};
      }
      private function pair(stopped:Boolean=false):Object {
         var p:Object={a:RemoteMotionBefore.enemy(),b:RemoteMotionAfter.enemy(),
            aa:[snap(1000,0,1,stopped),snap(1100,10,5,stopped)],
            bb:[snap(1000,0,1,stopped),snap(1100,10,5,stopped)]};
         for(var i:int=0;i<2;i++){p.a.push(p.aa[i],1000+i*100);p.b.push(p.bb[i],1000+i*100);}
         return p;
      }
      private function run():void {
         var p:Object=pair();
         var a:Object=p.a.sample(1150),position:Object=MotionPositionAccess.sample(p.b,1150);
         var oldWeaponX:Number=a.weapons[0].display.x,oldBodyF:Number=a.bodyPose.blit.f;
         check(a.x===position.x&&a.y===position.y&&p.a.sourceTime===p.b.sourceTime,
            "deferred design starts with exactly equal position and source cursor");
         // Both callers retain the nested input arrays from push. The old
         // complete sample has already copied interpolated weapon/body values.
         p.aa[1].weapons[0].display.x+=50;p.bb[1].weapons[0].display.x+=50;
         p.aa[1].visual.pose.blit.f+=4;p.bb[1].visual.pose.blit.f+=4;
         a=p.a.currentSample;var b:Object=p.b.currentSample;
         evidence.interpolated={sourceTime:p.a.sourceTime,oldWeaponX:a.weapons[0].display.x,
            deferredWeaponX:b.weapons[0].display.x,oldBodyF:a.bodyPose.blit.f,deferredBodyF:b.bodyPose.blit.f};
         check(equal(a.weapons,b.weapons),"SEMANTIC EQUIVALENCE: nested weapon mutation before getter must not alter an already sampled pose");
         check(equal(a.bodyPose,b.bodyPose),"SEMANTIC EQUIVALENCE: nested blit mutation before getter must not alter an already sampled pose");
         check(a.weapons[0].display.x===oldWeaponX&&a.bodyPose.blit.f===oldBodyF,
            "production complete sample retains its computed numeric values");
         check(equal(p.a.sample(1150),p.b.sample(1150)),
            "a new complete sample observes the changed inputs equally without moving time");

         p=pair(true);a=p.a.sample(1150);MotionPositionAccess.sample(p.b,1150);b=p.b.currentSample;
         check(a.bodyPose===p.aa[0].visual.pose&&b.bodyPose===p.bb[0].visual.pose,
            "non-interpolating stopped pose preserves the original input-object identity");
         p.aa[0].visual.pose.blit.f+=9;p.bb[0].visual.pose.blit.f+=9;
         check(equal(a.bodyPose,b.bodyPose)&&a.bodyPose.blit.f===10,
            "stopped-pose input mutation stays live: blanket deep-copy would change old semantics");

         p=pair();a=p.a.sample(1150);b=p.b.sample(1150);
         p.a.sample(1151);MotionPositionAccess.sample(p.b,1151);
         check(equal(a,b)&&a===p.a.currentSample&&b===p.b.currentSample,
            "published-state guard protects old output aliases but does not solve nested input ownership");
      }
      private function start(e:Event):void {
         removeEventListener(Event.ADDED_TO_STAGE,start);
         try {run();}catch(error:*){check(false,"uncaught component error "+String(error)+" "+error.getStackTrace());}
         var out:Object={passed:failed==0,failed:failed,assertions:assertions,evidence:evidence,
            expected_semantic_failures:2,design_rejected:true,native_game_test:false,performance_qualified:false};
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(out));stream.close();NativeApplication.nativeApplication.exit(failed?1:0);
      }
   }
}
