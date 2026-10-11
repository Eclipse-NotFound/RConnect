package rconnect.game
{
   import flash.utils.getDefinitionByName;
   import flash.utils.getTimer;

   /** Number lifetime must not depend on Unit.actions: mirror receivers never run AI. */
   public class HitFeedback
   {
      private var channels:Object = {};

      public function show(target:Object, hpLoss:Number, shieldLoss:Number,style:Object=null,force:Boolean=false):void
      {
         try
         {
            var w:Object = getDefinitionByName("fe.World")["w"];
            if(w.showHit < 1 || !force && GameBridge.probe(target,"showNumbs") == false) return;
            if(hpLoss > 0.5) emit(target,hpLoss,"hp",w.showHit,style);
            if(shieldLoss > 0.5) emit(target,shieldLoss,"shield",w.showHit,style);
         }
         catch(err:*) {} // Feedback must never interrupt damage settlement.
      }

      private function emit(target:Object, loss:Number, channel:String, mode:int,style:Object):void
      {
         var now:int = getTimer();
         var rec:Object = channels[channel];
         var part:Object = rec == null ? null : rec.part;
         var reuse:Boolean = mode == 2 && rec != null && now-rec.at < 500
            && part != null && part.liv > 0 && part.in_chain && part.vis.parent != null;
         var total:Number = reuse ? rec.total+loss : loss;
         var txt:String = (channel == "shield" ? "S -" : "")+Math.round(total);
         if(reuse)
         {
            part.vis.numb.text = txt;
            part.liv = 60;
         }
         else
         {
            var emitter:Object = getDefinitionByName("fe.graph.Emitter")["arr"]["numb"];
            var x:Number=style==null?target.X:GameBridge.probeNum(style,"x",target.X);
            var y:Number=style==null?target.Y-target.scY/2:GameBridge.probeNum(style,"y",target.Y-target.scY/2);
            part = emitter.cast(target.loc,x,y-(channel=="shield"?20:0),
               {txt:txt,frame:style==null?1:int(style.frame),scale:style==null?1:Number(style.scale),rx:20});
            if(part != null && channel == "shield") part.vis.numb.textColor = 0x66CCFF;
         }
         channels[channel] = {part:part,total:total,at:now};
      }
   }
}
