package rconnect.game {
   import flash.desktop.NativeApplication;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Isolated diagnostic collector. Never advances, probes or redraws game state. */
   public class RestoreCostTrace {
      private static var enabled:Boolean=false,armed:Boolean=false;
      private static var stage:Stage,listeners:Array=[];
      private static var record:Object,frame:Object,render:Object;
      private static var scopes:Object={},completed:int=0;
      private static const LIMIT:int=3;

      public static function enable(value:Stage):void {
         if(stage!=null || value==null)return;
         if(NativeApplication.nativeApplication.applicationID.indexOf("pfe-modsettings-rconnect-coop-")!=0)return;
         enabled=true;stage=value;
         listen(Event.ENTER_FRAME,2147483647,"enter.top");
         listen(Event.ENTER_FRAME,90001,"enter.beforeRCPerception");
         listen(Event.ENTER_FRAME,89999,"enter.afterRCPerception");
         listen(Event.ENTER_FRAME,1,"enter.beforePriority0");
         listen(Event.ENTER_FRAME,-1,"enter.afterPriority0");
         listen(Event.ENTER_FRAME,-8999,"enter.beforeRCMask");
         listen(Event.ENTER_FRAME,-9001,"enter.afterRCMask");
         listen(Event.ENTER_FRAME,-9999,"enter.beforeRCMirror");
         listen(Event.ENTER_FRAME,-10001,"enter.afterRCMirror");
         listen(Event.ENTER_FRAME,-2147483648,"enter.bottom");
         listen(Event.RENDER,2147483647,"render.top");
         listen(Event.RENDER,-9999,"render.beforeRCView");
         listen(Event.RENDER,-10001,"render.afterRCView");
         listen(Event.RENDER,-2147483648,"render.bottom");
      }
      private static function listen(type:String,priority:int,label:String):void {
         var fn:Function=function(e:Event):void {boundary(label);};
         listeners.push({type:type,fn:fn,priority:priority,label:label});
         stage.addEventListener(type,fn,false,priority,false);
      }
      public static function transaction(role:String,key:String,epoch:int,barrier:int):void {
         if(!enabled || completed>=LIMIT)return;
         if(!armed) {
            if(key.indexOf("random_mane/")!=0)return;
            armed=true;
         }
         if(record!=null) {
            if(record.role==role && record.epoch==epoch && record.barrier==barrier)return;
            finish("overtaken-before-three-frames");
            if(completed>=LIMIT)return;
         }
         scopes={};frame=null;render=null;
         record={role:role,key:key,epoch:epoch,barrier:barrier,started:getTimer(),postAt:-1,
            phases:[],times:{},preGrantTimes:{},postGrantTimes:{},counts:{},classes:{},classOverflow:0,frames:[],
            scopeMismatches:0,diagnosticOnly:true,performanceQualified:false};
      }
      public static function phase(name:String):void {
         if(record!=null && record.phases.length<16)record.phases.push({name:name,at:getTimer()});
      }
      public static function postGrant():void {
         if(record==null)return;
         record.postAt=getTimer();phase("grant-or-commit-return");
      }
      public static function begin(name:String):void {
         if(record==null || (name.indexOf("frame.")==0 && frame==null))return;
         var stack:Array=scopes[name];if(stack==null)stack=scopes[name]=[];
         stack.push(getTimer());
      }
      private static function sum(target:Object,name:String,elapsed:int):void {
         var row:Object=target[name];if(row==null)row=target[name]={calls:0,ms:0,max:0};
         row.calls++;row.ms+=elapsed;row.max=Math.max(row.max,elapsed);
      }
      public static function end(name:String):void {
         if(record==null)return;
         var stack:Array=scopes[name];
         if(stack==null || stack.length==0) {
            if(name.indexOf("frame.")!=0)record.scopeMismatches++;
            return;
         }
         var started:int=int(stack.pop()),elapsed:int=getTimer()-started;
         sum(record.times,name,elapsed);
         sum(int(record.postAt)<0 || started<=int(record.postAt)?record.preGrantTimes:record.postGrantTimes,name,elapsed);
         if(frame!=null)sum(frame.times,name,elapsed);
      }
      public static function count(name:String,value:int=1):void {
         if(record==null)return;
         record.counts[name]=int(record.counts[name])+value;
         if(frame!=null)frame.counts[name]=int(frame.counts[name])+value;
      }
      public static function createdClass(name:String):void {
         if(record==null)return;
         if(record.classes[name]==null) {
            var size:int=0;for(var k:String in record.classes)size++;
            if(size>=64){record.classOverflow++;return;}
         }
         record.classes[name]=int(record.classes[name])+1;
      }
      private static function boundary(label:String):void {
         if(record==null || int(record.postAt)<0)return;
         var now:int=getTimer();
         if(label=="enter.top") {
            // Finish on the fourth ENTER_FRAME, after all renders belonging to
            // the first three complete frames. This log is outside their work.
            if(record.frames.length>=3){finish("three-complete-enter-frames");return;}
            frame={n:record.frames.length+1,started:now,marks:[],renders:[],times:{},counts:{}};
            record.frames.push(frame);render=null;
         }
         if(frame==null)return; // Ignore the partial frame containing the grant.
         if(label.indexOf("enter.")==0)frame.marks.push({name:label,at:now});
         else {
            if(label=="render.top") {
               if(frame.renders.length>=16){count("render.markOverflow");render=null;return;}
               render={marks:[]};frame.renders.push(render);
            }
            if(render!=null)render.marks.push({name:label,at:now});
         }
      }
      public static function abort():void {if(record!=null)finish("room-failure-incomplete");}
      private static function finish(reason:String):void {
         if(record==null)return;
         var output:Object=record;record=null;frame=null;render=null;
         output.finished=getTimer();output.reason=reason;output.openScopes={};
         for(var key:String in scopes)if(scopes[key].length)output.openScopes[key]=scopes[key].length;
         scopes={};completed++;
         if(completed>=LIMIT) {
            enabled=false;
            for each(var listener:Object in listeners)stage.removeEventListener(listener.type,listener.fn,false);
            listeners=[];
         }
         // One bounded aggregate per transaction. Existing errors and room
         // checkpoint diagnostics are untouched; no per-unit disk writes.
         Log.d("RConnectRestoreCost "+JSON.stringify(output));
      }
   }
}
