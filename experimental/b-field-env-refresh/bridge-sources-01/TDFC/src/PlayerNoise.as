package {
 /** 保留原版脚步/枪声产生与衰减，只限制响度；不把普通移动变成全局警报。 */
 public class PlayerNoise {
  private static var state:NoiseState=new NoiseState();
  public static function reset():void {state.reset();}
  public static function cap(value:Number):Number {return Math.max(0,Math.min(Config.NOISE_MAX,value));}
  public static function update(g:*):void {
   state.update(g);
  }
 }
}
