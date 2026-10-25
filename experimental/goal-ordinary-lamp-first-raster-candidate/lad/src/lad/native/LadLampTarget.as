package lad.native {
    import fe.unit.Unit;
    import fe.loc.Box;
    import fe.weapon.Bullet;
    /** No AI, locomotion, loot or death pipeline; participates in native projectile intersection. */
    public class LadLampTarget extends Unit {
        private var ladController:*;
        private var ladLamp:Object;
        public function LadLampTarget(controller:*,lamp:Object,location:*) {
            super();ladController=controller;ladLamp=lamp;
            var u:*=this;
            u.loc=location;u.id="lad_lamp";u.nazv="灯具";u.fraction=0;
            u.doop=true;u.isSats=false;u.showNumbs=false;u.levitPoss=false;u.activateTrap=0;
            u.dexter=0;u.dodge=0;u.invulner=false;u.hp=40;u.maxhp=40;u.xp=0;
            u.X=lamp.x;u.Y=lamp.bounds.bottom;u.scX=lamp.bounds.width;u.scY=lamp.bounds.height;
            u.X1=lamp.bounds.left;u.X2=lamp.bounds.right;u.Y1=lamp.bounds.top;u.Y2=lamp.bounds.bottom;
            u.sost=1;u.vis=null;u.inter.active=false;
        }
        override public function step():* { }
        override public function damage(amount:Number,kind:int,bullet:Bullet=null,critical:Boolean=false):Number {
            if(ladLamp.state.hp<=0) return 0;
            return ladController.hitLamp(ladLamp,amount,kind);
        }
        override public function udarBullet(bullet:Bullet,mode:int=0):int {
            var b:*=bullet;
            if(ladLamp.state.hp<=0) return -1;
            damage(Math.max(0,Number(b.damage)),int(b.tipDamage),bullet);
            return 1;
        }
        override public function udarUnit(unit:Unit,multiplier:Number=1):Boolean {return false;}
        override public function udarBox(box:Box):int {return 0;}
        override public function die(kind:int=0):* { }
        override public function setNull(reset:Boolean=false):* { }
    }
}
