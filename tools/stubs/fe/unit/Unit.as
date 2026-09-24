package fe.unit {
import fe.weapon.Bullet;
// Compile-only external declarations. Never embedded in the production SWF.
public class Unit {
internal var mapxml:XML;
internal var uniqName:Boolean;
internal var t_hp:int;
internal var aiNapr:int;
internal var aiVNapr:int;
internal var aiTTurn:int;
internal var aiPlav:int;
internal var aiState:int;
internal var aiTCh:int;
internal var aiSpok:int;
internal var maxSpok:int;
internal var timerDie:int;
internal var t_hitPart:int;
internal var hitSumm:Number;
internal var t_mess:int;
internal var kolChild:int;
public function Unit(id:String=null,difficulty:Number=100,map:XML=null,data:Object=null) {}
public function damage(amount:Number,type:int,bullet:Bullet=null,periodic:Boolean=false):Number {return 0;}
public function die(type:int=0):* {}
} }
