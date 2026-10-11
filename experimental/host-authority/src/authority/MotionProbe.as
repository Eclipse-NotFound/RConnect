package authority {
   import flash.display.DisplayObject;
   import flash.filters.GlowFilter;
   /** Four real native fast-grab trials, then a real join-opened container.
    * Reference positions are sampled from original display objects before
    * serialization; interpolation is checked independently on screen frames. */
   public final class MotionProbe extends Probe {
      private var ready:Boolean=false,phase:int=-1,peerReady:int=-1,begin:int=-1,ending:int=-1;
      private var target:Object,container:Object,fy:Number=0,targetId:uint=0,receivedReport:Object;
      private var references:Object={},counts:Object={},sourceCount:int=0,heldCount:int=0;
      private var minX:Number,maxX:Number,dropCount:int=0,phaseSent:int=-1;
      private var readyToEnd:Boolean=false;
      public function MotionProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function message(v:Object):void {
         if(host && v.type=="motion-ready")peerReady=v.phase;
         if(host && v.type=="motion-report")receivedReport=v;
         if(!host && v.type=="motion-phase") {
            phase=v.phase;fy=v.floor;begin=-1;ending=-1;references={};
            counts={samples:0,missing:0,position:0,glow:0,interpolated:0,interpolationError:0,maxError:0,held:0,drops:0,maxDisplayAge:0};
         }
         if(!host && v.type=="motion-go")begin=v.tick;
         if(!host && v.type=="motion-reference")references[v.tick]=v;
         if(!host && v.type=="motion-end")ending=v.tick;
         if(!host && v.type=="motion-finish")finish();
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];frame.aimX=700;frame.aimY=fy-8;
         if(begin<0)return frame;
         var tick:int=(host?session.runtime.tick:RConnectMod.instance.replica.lastTick)-begin;
         if(phase<4 && (host?0:1)==phase%2) {
            if(tick>=18 && tick<23 || tick>=140 && tick<145)frame.buttons=Commands.TELE;
            if(tick>=32 && tick<136){frame.aimX=700+75*Math.sin((tick-32)*.18);frame.aimY=fy-115+50*Math.sin((tick-32)*.31);}
         }
         if(phase==4 && !host && tick>=18 && tick<60)frame.buttons=Commands.ACTION;
         return frame;
      }
      private function glow(clip:DisplayObject):Object {
         for each(var f:Object in clip.filters)if(f is GlowFilter)return {color:f.color,alpha:f.alpha,strength:f.strength};return null;
      }
      private function item(o:Object,session:HostSession,kind:String):Object {
         var v:DisplayObject=o.vis as DisplayObject;
         if(v==null || v.parent==null)return null;
         return {id:session.sceneId(o),kind:kind,x:v.x,y:v.y,held:o.levit>0,glow:glow(v)};
      }
      private function source(session:HostSession):void {
         if(begin<0 || readyToEnd)return;
         var items:Array=[],s:Object;
         if(phase<4) {
            s=item(target,session,phase<2?"box":"loot");
            if(s!=null)items.push(s);
            if(session.actors[phase%2].unit.teleObj===target){++heldCount;minX=Math.min(minX,target.X);maxX=Math.max(maxX,target.X);}
         }else {
            var o:Object=session.actors[1].unit.loc.firstObj;
            while(o!=null){if(NativeAccess.get(o,"item")!=null && o.item.id=="kofe"){s=item(o,session,"drop");if(s!=null){items.push(s);++dropCount;}}o=o.nobj;}
         }
         sourceCount+=items.length;
         session.link.send({type:"motion-reference",phase:phase,tick:session.runtime.tick,items:items});
      }
      private function display(s:Object,replica:ClientReplica):DisplayObject {
         var rec:Object=s.kind=="box"?replica.scene.objects[s.id]:replica.scene.effects.records[s.id];
         return rec==null?null:s.kind=="box"?rec.object.vis as DisplayObject:rec.clip as DisplayObject;
      }
      private function confirmed(frame:Object):void {
         var ref:Object=references[frame.tick];if(ref==null || ref.phase!=phase)return;
         var replica:ClientReplica=RConnectMod.instance.replica;
         for each(var s:Object in ref.items) {
            ++counts.samples;if(s.held)++counts.held;if(s.kind=="drop")++counts.drops;
            var clip:DisplayObject=display(s,replica);
            if(clip==null || clip.parent==null){++counts.missing;continue;}
            var error:Number=Math.max(Math.abs(clip.x-s.x),Math.abs(clip.y-s.y));
            counts.maxError=Math.max(counts.maxError,error);if(error>.06)++counts.position;
            var actual:Object=glow(clip);
            if((s.glow==null)!=(actual==null) || s.glow!=null && (actual.color!=s.glow.color || Math.abs(actual.alpha-s.glow.alpha)>.001 || Math.abs(actual.strength-s.glow.strength)>.001))++counts.glow;
         }
      }
      private function presentation(replica:ClientReplica):void {
         var a:Object=replica.clock.current,b:Object=replica.clock.next;
         if(a==null || b==null || replica.clock.fraction<=0)return;
         var first:Object=references[a.tick],next:Object=references[b.tick];
         if(first==null || next==null || first.phase!=phase || next.phase!=phase)return;
         counts.maxDisplayAge=Math.max(counts.maxDisplayAge,replica.lastFrame.time-a.time);
         for each(var left:Object in first.items)for each(var right:Object in next.items)if(left.id==right.id) {
            var clip:DisplayObject=display(left,replica);if(clip==null)continue;
            if(Math.abs(right.x-left.x)>=160 || Math.abs(right.y-left.y)>=160)continue;
            var part:Number=replica.clock.fraction,x:Number=left.x+(right.x-left.x)*part,y:Number=left.y+(right.y-left.y)*part;
            if(Math.abs(right.x-left.x)+Math.abs(right.y-left.y)<.1)continue;
            ++counts.interpolated;
            var error:Number=Math.max(Math.abs(clip.x-x),Math.abs(clip.y-y));
            if(error>.08)++counts.interpolationError;counts.maxError=Math.max(counts.maxError,error);
         }
      }
      private function start(session:HostSession,index:int):void {
         phase=index;peerReady=-1;begin=-1;readyToEnd=false;receivedReport=null;
         sourceCount=heldCount=dropCount=0;minX=Number.POSITIVE_INFINITY;maxX=Number.NEGATIVE_INFINITY;
         var room:Object=session.actors[0].unit.loc,Box:Class=access.definition("fe.loc.Box");
         for each(var a:PlayerActor in session.actors)a.unit.dropTeleObj();
         fy=ProbeArena.floor(room);
         for each(a in session.actors)access.scope.run(a.context,function():void {
            a.unit.setLocPos(a.id==index%2?570:400,fy);a.unit.dx=a.unit.dy=0;a.unit.invulner=true;
            a.unit.pers.skills.tele=5;a.unit.pers.setParameters();a.unit.mana=a.unit.maxmana=10000;
         });
         access.scope.run(session.actors[index%2].context,function():void {
            if(index<2 || index==4) {
               target=new Box(room,"case",700,fy,<obj cont="custom" lock="0" mine="0"><item id="kofe" kol="9"/></obj>,null);
               room.addObj(target);room.objs.push(target);target.addVisual();target.inter.setAct("lock",0);container=target;
            }else {
               var Loot:Class=access.definition("fe.loc.Loot"),Item:Class=access.definition("fe.serv.Item");
               target=new Loot(room,new Item(null,"kofe",27),700,fy,false,false,false);target.auto=false;target.addVisual();
            }
         });
         if(index==4)session.actors[1].unit.setLocPos(600,fy);
         session.link.send({type:"motion-phase",phase:phase,floor:fy});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready){ready=true;replica.confirmed=confirmed;}
            if(phase>=0 && phaseSent!=phase){phaseSent=phase;RConnectMod.instance.link.send({type:"motion-ready",phase:phase});}
            presentation(replica);
            if(ending>=0 && replica.displayFrame.tick>=ending) {
               check(counts.samples>60 && counts.missing==0 && counts.position==0,
                  "moving native objects retain exact confirmed positions phase "+phase,counts);
               check(counts.glow==0 && (phase==4 || counts.held>30),"native telekinesis glow belongs to the actual held object phase "+phase,counts);
               check(counts.interpolated>10 && counts.interpolationError==0,
                  "fast movement and drops use one continuous source timeline phase "+phase,counts);
               if(phase==4)check(counts.drops>40,"join-opened container shows native falling loot throughout its trajectory",counts);
               RConnectMod.instance.link.send({type:"motion-report",phase:phase,counts:counts});ending=-1;
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready){ready=true;var publish:Function=session.runtime.afterStep;session.runtime.afterStep=function():void{source(session);publish();};start(session,0);return;}
         if(begin<0 && peerReady==phase){begin=session.runtime.tick;session.link.send({type:"motion-go",tick:begin});}
         if(begin>=0 && session.runtime.tick-begin>=200 && !readyToEnd) {
            readyToEnd=true;
            if(phase<4) {
               check(heldCount>40 && maxX-minX>40,"real native grab follows a fast changing mouse path phase "+phase,{held:heldCount,range:maxX-minX});
               check(session.actors[phase%2].unit.teleObj==null && target.levit==0,
                  "new native press releases the target and ends its held state phase "+phase);
            }else check(container.inter.cont=="empty" && dropCount>40,"join's actual container action produces native falling drops",{samples:dropCount});
            session.link.send({type:"motion-end",tick:session.runtime.tick});
         }
         if(readyToEnd && receivedReport!=null && receivedReport.phase==phase) {
            if(phase<4)start(session,phase+1);else {session.link.send({type:"motion-finish"});finish();}
         }
      }
   }
}
