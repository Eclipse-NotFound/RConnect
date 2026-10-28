package {
 import flash.system.ApplicationDomain;
 /** Exercise the real loaded PoseTween against the frozen uncached algorithm.
  * Synthetic immutable wire data only. No game, clock or entity mutation. */
 public final class BCadenceChecks {
  private static function pose(x:Number,y:Number=10):Object {
   return {x:x,y:y,a:1,v:true,sx:1,sy:1,r:15,m:[1,0,0,1,x,y],f:1,
    children:[{n:"limb",i:0,cls:"flash.display::MovieClip",s:{x:1,y:2,a:1,v:true,sx:1,sy:1,r:0,f:1,m:[1,0,0,1,1,2]}}]};
  }
  private static function record(id:int,key:int,x:Number):Object {
   return {id:id,key:key,room:"test-room",positionEpoch:1,x:x,y:10,rotation:15,
    visual:pose(x),pose:pose(x),fields:{X:x,Y:10,X1:x-3,X2:x+3,Y1:6,Y2:10},weapons:[]};
  }
  private static function frame(projectiles:Array,units:Array,objects:Array=null,effects:Array=null):Object {
   return {room:"test-room",tick:42,time:100,pauseEpoch:1,paused:false,
    timeControl:{phase:"idle",cycle:0},players:[],projectiles:projectiles,
    projectileEvents:[{id:99,ended:true}],scene:{key:"test-room",units:units,objects:objects==null?[]:objects,
     effects:effects==null?[]:effects,tiles:[{x:1,y:2,v:[0]}],terrainRevision:7},character:{sentinel:"unchanged"}};
  }
  private static function equal(a:*,b:*):Boolean {
   if(a===b)return true;
   if(a is Number && b is Number && isNaN(a) && isNaN(b))return true;
   if(a==null || b==null || typeof(a)!="object" || typeof(b)!="object" || (a is Array)!=(b is Array))return false;
   if(a is Array && a.length!=b.length)return false;
   for(var key:String in a)if(!b.hasOwnProperty(key) || !equal(a[key],b[key]))return false;
   for(key in b)if(!a.hasOwnProperty(key))return false;
   return true;
  }
  private static function compare(Type:Object,a:Object,b:Object,t:Number):Boolean {
   return equal(Type.frame(a,b,t),BCadenceReferenceChecks.frame(a,b,t));
  }
  public static function run(domain:ApplicationDomain,check:Function):void {
   var Type:Object=domain.getDefinition("authority.PoseTween"),a:Object,b:Object,actual:Object;
   var left:Array=[record(7,3,0)],shared:Array=[record(7,9,40),record(8,3,80)];
   a=frame(left,left,left,left);b=frame(shared,shared,shared,shared);
   var originalA:String=JSON.stringify(a),originalB:String=JSON.stringify(b),matches:Boolean=true;
   for(var i:int=0;i<=20;i++)matches=matches && compare(Type,a,b,i/20);
   actual=Type.frame(a,b,.5);
   check(matches,"cadence index: repeated interpolation matches uncached reference for every collection");
   check(actual.projectiles[0].x==20 && actual.scene.units[0].pose.x==40 && actual.scene.objects[0].pose.x==40 && actual.scene.effects[0].pose.x==40,
    "cadence index: one shared target array keeps independent id and key indexes");
   check(JSON.stringify(a)==originalA && JSON.stringify(b)==originalB,"cadence index: repeated interpolation leaves both source frames immutable");

   var duplicates:Array=[record(7,3,40),record(7,3,80)];
   var duplicateFrame:Object=frame(duplicates,duplicates,duplicates,duplicates);
   actual=Type.frame(a,duplicateFrame,.5);
   check(compare(Type,a,duplicateFrame,.5) && actual.projectiles[0].x==40 && actual.scene.units[0].pose.x==40,
    "cadence index: duplicate identities retain the original last-record-wins order");
   var reversed:Array=[duplicates[1],duplicates[0]],reversedFrame:Object=frame(reversed,reversed,reversed,reversed);
   actual=Type.frame(a,reversedFrame,.5);
   check(compare(Type,a,reversedFrame,.5) && actual.projectiles[0].x==20 && actual.scene.units[0].pose.x==20,
    "cadence index: a different array order has its own index");

   var changed:Array=[record(7,3,120)],next:Object=frame(changed,changed,changed,changed);
   actual=Type.frame(a,next,.5);
   check(compare(Type,a,next,.5) && actual.projectiles[0].x==60 && actual.scene.units[0].pose.x==60,
    "cadence index: replacement arrays with the same entity IDs acquire new states");
   actual=Type.frame(a,b,.5);
   check(compare(Type,a,b,.5) && actual.projectiles[0].x==20 && actual.scene.units[0].pose.x==40,
    "cadence index: processing a new frame cannot alter an older cached frame");
   check(actual.projectileEvents===a.projectileEvents && actual.scene.tiles===a.scene.tiles && actual.character===a.character,
    "cadence index: discrete projectiles, terrain and character payloads retain their original references");

   var empty:Object=frame([],[],[],[]),missing:Object=frame([record(111,222,20)],[record(111,222,20)]);
   actual=Type.frame(a,missing,.5);
   check(compare(Type,a,empty,.5) && compare(Type,a,missing,.5) && actual.projectiles[0]===left[0] && actual.scene.units[0]===left[0],
    "cadence index: empty or missing keys preserve left-state fallback");
   check(Type.frame(a,null,.5)===a && Type.frame(a,b,0)===a,"cadence index: no-next and zero-fraction preserve identity");
   for each(var reason:String in ["room","pause","time-phase","time-cycle"]) {
    var boundary:Object=frame(changed,changed);
    if(reason=="room")boundary.room="another-room";
    else if(reason=="pause")boundary.pauseEpoch++;
    else if(reason=="time-phase")boundary.timeControl.phase="replay";
    else boundary.timeControl.cycle++;
    check(Type.frame(a,boundary,.5)===a && compare(Type,a,boundary,.5),"cadence index: boundary remains discrete: "+reason);
   }
   check(JSON.stringify(a)==originalA && JSON.stringify(b)==originalB,"cadence index: all cache lookups preserve historical wire data");
  }
 }
}
