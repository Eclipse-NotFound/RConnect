package {import addiction.Runtime;public class AddictionSystemMod {
 public static var instance:Runtime;
 public static function init(main:*):void {if(!instance)instance=new Runtime(main);}
} }
