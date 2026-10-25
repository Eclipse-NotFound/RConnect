package lad {
    /** Attached after native actions; never occupies weapon/fist/pet array indices. */
    public final class LadPlayerTick {
        public var vis:*=null;
        private var owner:LadRuntime;
        private var player:*;
        public function LadPlayerTick(runtime:LadRuntime,value:*) {owner=runtime;player=value;}
        public function step():void {owner.simulationStep(player);}
        public function addVisual():void {}
        public function remVisual():void {}
        public function err():String {LadLog.write("PLAYER_ADAPTER_ERROR");return "LightAndDarkness player adapter";}
    }
}
