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
      private static const OMIT:Object={visible:1,alpha:1,visFrame:1,visDamDY:1,n:1,in_chain:1};
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
            // Names come only from describeType's public variable list, not
            // arbitrary packet keys or getters. These declared slots cannot
            // be missing; avoid millions of optional-property probes per map.
            var value:*=o[n];
            if(value is Number) {if(isFinite(Number(value)))s[n]=value;}
            else if(value is String || value is Boolean) s[n]=value;
            // Native XML attributes remain XMLList entries until arithmetic is
            // performed. JSON otherwise serializes these resistances as "XMLList".
            else if(value is Array && (n=="vulner" || n=="begvulner")) s[n]=numbers(value);
            else if(value is Array && simple(value)) s[n]=JSON.parse(JSON.stringify(value));
         }
         return s;
      }
      public static function numbers(values:Array):Array
      {
         var out:Array=[];
         for each(var value:* in values)out.push(Number(value));
         return out;
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
         // Native linked-list membership belongs to addObj/remObj. In
         // particular a dead source's false cannot overwrite a new true link.
         for(var n:String in s)if(!OMIT[n])try {o[n]=s[n] is Array?JSON.parse(JSON.stringify(s[n])):s[n];}catch(e:*){}
      }
      public static function unit(u:Object):Object
      {/*RCRESTORE:73:BEGIN*/
RestoreCostTrace.begin("checkpoint.unitRuntime");try {
/*RCRESTORE:73:END*/
         var s:Object={p:scalars(u),internal:RConnectUnitAccess.capture(u as Unit),guns:[]};
         var children:Array=GameBridge.probe(u,"childObjs") as Array;
         if(children!=null)for(var i:int=0;i<children.length;i++)
         {
            var w:Object=children[i];
            if(GameBridge.probe(w,"kol_shoot")==null)continue;
            s.guns.push({slot:i,main:w===GameBridge.probe(u,"currentWeapon"),p:scalars(w)});
         }
         return s;
      /*RCRESTORE:74:BEGIN*/
} finally {RestoreCostTrace.end("checkpoint.unitRuntime");}
return null;
/*RCRESTORE:74:END*/}
      public static function restoreUnit(u:Object,s:Object,main:Object):void
      {/*RCRESTORE:75:BEGIN*/
RestoreCostTrace.begin("unit.restoreRuntime");try {
/*RCRESTORE:75:END*/
         if(s==null)return;
/*RCRESTORE:77:BEGIN*/
RestoreCostTrace.begin("unit.restoreScalars");try {
/*RCRESTORE:77:END*/         restore(u,s.p);/*RCRESTORE:78:BEGIN*/
} finally {RestoreCostTrace.end("unit.restoreScalars");}

/*RCRESTORE:78:END*/
/*RCRESTORE:79:BEGIN*/
RestoreCostTrace.begin("unit.restoreInternal");try {
/*RCRESTORE:79:END*/         RConnectUnitAccess.restore(u as Unit,s.internal);/*RCRESTORE:80:BEGIN*/
} finally {RestoreCostTrace.end("unit.restoreInternal");}

/*RCRESTORE:80:END*/
         var factory:Object=main.loaderInfo.applicationDomain.getDefinition("fe.weapon.Weapon");
         var children:Array=u.childObjs==null?[]:u.childObjs;
         for each(var gun:Object in s.guns)
         {
            var w:Object=children[int(gun.slot)];/*RCRESTORE:85:BEGIN*/
RestoreCostTrace.count("gun.visited");
/*RCRESTORE:85:END*/
            if(w==null || w.id!=gun.p.id || GameBridge.probe(w,"variant")!=gun.p.variant)
            {
               if(w!=null && GameBridge.probe(w,"remVisual") is Function)w.remVisual();
/*RCRESTORE:81:BEGIN*/
RestoreCostTrace.begin("gun.constructor");try {
/*RCRESTORE:81:END*/               w=factory.create(u,String(gun.p.id),int(gun.p.variant));/*RCRESTORE:82:BEGIN*/
} finally {RestoreCostTrace.end("gun.constructor");}

/*RCRESTORE:82:END*/
               if(w==null)throw new Error("Cannot restore weapon "+gun.p.id);
               children[int(gun.slot)]=w;/*RCRESTORE:86:BEGIN*/
RestoreCostTrace.count("gun.created");
/*RCRESTORE:86:END*/
            }
            /*RCRESTORE:83:BEGIN*/
RestoreCostTrace.begin("gun.restoreScalars");try {
/*RCRESTORE:83:END*/restore(w,gun.p);/*RCRESTORE:84:BEGIN*/
} finally {RestoreCostTrace.end("gun.restoreScalars");}

/*RCRESTORE:84:END*/if(gun.main)u.currentWeapon=w;
         }
         u.childObjs=children;u.setVisPos();
         if(int(u.sost)>=4){if(u.loc!=null)u.loc.remObj(u);u.remVisual();}
      /*RCRESTORE:76:BEGIN*/
} finally {RestoreCostTrace.end("unit.restoreRuntime");}
/*RCRESTORE:76:END*/}
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
