package fa {
    /** Game-step state machine; no timers advance while the game is paused. */
    public class BipodSupport {
        public var deployed:Boolean=false, remaining:int=0, suppressed:Boolean=false;
        private var automatic:Boolean=false, lowSupport:Boolean=false, heading:Number=0, exceeded:int=0;
        public function reset():void {deployed=false;remaining=0;suppressed=false;automatic=false;lowSupport=false;exceeded=0;}
        private function fold():void {deployed=false;remaining=0;automatic=false;lowSupport=false;exceeded=0;}
        private function start(sample:Object,config:Object,auto:Boolean):void {
            heading=sample.angle;automatic=auto;lowSupport=sample.low;exceeded=0;remaining=int(config.deploySteps);deployed=remaining==0;
        }
        public function toggle(sample:Object,config:Object):Boolean {
            if(deployed||remaining>0){fold();suppressed=sample.low;return true;}
            if(!sample.available||!sample.ground||sample.blocked||sample.speed>config.moveTolerance)return false;
            suppressed=false;start(sample,config,false);return true;
        }
        public function update(sample:Object,config:Object,advance:Boolean):void {
            if(!sample.low)suppressed=false;
            if(!sample.available||!sample.ground||sample.blocked||lowSupport&&!sample.low||automatic&&!config.autoBipod) {fold();return;}
            if(deployed||remaining>0) {
                var tooFar:Boolean=sample.speed>config.moveTolerance||Runtime.angleDelta(sample.angle,heading)>Number(config.turnTolerance)*Math.PI/180;
                if(tooFar) {
                    if(advance)exceeded++;
                    if(config.retractGrace==0||exceeded>=config.retractGrace){fold();return;}
                }else exceeded=0;
                if(advance&&remaining>0&&!tooFar&&--remaining==0)deployed=true;
            }else if(advance&&config.autoBipod&&sample.low&&!suppressed&&sample.speed<=config.moveTolerance)start(sample,config,true);
        }
    }
}
