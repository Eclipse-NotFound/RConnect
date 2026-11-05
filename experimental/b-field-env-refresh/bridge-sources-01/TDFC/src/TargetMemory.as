package {
 /** Knowledge about one player incarnation. Never stores a live target object. */
 public class TargetMemory {
  public var lastSeen:int=-100000,lastVisual:int=-100000;
  public var sensing:Object;
  public var knownX:Number=0,knownY:Number=0;
  public var evidence:String="无";
  public var confirm:int=0,lastReport:int=-100000,lastHeard:int=-100000;
  public var observed:Boolean=false,confirmed:Boolean=false,heard:Boolean=false;
  public function copyFrom(other:TargetMemory):void {
   lastSeen=other.lastSeen;lastVisual=other.lastVisual;sensing=other.sensing;
   knownX=other.knownX;knownY=other.knownY;evidence=other.evidence;
   confirm=other.confirm;lastReport=other.lastReport;lastHeard=other.lastHeard;
   observed=other.observed;confirmed=other.confirmed;heard=other.heard;
  }
 }
}
