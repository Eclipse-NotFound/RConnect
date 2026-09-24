package rconnect.game
{
   import flash.utils.describeType;
   import flash.utils.getQualifiedClassName;
   import fe.unit.Unit;
   import fe.unit.RConnectUnitAccess;

   /** Ownership checkpoints, not render snapshots. Only scalar/primitive-array
    * values cross the wire; world, display, target and linked-list references never do. */
   public class NativeRoomState
   {
      private static var schemas:Object={};
      private static const OMIT:Object={visible:1,alpha:1,visFrame:1,visDamDY:1,n:1};
      public static function scalars(o:Object):Object
      {
         var s:Object={}; if(o==null)return s;
         var cls:String=getQualifiedClassName(o),names:Array=schemas[cls];
         if(names==null)
         {
            names=[];
            for each(var v:XML in describeType(o).variable)
               if(!OMIT[String(v.@name)] && !v.hasOwnProperty("@uri")) names.push(String(v.@name));
            schemas[cls]=names;
         }
         for each(var n:String in names)
         {
            var value:*=GameBridge.probe(o,n);
            if(value is Number) {if(isFinite(Number(value)))s[n]=value;}
            else if(value is String || value is Boolean) s[n]=value;
            else if(value is Array && simple(value)) s[n]=JSON.parse(JSON.stringify(value));
         }
         return s;
      }
      private static function simple(a:Array,depth:int=0):Boolean
      {
         if(depth>3 || a.length>1024)return false;
         for each(var v:* in a)
            if(v!=null && !(v is String) && !(v is Boolean) && !(v is Number)
               && !(v is Array && simple(v,depth+1)))return false;
         return true;
      }
      public static function restore(o:Object,s:Object):void
      {
         if(o==null || s==null)return;
         for(var n:String in s) try {o[n]=s[n] is Array?JSON.parse(JSON.stringify(s[n])):s[n];}catch(e:*){}
      }
      public static function unit(u:Object):Object
      {
         var s:Object={p:scalars(u),internal:RConnectUnitAccess.capture(u as Unit),guns:[]};
         var children:Array=GameBridge.probe(u,"childObjs") as Array;
         if(children!=null)for(var i:int=0;i<children.length;i++)
         {
            var w:Object=children[i];
            if(GameBridge.probe(w,"kol_shoot")==null)continue;
            s.guns.push({slot:i,main:w===GameBridge.probe(u,"currentWeapon"),p:scalars(w)});
         }
         return s;
      }
      public static function restoreUnit(u:Object,s:Object,main:Object):void
      {
         if(s==null)return;
         restore(u,s.p);
         RConnectUnitAccess.restore(u as Unit,s.internal);
         var factory:Object=main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         var children:Array=u.childObjs==null?[]:u.childObjs;
         for each(var gun:Object in s.guns)
         {
            var w:Object=children[int(gun.slot)];
            if(w==null || w.id!=gun.p.id || GameBridge.probe(w,"variant")!=gun.p.variant)
            {
               if(w!=null && GameBridge.probe(w,"remVisual") is Function)w.remVisual();
               w=factory.create(u,String(gun.p.id),int(gun.p.variant));
               if(w==null)throw new Error("Cannot restore weapon "+gun.p.id);
               children[int(gun.slot)]=w;
            }
            restore(w,gun.p);if(gun.main)u.currentWeapon=w;
         }
         u.childObjs=children;u.setVisPos();
         if(int(u.sost)>=4)u.remVisual();
      }
      public static function constructorId(s:Object):String
      {
         var cid:String=String(s.id);
         // Native UnitTrap calls super() and only assigns its id for null.
         if(String(s.cls)=="fe.unit::UnitTrap")return null;
         if(String(s.cls).indexOf("UnitAlicorn")>=0)cid=String(s.tr);
         if(String(s.cls).indexOf("UnitTurret")>=0)
         {
            cid=TurretDisplay.constructorId(s);
            var t:Object=s.runtime.internal.groups.UnitTurret;
            if(t!=null && int(t.hidden)>0)cid=int(t.hidden)==1?"hidden":"hidden2";
         }
         return cid;
      }
   }
}
