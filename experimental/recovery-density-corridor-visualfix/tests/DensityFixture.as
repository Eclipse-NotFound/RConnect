package {
   import flash.display.DisplayObject;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import rconnect.game.GameBridge;
   import rconnect.game.MirrorHitUnit;
   /** External setup only. Never called from the seven measured frame windows. */
   public class DensityFixture {
      public static const X:Number=161.8,Y:Number=960;
      public static function nativeEnemy(u:Object):Boolean {
         // Fraction alone also selects third-party scene/lamp collision proxies.
         return u is Unit && !(u is MirrorHitUnit)
            && getQualifiedClassName(u).indexOf("fe.unit::")==0
            && !Boolean(GameBridge.probe(u,"player")) && !Boolean(GameBridge.probe(u,"npc"))
            && Number(GameBridge.probe(u,"fraction"))>0 && Number(GameBridge.probe(u,"fraction"))<100;
      }
      public static function fields(value:Object,names:Array):Object {
         var result:Object={};for each(var key:String in names) {
            var item:*=GameBridge.probe(value,key);
            if(item===undefined)result[key]="<undefined>";
            else if(item===null || item is String || item is Boolean || item is Number)
               result[key]=(item is Number && !isFinite(item))?String(item):item;
            else if(item is XML || item is XMLList)result[key]=String(item);
            else result[key]={cls:getQualifiedClassName(item),id:String(GameBridge.probe(item,"id")),
               x:String(GameBridge.probe(item,"X")),y:String(GameBridge.probe(item,"Y"))};
         }return result;
      }
      public static function actor(u:Object):Object {
         var out:Object=fields(u,["id","tr","X","Y","scX","scY","hp","maxhp","fraction","storona","sost","disabled","in_chain"]);
         out.cls=getQualifiedClassName(u);
         out.weapon=u.currentWeapon==null?null:fields(u.currentWeapon,
            ["id","variant","damage","destroy","damageExpl","precision","deviation","critCh","speed","hold"]);
         return out;
      }
      public static function place(mod:Object):void {
         var g:Object=mod.game.gg,c:Object=mod.game.world.cam,ctr:Object=mod.game.world.ctr;
         g.setPos(X,Y);g.dx=g.dy=0;g.storona=1;g.setVisPos();g.invulner=true;
         ctr.keyLeft=ctr.keyRight=ctr.keyJump=ctr.keyLook=ctr.keyZoom=false;
         c.camRun=false;c.showOn=false;c.showX=-1;c.otryv=0;c.celX=mod.stage.stageWidth/2;c.celY=mod.stage.stageHeight/2;
         c.setLoc(mod.game.loc);c.setZoom(2);c.ovy=int(Y*c.scaleV);c.calc(g);
      }
      public static function camera(mod:Object):Object {
         return {camera:fields(mod.game.world.cam,["X","Y","vx","vy","scaleV","isZoom","camRun","otryv","showOn"]),
            visual:fields(mod.game.world.visual,["x","y","scaleX","scaleY"])};
      }
      public static function player(mod:Object):Object {
         return fields(mod.game.gg,["X","Y","dx","dy","storona","sost","disabled"]);
      }
      public static function atPoint(g:Object):Boolean {
         return Math.abs(Number(g.X)-X)<.001 && Math.abs(Number(g.Y)-Y)<.001
            && Number(g.dx)==0 && Number(g.dy)==0 && Number(g.storona)==1 && int(g.sost)==1;
      }
      public static function removeExtras(mod:Object,keep:Array):Array {
         var removed:Array=[],units:Array=mod.game.loc.units;
         for(var i:int=units.length-1;i>=0;i--) {
            var u:Object=units[i];if(!nativeEnemy(u) || keep.indexOf(u)>=0)continue;
            removed.push(actor(u));mod.game.loc.remObj(u);units.splice(i,1);
         }
         // No death(), damage(), drops, kill credit, or forged network packets.
         return removed;
      }
      public static function canonical(value:*):String {
         if(value is Array){var arr:Array=[];for each(var item:* in value)arr.push(canonical(item));return "["+arr.join(",")+"]";}
         if(value!==null && typeof value=="object") {
            var keys:Array=[],pairs:Array=[];for(var k:String in value)keys.push(k);keys.sort();
            for each(k in keys)pairs.push(JSON.stringify(k)+":"+canonical(value[k]));return "{"+pairs.join(",")+"}";
         }
         return JSON.stringify(value);
      }
      public static function sorted(rows:Array):Array {
         rows.sort(function(a:*,b:*):Number {var x:String=canonical(a),y:String=canonical(b);return x<y?-1:(x>y?1:0);});return rows;
      }
      public static function hash(value:*):String {
         // Adler32 over UTF-16 code units; offline audit also records SHA256.
         var text:String=canonical(value),a:uint=1,b:uint=0;
         for(var i:int=0;i<text.length;i++){a=(a+text.charCodeAt(i))%65521;b=(b+a)%65521;}
         return uint((b<<16)|a).toString(16);
      }
      public static function snapshot(mod:Object,keep:Array):Object {
         var loc:Object=mod.game.loc,cells:Array=[],actors:Array=[],others:Array=[],art:Array=[],seen:Array=[];
         for(var y:int=0;y<loc.spaceY;y++)for(var x:int=0;x<loc.spaceX;x++)
            cells.push(fields(loc.space[x][y],["front","back","phis","zForm","fRear","diagon","stair","shelf","door","fake","vid","vid2"]));
         for each(var u:Object in loc.units) {
            if(keep.indexOf(u)>=0)actors.push(actor(u));
            else if(!(u is MirrorHitUnit) && u!==mod.game.gg)others.push({list:"units",value:objectRow(u)});
         }
         var obj:Object=loc.firstObj,n:int=0;
         while(obj!=null && n++<10000){
            if(keep.indexOf(obj)<0 && obj!==mod.game.gg && !(obj is MirrorHitUnit))
               others.push({list:"chain",value:objectRow(obj)});
            if(seen.indexOf(obj)>=0)throw new Error("density object chain cycle");seen.push(obj);obj=obj.nobj;
         }
         if(obj!=null)throw new Error("density object chain exceeds 10000");
         for each(var bo:Object in loc.backobjs)art.push(objectRow(bo));
         return {location:fields(loc,["id","spaceX","spaceY","darkness","lightOn","backwall","transpFon","homeStable","black"]),
            color:fields(loc.cTransform,["redMultiplier","greenMultiplier","blueMultiplier","alphaMultiplier",
               "redOffset","greenOffset","blueOffset","alphaOffset"]),tileHash:hash(cells),tileHashAlgorithm:"adler32-utf16-canonical-v1",
            actors:sorted(actors),otherObjects:sorted(others),backobjs:sorted(art),player:player(mod),camera:camera(mod),
            viewport:[mod.stage.stageWidth,mod.stage.stageHeight,mod.stage.frameRate,mod.stage.quality]};
      }
      private static function objectRow(u:Object):Object {
         var row:Object=fields(u,["id","X","Y","scX","scY","frame","sloy","alpha","er","fraction","npc","player","in_chain"]);
         row.cls=getQualifiedClassName(u);return row;
      }
   }
}
