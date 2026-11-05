package {
 /** Owns only the movement-noise value it last wrote for one native player. */
 public class NoiseState {
  private var player:*,originalRun:Number=NaN,lastRun:Number=NaN;
  public function reset():void {
   try {if(player && GameBridge.num(player,"noiseRun")==lastRun)player.noiseRun=originalRun;}catch(e:Error){}
   player=null;originalRun=lastRun=NaN;
  }
  public function update(g:*):void {
   if(player!==g){reset();player=g;originalRun=GameBridge.num(g,"noiseRun",200);}
   var current:Number=GameBridge.num(g,"noiseRun",200);
   if(!isNaN(lastRun) && current!=lastRun)originalRun=current;
   lastRun=Math.min(originalRun,GameBridge.get(g,"isSit",false)?Config.NOISE_SNEAK:Config.NOISE_RUN);
   g.noiseRun=lastRun;g.noise=PlayerNoise.cap(GameBridge.num(g,"noise"));
  }
 }
}
