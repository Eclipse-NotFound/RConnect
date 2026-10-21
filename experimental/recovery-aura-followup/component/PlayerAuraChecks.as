package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.filters.BlurFilter;
   import flash.filters.GlowFilter;
   import flash.geom.ColorTransform;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.utils.describeType;
   import rconnect.game.TelekinesisVisuals;
   import rconnect.game.PlayerBodyEffects;

   /** Real AIR display/filter components. No game, physics or TCP is emulated. */
   public class PlayerAuraChecks extends Sprite {
      private var rows:Array=[],failed:int=0;
      public function PlayerAuraChecks() {
         try {playerLifecycle();ownership();channelOwnership();bodyOwnership();validation();}
         catch(e:Error){check(false,"uncaught "+e.getStackTrace());}
         var out:FileStream=new FileStream();
         out.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         out.writeUTFBytes(JSON.stringify({pass:rows.length-failed,fail:failed,checks:rows,gameLoaded:false}));out.close();
         NativeApplication.nativeApplication.exit(failed?1:0);
      }
      private function check(ok:Boolean,label:String):void {rows.push({pass:ok,label:label});if(!ok)failed++;}
      private function body():Sprite {
         var v:Sprite=new Sprite();v.graphics.beginFill(0xffffff);v.graphics.drawRect(0,0,20,30);v.graphics.endFill();
         v.x=40;v.y=35;addChild(v);return v;
      }
      private function rgb(v:DisplayObject):String {
         var c:ColorTransform=v.transform.colorTransform;
         return JSON.stringify([c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,
            c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset]);
      }
      private function count(v:DisplayObject,cl:Class):int {var n:int=0;for each(var f:Object in v.filters)if(f is cl)n++;return n;}
      private function snapshot():BitmapData {var b:BitmapData=new BitmapData(120,120,false,0);b.draw(this);return b;}
      private function style():Object {
         var v:Sprite=new Sprite();v.filters=[new GlowFilter(0x20d0ff,.8,12,12,2,1,false,false)];
         v.transform.colorTransform=new ColorTransform(.8,.6,1,1,10,30,50,0);
         return TelekinesisVisuals.captureObject({levit:2,vis:v});
      }
      private function playerLifecycle():void {
         var aura:TelekinesisVisuals=new TelekinesisVisuals(),loc:Object={},v:Sprite=body();
         var player:Object={loc:loc,player:true,in_chain:false,sost:1,dead:false,vis:v,levit:2,x:5,dx:7};loc.gg=player;
         var original:String=rgb(v),before:BitmapData=snapshot(),s:Object=style();
         aura.object(player,s);aura.tick(loc,null,false);
         check(count(v,GlowFilter)==1,"actual local-player identity receives aura outside ordinary object chain");
         check(rgb(v)==JSON.stringify(s.ct),"local player's eight native tint channels match the source");
         var held:BitmapData=snapshot();var diff:Object=before.compare(held);
         check(diff is BitmapData,"aura changes actual AIR raster pixels");if(diff is BitmapData)BitmapData(diff).dispose();
         var halo:uint=held.getPixel(36,50);check(halo!=before.getPixel(36,50),"glow contributes pixels beyond body boundary");
         check(player.x==5&&player.dx==7&&player.levit==2,"presentation does not change movement or grab state");
         aura.object(player,null);aura.tick(loc,null,false);
         check(count(v,GlowFilter)==0&&rgb(v)==original,"release restores pre-grab glow and tint");
         var after:BitmapData=snapshot();diff=before.compare(after);
         check(diff===0,"released frame returns to exact pre-grab pixels");if(diff is BitmapData)BitmapData(diff).dispose();
         before.dispose();held.dispose();after.dispose();
         aura.object(player,s);aura.tick(loc,null,false);player.dead=true;aura.tick(loc,null,false);
         check(count(v,GlowFilter)==0&&rgb(v)==original,"dead player releases the presentation overlay");
         player.dead=false;aura.object(player,s);aura.tick(loc,null,false);player.loc={};aura.tick(loc,null,false);
         check(count(v,GlowFilter)==0,"leaving the room removes the overlay from the previous body");
         player.loc=loc;aura.object(player,s);aura.tick(loc,null,false);aura.reset();
         check(count(v,GlowFilter)==0&&rgb(v)==original,"session reset restores the old local body");
         loc.gg={};aura.object(player,s);aura.tick(loc,null,false);
         check(count(v,GlowFilter)==0,"player flag alone cannot admit an unrelated unlinked object");
         removeChild(v);
      }
      private function ownership():void {
         var aura:TelekinesisVisuals=new TelekinesisVisuals(),loc:Object={},v:Sprite=body(),s:Object=style();
         var u:Object={loc:loc,in_chain:true,sost:1,vis:v,levit:2};v.filters=[new BlurFilter(2,2,1)];
         aura.object(u,s);aura.tick(loc,null,false);
         check(count(v,GlowFilter)==1&&count(v,BlurFilter)==1,"object overlay preserves unrelated existing filters");
         v.filters=[new BlurFilter(3,3,1),new GlowFilter(0xe040b0)];
         v.transform.colorTransform=new ColorTransform(.3,1,.5,1,5,0,0,0);var replacement:String=rgb(v);
         aura.reset();check(count(v,GlowFilter)==1&&uint(v.filters[1].color)==0xe040b0&&rgb(v)==replacement,
            "release does not erase a newer local effect's filter or tint");
         aura.object(u,s);aura.tick(loc,u,false);
         check(uint(v.filters[1].color)==0xe040b0&&rgb(v)==replacement,"native local grab keeps presentation ownership");
         aura.reset();v.filters=[];v.transform.colorTransform=new ColorTransform();
         aura.object(u,s);aura.tick(loc,null,false);var old:Sprite=v;v=body();u.vis=v;aura.tick(loc,null,false);
         check(count(old,GlowFilter)==0&&count(v,GlowFilter)==1,"body replacement restores old visual and decorates new visual");
         aura.reset();check(count(v,GlowFilter)==0,"reset also cleans the replacement visual");removeChild(old);removeChild(v);
      }
      private function channels(v:DisplayObject,alpha:Boolean):String {
         var c:ColorTransform=v.transform.colorTransform;
         return JSON.stringify(alpha?[c.alphaMultiplier,c.alphaOffset]:
            [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.redOffset,c.greenOffset,c.blueOffset]);
      }
      private function channelOwnership():void {
         // 3 independent native changes x release/reset/body replacement.
         // All expected values come from real AIR display readback, not raw
         // decimal literals which AIR may store at fixed precision.
         for each(var change:String in ["alpha","rgb","both"])for each(var finish:String in ["release","reset","replace"]) {
            var aura:TelekinesisVisuals=new TelekinesisVisuals(),loc:Object={},v:Sprite=body(),s:Object=style();
            var u:Object={loc:loc,player:true,in_chain:false,sost:1,dead:false,vis:v,levit:2};loc.gg=u;
            v.transform.colorTransform=new ColorTransform(.9,.7,.5,.625,3,7,11,9);
            v.filters=[new BlurFilter(2,2,1),new GlowFilter(0x604020,.5,4,4,1,1)];
            var oldRGB:String=channels(v,false),oldAlpha:String=channels(v,true);
            aura.object(u,s);aura.tick(loc,null,false);
            var c:ColorTransform=v.transform.colorTransform;
            if(change=="rgb" || change=="both") {
               c.redMultiplier=.2;c.greenMultiplier=.9;c.blueMultiplier=.4;
               c.redOffset=13;c.greenOffset=17;c.blueOffset=23;
            }
            if(change=="alpha" || change=="both")c.alphaOffset=21;
            v.transform.colorTransform=c;
            if(change=="alpha" || change=="both")v.alpha=.375; // Native DisplayObject.alpha alias.
            // A newer unrelated blur must survive the glow restoration too.
            var filters:Array=v.filters;filters[0]=new BlurFilter(3,5,1);v.filters=filters;
            var wantRGB:String=change=="alpha"?oldRGB:channels(v,false);
            var wantAlpha:String=change=="rgb"?oldAlpha:channels(v,true);
            var replacement:Sprite=null,replacementBefore:String=null;
            if(finish=="release"){aura.object(u,null);aura.tick(loc,null,false);}
            else if(finish=="reset")aura.reset();
            else {
               replacement=body();replacement.transform.colorTransform=new ColorTransform(.4,.3,.8,.875,29,31,37,5);
               replacementBefore=rgb(replacement);u.vis=replacement;aura.tick(loc,null,false);
            }
            var label:String=change+" / "+finish;
            check(channels(v,false)==wantRGB,"RGB group ownership "+label+" actual="+channels(v,false)+" expected="+wantRGB);
            check(channels(v,true)==wantAlpha,"alpha group ownership "+label+" actual="+channels(v,true)+" expected="+wantAlpha);
            var live:Array=v.filters;
            check(count(v,GlowFilter)==1 && uint(live[1].color)==0x604020 && count(v,BlurFilter)==1
               && Number(live[0].blurX)==3 && Number(live[0].blurY)==5,
               "original glow and newer unrelated blur survive "+label);
            if(replacement!=null) {
               check(rgb(replacement)==JSON.stringify(s.ct)&&count(replacement,GlowFilter)==1,"replacement receives native aura "+label);
               aura.reset();check(rgb(replacement)==replacementBefore&&count(replacement,GlowFilter)==0,"replacement reset restores its own baseline "+label);
               removeChild(replacement);
            }
            aura.reset();removeChild(v);
         }
      }
      private function bodyOwnership():void {
         var effects:PlayerBodyEffects=new PlayerBodyEffects(),v:Sprite=body(),u:Object={player:false,vis:v};
         v.filters=[new GlowFilter(0x20d0ff)];v.transform.colorTransform=new ColorTransform(.8,.6,1,1,10,30,50,0);
         var original:String=rgb(v),s:Object={player:true,c:[1,1,1,1,0,0,0,0],a:1,parts:{}};
         var apply:Function=effects.apply;
         if(describeType(effects)..method.(@name=="apply").parameter.length()>=4)apply(u,s,false,true);else apply(u,s,false);
         check(rgb(v)==original&&count(v,GlowFilter)==1,"stale ordinary body snapshot cannot overwrite native peer-grab tint");
         effects.apply(u,s,false);
         check(v.transform.colorTransform.redMultiplier==1&&v.alpha==.75,"ordinary unheld teammate tint and opacity remain unchanged");
         u.player=true;v.transform.colorTransform=new ColorTransform(.4,.5,.6,.8,1,2,3,4);original=rgb(v);
         effects.apply(u,s,false);check(rgb(v)==original,"remote body synchronization never paints the actual local player");
         u.player=false;s.player=false;s.c=[1,.7,.6,.9,4,5,6,0];
         if(describeType(effects)..method.(@name=="apply").parameter.length()>=4)apply(u,s,false,true);else apply(u,s,false);
         // AIR stores the display multiplier in fixed precision. Compare to an
         // independent native display assignment, not the unquantized .7 literal.
         var expected:Sprite=new Sprite();expected.transform.colorTransform=new ColorTransform(1,.7,.6,.9,4,5,6,0);
         var actual:ColorTransform=v.transform.colorTransform,want:ColorTransform=expected.transform.colorTransform;
         check(actual.redMultiplier==want.redMultiplier && actual.greenMultiplier==want.greenMultiplier
            && actual.blueMultiplier==want.blueMultiplier && actual.redOffset==want.redOffset
            && actual.greenOffset==want.greenOffset && actual.blueOffset==want.blueOffset,
            "native-grip ownership branch does not skip ordinary enemy tint (actual green="+actual.greenMultiplier+", native="+want.greenMultiplier+")");
         removeChild(v);
      }
      private function validation():void {
         var klass:Object=TelekinesisVisuals;
         if(!("validated" in klass)){check(false,"bounded incoming aura validation exists");return;}
         var s:Object=style(),valid:Object=klass.validated(s);
         check(JSON.stringify(valid)==JSON.stringify(s),"finite native glow and tint round-trip unchanged");
         check(klass.validated(null)==null&&klass.validated({glow:[],ct:[1]})==null,"missing or malformed aura is rejected");
         s=style();s.glow[0][3]=NaN;check(klass.validated(s)==null,"nonfinite glow parameter is rejected");
         s=style();s.ct[7]=Infinity;check(klass.validated(s)==null,"nonfinite tint channel is rejected");
         s=style();s.glow=[s.glow[0],s.glow[0],s.glow[0],s.glow[0],s.glow[0]];
         check(klass.validated(s)==null,"too many filters are rejected");
         s=style();s.glow[0][2]=100000;s.ct[4]=100000;valid=klass.validated(s);
         check(valid.glow[0][2]==64&&valid.ct[4]==255,"oversized valid channels are bounded before painting local body");
      }
   }
}
