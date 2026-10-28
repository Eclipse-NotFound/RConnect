package fe.weapon {
    public class FAWeaponBridge {
        public static function recoil(w:Weapon, factor:Number, shots:int):void {
            var v:Number=w.rotUp;
            var before:Number=v>4.5?v/0.9:(v>0?v+0.5:0);
            before=Math.max(0,before-w.recoilUp*w.recoilMult*(1-factor)*shots);
            w.rotUp=before>5?before*0.9:(before>0.5?before-0.5:0);
            w.t_ret=Math.round(w.t_ret*factor);
        }
        public static function read(w:Weapon):Number { return w.rotUp; }
        public static function seed(w:Weapon, n:Number):void { w.rotUp=n; }
    }
}
