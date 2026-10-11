package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.events.TimerEvent;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getTimer;
   import flash.utils.getQualifiedClassName;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** A native hidden enemy Mine, outside the host's detection direction.
    * Only the joining player's real perception can discover it. */
   public class MineSightTestDoc extends Sprite {
      public static const MOD_CLASS:Class=RConnectMod;
      private var mod:RConnectMod,host:Boolean,t:Timer=new Timer(100),links:Dictionary=new Dictionary();
      private var phase:String="boot",at:int=getTimer(),lastReady:int=0;
      private var baseX:Number,baseY:Number,mine:Object,reported:Boolean=false;
      public function MineSightTestDoc() {
         var id:String=NativeApplication.nativeApplication.applicationID;
         if(id.indexOf("rconnect-coop-")<0)return;host=id.indexOf("-host-")>=0;
         t.addEventListener(TimerEvent.TIMER,tick);t.start();
      }
      private function check(ok:Boolean,s:String):void {Log.d("COOP "+(ok?"PASS ":"FAIL ")+"mine-sight "+s);}
      private function change(s:String):void {phase=s;at=getTimer();reported=false;}
      private function send(op:String,p:Object=null):void {p=p||{};p.type="mine-sight-test";p.op=op;
         if(host)mod.session.server.broadcast(p);else mod.session.link.send(p);}
      private function watch(l:TcpLink):void {if(l!=null&&!links[l]){links[l]=true;l.addEventListener(TcpLink.MESSAGE,receive);}}
      private function arena():void {
         var loc:Object=mod.game.loc;
         for(var yy:int=240;yy<loc.limY-40;yy+=40)for(var xx:int=80;xx<loc.limX-480;xx+=40) {
            var clear:Boolean=true;
            for(var dx:int=0;dx<=460&&clear;dx+=20) {
               if(loc.getAbsTile(xx+dx,yy+1).phis!=1){clear=false;break;}
               for(var dy:int=20;dy<=180;dy+=20)if(loc.getAbsTile(xx+dx,yy-dy).phis!=0){clear=false;break;}
            }
            if(clear){baseX=xx;baseY=yy;return;}
         }
         throw new Error("no native mine detection corridor");
      }
      private function position(near:Boolean):void {
         var g:Object=mod.game.gg;g.disabled=true;g.invulner=true;g.dx=g.dy=0;
         g.setPos(baseX+(host?40:near?320:440),baseY);g.storona=host?-1:near?-1:1;
         g.eyeX=g.X;g.eyeY=g.Y-30;g.setVisPos();
      }
      private function install():void {
         mod.game.forceCloseOverlays();mod.config.setValue("followTeammate","0");
         if(host) {
            var c:Class=mod.main.loaderInfo.applicationDomain.getDefinition("fe.unit.Mine") as Class;
            mine=new c("mine");mine.putLoc(mod.game.loc,baseX+250,baseY);mine.sens=0;mine.setVis(false);
            mod.game.loc.units.push(mine);mod.game.loc.addObj(mine);
         }
         position(false);change("initial");
      }
      private function findMine():Object {
         for each(var u:Object in mod.game.loc.units)
            if(getQualifiedClassName(u)=="fe.unit::Mine"&&u.id=="mine"&&Math.abs(u.X-baseX-250)<1)return u;
         return null;
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p.type!="mine-sight-test")return;
         if(p.op=="done"){finish();return;}
         if(host&&p.op=="ready"&&phase=="boot") {arena();install();send("setup",{x:baseX,y:baseY});}
         else if(!host&&p.op=="setup") {baseX=p.x;baseY=p.y;install();}
         else if(host&&p.op=="initial") {check(p.hidden,"join initially cannot see hidden mine");send("approach");change("approach");}
         else if(!host&&p.op=="approach") {position(true);change("approach");}
         else if(host&&p.op=="result") {check(p.visible,"join renders mine discovered without host exploration");
            check(mine.isVis&&mine.vis.stage!=null&&mine.vis.visible,"discovery reaches host's native mine");send("done");finish();}
      }
      private function tick(e:TimerEvent):void {
         mod=RConnectMod.instance;if(mod==null||mod.game.gg==null)return;
         if(host)for each(var peer:Object in mod.session.peers)watch(peer.link as TcpLink);else watch(mod.session.link);
         if(mod.game.world.clickReq==1){mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true));mod.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true));}
         if(getTimer()-at>65000){check(false,"timeout "+phase);send("done");finish();return;}
         if(phase=="boot") {if(!TestRoomReadiness.ready(mod,host))return;
            if(!host&&getTimer()-lastReady>1000){lastReady=getTimer();send("ready");}return;}
         if(!mod.session.rooms.ready||mod.session.rooms.busy||mod.game.isTransitioning())return;
         position(phase=="approach");mod.stage.invalidate();
         if(phase=="initial"&&getTimer()-at>1800&&!reported) {
            mine=findMine();if(mine==null)return;reported=true;
            check(!mine.isVis,"native trap starts hidden");
            if(host)check(mod.game.gg.lookInvis(mine)==false,"host's own perception cannot discover this mine");
            else send("initial",{hidden:!mine.isVis});
         }
         if(phase=="approach"&&getTimer()-at>2600&&!reported) {
            mine=findMine();if(mine==null)return;reported=true;
            if(!host) {check(mod.game.gg.lookInvis(mine),"joining native perception sees the mine");
               send("result",{visible:mine.isVis&&mine.vis!=null&&mine.vis.stage!=null&&mine.vis.visible});}
         }
      }
      private function finish():void {if(phase=="done")return;change("done");t.stop();Log.d("COOP EFFECTS DONE mine-sight "+(host?"host":"join"));}
   }
}
