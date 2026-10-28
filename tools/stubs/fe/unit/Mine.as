package fe.unit { public class Mine extends Unit {
internal var aiN:int;
public function Mine(id:String=null,difficulty:Number=100,map:XML=null,data:Object=null) {super(id,difficulty,map,data);}
public function dropLoot():* {}
} }
