package authority {
   public final class AreasProbe extends Probe {
      private var begin:int=-1,tick:int=0,phase:int=0,area:Object,fy:Number=0,over:int=0,out:int=0,runs:Array=[0,0],first:Array;
      public function AreasProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(value:Object):void {
         if(host && begin<0 && value.type=="input" && value.player==1 && value.probeStart is Number)begin=int(value.probeStart);
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.actions=[];frame.buttons=0;if(!host && begin>=0)frame.probeStart=begin;return frame;
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            var f:Object=replica.lastFrame;if(begin<0)begin=f.tick;tick=f.tick-begin;
            if(tick>250){check(f.players[0].x>=990 && f.players[1].x>=990,"join confirms both native portal arrivals");finish();}return;
         }
         if(session==null || !session.active)return;
         var a:PlayerActor=session.actors[0],b:PlayerActor=session.actors[1],room:Object=a.unit.loc;
         if(area==null) {
            fy=ProbeArena.floor(room);a.unit.setLocPos(500,fy);b.unit.setLocPos(600,fy);
            var Area:Class=access.definition("fe.loc.Area");area=new Area(room,<obj/>,null,false);area.setSize(400,fy-120,700,fy+1);area.noRad=true;
            area.run=function():void {++runs[access.world.gg===a.unit?0:1];};area.over=function():void {++over;};area.out=function():void {++out;};
            room.acts.push(area);room.addObj(area);first=[runs[0],runs[1]];
         }
         if(begin<0)return;tick=session.runtime.tick-begin;
         if(phase==0 && tick>40) {
            phase=1;check(runs[0]>10 && runs[0]==runs[1] && a.unit.noRad && b.unit.noRad,"both real occupants receive a native area's continuous personal effect",{runs:runs});
            check(over==1 && out==0,"shared area entry fires once with two occupants");b.unit.setLocPos(850,fy);
         }
         if(phase==1 && tick>80) {phase=2;check(over==1 && out==0,"one player leaving does not falsely close an occupied shared area");a.unit.setLocPos(850,fy);}
         if(phase==2 && tick>120) {phase=3;check(out==1,"shared area exit fires when its last player leaves");area.onPort=true;area.portX=24;area.portY=int((fy+1)/40)-1;b.unit.setLocPos(500,fy);}
         if(phase==3 && tick>160) {phase=4;check(b.unit.X>=990 && a.unit.X<900,"joining player uses its own native portal entry");a.unit.setLocPos(500,fy);}
         if(phase==4 && tick>205) {phase=5;check(a.unit.X>=990 && b.unit.X>=990,"host can use the same portal after the joining player");check(access.world.gg===a.unit && access.scope.depth==0,"area callbacks preserve the active player's context");}
         if(tick>270)finish();
      }
   }
}
