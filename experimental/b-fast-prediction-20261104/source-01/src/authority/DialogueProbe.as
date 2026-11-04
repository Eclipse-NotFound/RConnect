package authority {
 import flash.utils.getTimer;
 /** Native GUI scripts stay on the host; the client only presents and acknowledges. */
 public final class DialogueProbe extends Probe {
  private var stage:int=0,done:int=0,phase:int=0,at:int=0,lastAck:int=0,seen:Boolean=false;
  private var remote:PlayerActor,request:Object;
  public function DialogueProbe(a:NativeAccess,h:Boolean){super(a,h);}
  override public function message(value:Object):void {
   if(host && value.type=="input" && value.probeDialogDone is Number)done=int(value.probeDialogDone);
   if(!host && value.type=="probe-dialog")request=value;
  }
  override public function input(frame:Object,session:HostSession):Object {frame.buttons=0;if(!host)frame.probeDialogDone=done;return frame;}
  override public function observe(session:HostSession,replica:ClientReplica):void {
   if(finished)return;
   var w:Object=access.world;
   if(!host) {
    if(request==null || replica==null || replica.displayFrame==null)return;
    var modal:Object=replica.displayFrame.character.modal;
    if(stage!=request.stage){stage=request.stage;phase=0;seen=false;at=getTimer();}
    if(stage==1 || stage==3) {
     if(!seen && modal.inform!=null && w.gui.vis.inform.txt.text.indexOf("B加入侧提示")>=0) {
      seen=true;check(!w.gg.ggControl,"joining native information panel owns only joining control");
      w.ctr.keyPressed=true;
     }
     if(seen && modal.inform==null && w.gg.ggControl) {
      check(true,"joining acknowledgement completes the host-side native information script");done=stage;
     }
    } else if(stage==2) {
     var text:String=w.gui.vis.dial.txt.text;
     if(phase==0 && modal.dial!=null && text.indexOf("B第一页")>=0) {
      phase=1;check(!w.gg.ggControl,"joining dialogue begins with original first line");w.ctr.keyPressed=true;
     }
     if(phase==1 && text.indexOf("B第二页")>=0) {phase=2;check(true,"one acknowledgement advances to original second line");w.ctr.keyPressed=true;}
     if(phase==2 && modal.dial==null && w.gg.ggControl){check(true,"final dialogue acknowledgement restores joining control");done=stage;}
    } else if(stage==4) {
     if(!seen && modal.imp!=null && replica.lastFrame.paused) {seen=true;check(w.gui.vis.imp.txt.text.indexOf("B重要提示")>=0,"native important message is visible during shared pause");}
     if(seen && modal.imp!=null && getTimer()-lastAck>500){w.ctr.keyPressed=true;lastAck=getTimer();}
     if(seen && modal.imp==null && !replica.lastFrame.paused) {
      check(true,"important message acknowledgement releases shared pause without closing the connection");done=stage;
      SceneChecks.picture(access,"native-dialogue-complete.png");finish();
     }
    }
    return;
   }
   if(session==null || !session.active)return;
   if(stage==0) {
    remote=session.actors[1];var fy:Number=ProbeArena.floor(w.loc);
    w.gg.setLocPos(300,fy);remote.unit.setLocPos(600,fy);
    access.definition("fe.Res")["d"].appendChild(<txt id="rconnect_b_dialog_fixture"><n><r>B第一页</r><r>B第二页</r></n></txt>);
    next(session);return;
   }
   if(done<stage)return;
   if(stage<4)check(remote.unit.ggControl,"original joining GUI script restores its native player",{stage:stage});
   if(stage==3) {
    check(w.gui.vis.inform.visible && !w.gg.ggControl,"joining acknowledgement cannot dismiss host's independent information panel");
    w.ctr.keyPressed=true;w.gui.step();check(w.gg.ggControl,"host acknowledges its own native information script");
   } else check(w.gg.ggControl,"remote modal input does not disable the host player",{stage:stage});
   if(stage==4){check(!session.pause.paused,"host resumes after the confirmed native popup closes");finish();return;}
   next(session);
  }
  private function next(session:HostSession):void {
   ++stage;
   if(stage==3)access.world.gui.informText("B宿主自己的提示");
   if(stage==4)session.pause.enabled=true;
   access.scope.run(remote.context,function():void {
    if(stage==1 || stage==3)remote.context.gui.informText("B加入侧提示 "+stage);
    else if(stage==2)remote.context.gui.dialog("rconnect_b_dialog_fixture");
    else if(stage==4)remote.context.gui.impMess("B重要提示","B重要提示内容","pot0");
   });
   session.link.send({type:"probe-dialog",stage:stage});
  }
 }
}
