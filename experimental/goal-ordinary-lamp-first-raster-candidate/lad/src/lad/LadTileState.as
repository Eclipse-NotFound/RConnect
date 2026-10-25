package lad {
    /** Typed snapshot of the native tile properties that affect illumination. */
    public final class LadTileState {
        public var opacity:Number;
        public var back:String;
        public var rear:Boolean;
        public var front:String;
        public var physical:int;
        public var shape:int;
        public var diagonal:int;
        public var top:Number;
        public function LadTileState(opacity:Number,back:String,rear:Boolean,front:String,physical:int,shape:int,diagonal:int,top:Number) {
            this.opacity=opacity;this.back=back;this.rear=rear;this.front=front;
            this.physical=physical;this.shape=shape;this.diagonal=diagonal;this.top=top;
        }
    }
}
