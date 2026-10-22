package rconnect.game {public class GameBridge {public static function probe(o:Object,k:String):*{try{return o!=null && k in o?o[k]:null;}catch(e:*){}return null;}}}
