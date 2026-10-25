package rconnect.game {
   import fe.loc.Tile;
   // TERRAIN-REASON BEGIN imports.
   import rconnect.core.Log;
   import flash.desktop.NativeApplication;
   // TERRAIN-REASON END imports.

   /** A synchronous checkpoint restore may change HP/vision without changing
    * the terrain picture. Compare its inputs before object reconciliation,
    * not after it has already changed doors and supporting tiles. Unsupported
    * inputs and pending native rebuilds retain the complete redraw path. */
   public class RoomTerrainView {
      private var room:Object,renderer:Object;
      private var width:int,height:int;
      private var rows:Array=[];
      private var contours:Array=[];
      private var style:Array;
      private var backdrops:Array=[];
      private var valid:Boolean=false;
      private static const STYLE:Array=["backwall","backform","darkness","transpFon","tipWater",
         "gas","homeStable","black","lightOn","limX","limY","color"];
      private static const BACKDROP:Array=["X","Y","scX","scY","alpha","blend","sloy","er",
         "vis","erase","light"];
      private static const CONTOURS:Array=["kont1","kont2","kont3","kont4","pont1","pont2","pont3","pont4"];
      // TERRAIN-REASON BEGIN: diagnostic-only; remove this entire block to strip.
      private static var reasonData:Object=null;
      private static var reasonKind:String="",reasonFields:Array=null;
      private static var reasonX:int=-1,reasonY:int=-1,reasonIndex:int=-1;
      private static const REASON_TILE:Array=["X","Y","phis","shelf","phX1","phX2","phY1","phY2","zForm",
         "diagon","stair","water","vid","vid2","front","back","zad","fRear","vRear","v2Rear",
         "opac","mat","kontur","konturRot","floor","place","fake","doorPresent"];
      private static const REASON_STYLE:Array=STYLE.concat(["cTransform","cTransformFon"]);
      public static function diagnosticBegin(loc:Object,retained:Boolean,dirty:Boolean):Boolean {
         try {
            reasonData=null;
            if(loc==null)return false;
            var app:String=NativeApplication.nativeApplication.applicationID;
            if(app.indexOf("pfe-modsettings-rconnect-coop-")!=0)return false;
            reasonKind="";reasonFields=null;reasonX=-1;reasonY=-1;reasonIndex=-1;
            reasonData={schema:"terrain-reuse-first-rejection-v1",DIAGNOSTIC_ONLY:true,complete:false,performanceQualified:false,
               appId:app,captureRetained:retained,captureDirty:dirty,
               width:int(loc.spaceX),height:int(loc.spaceY),viewCreated:false,constructorValid:false,
               unchangedCalled:false,reused:false,admission:{},reuseGuardDirty:null,first:null,faultCount:0,faults:[]};
            return true;
         }catch(error:*) {diagnosticFault("begin");return reasonData!=null;}
         return false; // Unreachable fallback for ASC return analysis.
      }
      private static function diagnosticValue(value:*):* {
         if(value===undefined)return {type:"undefined"};
         if(value===null)return {type:"null",value:null};
         if(value is Boolean)return {type:"boolean",value:value};
         if(value is String)return String(value).length<=96?{type:"string",value:value}:{type:"string",prefix:String(value).substr(0,96),length:String(value).length};
         if(value is Number)return {type:typeof value,value:isFinite(Number(value))?value:String(value)};
         return {type:typeof value};
      }
      private static function diagnosticFault(where:String):void {
         try{if(reasonData!=null){reasonData.faultCount++;if(reasonData.faults.length<4)reasonData.faults.push(where);}}catch(ignored:*){}
      }
      private static function diagnosticReject(stage:String,field:String,expected:*,actual:*,x:int=-1,y:int=-1,index:int=-1):void {
         if(reasonData==null || reasonData.first!=null)return;
         try{reasonData.first={stage:stage,field:field,expected:diagnosticValue(expected),actual:diagnosticValue(actual),x:x,y:y,index:index};}
         catch(error:*){diagnosticFault("reject");}
      }
      private static function diagnosticContext(kind:String,names:Array=null,x:int=-1,y:int=-1,index:int=-1):void {
         if(reasonData==null)return;
         try{reasonKind=kind;reasonFields=names;reasonX=x;reasonY=y;reasonIndex=index;
            if(kind=="unchanged")reasonData.unchangedCalled=true;}
         catch(error:*){diagnosticFault("context");}
      }
      private static function diagnosticDifference(a:Array,b:Array,slot:int):void {
         if(reasonData==null || reasonData.first!=null)return;
         try{diagnosticReject(reasonKind,slot<0?"length":String(reasonFields[slot]),slot<0?a.length:a[slot],
            slot<0?b.length:b[slot],reasonX,reasonY,reasonIndex);}
         catch(error:*){diagnosticFault("difference");}
      }
      private function diagnosticGuard(stage:String,loc:Object):void {
         if(reasonData==null || reasonData.first!=null)return;
         // Called only after the untouched original compound guard rejected.
         // These native data fields are reread in the same order; no setters/callbacks run.
         try {
            if(stage=="constructor") {
               if(renderer==null)diagnosticReject(stage,"rendererPresent",true,false);
               else if(renderer.loc!==loc)diagnosticReject(stage,"rendererRoomIdentity",true,false);
               else if(loc.isRebuild)diagnosticReject(stage,"isRebuild",false,loc.isRebuild);
               else if(loc.isRecalc)diagnosticReject(stage,"isRecalc",false,loc.isRecalc);
               else if(width<1)diagnosticReject(stage,"widthMinimum",1,width);
               else if(height<1)diagnosticReject(stage,"heightMinimum",1,height);
               else if(width>512)diagnosticReject(stage,"widthMaximum",512,width);
               else if(height>256)diagnosticReject(stage,"heightMaximum",256,height);
               else diagnosticFault("constructor-guard-no-match");
            } else {
               if(!valid)diagnosticReject(stage,"constructorValid",true,false);
               else if(loc!==room)diagnosticReject(stage,"roomIdentity",true,false);
               else if(loc.grafon!==renderer)diagnosticReject(stage,"rendererIdentity",true,false);
               else if(renderer.loc!==room)diagnosticReject(stage,"rendererRoomIdentity",true,false);
               else if(loc.spaceX!=width)diagnosticReject(stage,"width",width,loc.spaceX);
               else if(loc.spaceY!=height)diagnosticReject(stage,"height",height,loc.spaceY);
               else if(loc.isRebuild)diagnosticReject(stage,"isRebuild",false,loc.isRebuild);
               else if(loc.isRecalc)diagnosticReject(stage,"isRecalc",false,loc.isRecalc);
               else diagnosticFault("unchanged-guard-no-match");
            }
         }catch(error:*){diagnosticFault("guard");}
      }
      private static function diagnosticValid():void {
         try{if(reasonData!=null)reasonData.constructorValid=true;}catch(error:*){diagnosticFault("valid");}
      }
      public static function diagnosticAdmission(field:String,allowed:Boolean):Boolean {
         try{if(reasonData!=null){reasonData.admission[field]=allowed;if(!allowed)diagnosticReject("admission",field,true,allowed);}}
         catch(error:*){diagnosticFault("admission");}
         return allowed;
      }
      public static function diagnosticReuseGuard(dirty:Boolean):void {
         try{if(reasonData!=null)reasonData.reuseGuardDirty=dirty;}
         catch(error:*){diagnosticFault("reuse-guard");}
      }
      public static function diagnosticCreated(created:Boolean):void {
         try{if(reasonData!=null){reasonData.viewCreated=created;if(!created)diagnosticReject("admission","viewCreated",true,false);}}
         catch(error:*){diagnosticFault("created");}
      }
      public static function diagnosticFinish(armed:Boolean,reused:Boolean,key:*):void {
         if(!armed)return;
         var result:Object=reasonData;reasonData=null;reasonFields=null;
         try {
            if(result==null)return;
            result.complete=true;result.reused=reused;result.key=key;
            Log.d("RConnectTerrainReuse DIAGNOSTIC_ONLY "+JSON.stringify(result));
         } catch(ignored:*) {} // Absent output is incomplete evidence, never a gameplay failure.
      }
      // TERRAIN-REASON END.
      // HP and vision are deliberately absent: the full checkpoint still
      // restores them, and refresh() updates the native light map separately.
      // Contours are derived from phis/back/shelf/door by tileKontur().
      private static function tileInputs(t:Object):Array {
         return [t.X,t.Y,t.phis,t.shelf,t.phX1,t.phX2,t.phY1,t.phY2,t.zForm,
            t.diagon,t.stair,t.water,t.vid,t.vid2,t.front,t.back,t.zad,
            t.fRear,t.vRear,t.v2Rear,t.opac,t.mat,t.kontur,t.konturRot,t.floor,
            t.place,t.fake,t.door!=null];
      }
      private static function fields(o:Object,names:Array):Array {
         var out:Array=[];for each(var n:String in names)out.push(o[n]);return out;
      }
      private static function same(a:Array,b:Array):Boolean {
         if(a.length!=b.length){diagnosticDifference(a,b,-1);return false;}
         for(var i:int=0;i<a.length;i++)if(a[i]!==b[i]){diagnosticDifference(a,b,i);return false;}
         return true;
      }
      private static function colors(loc:Object):Array {
         var out:Array=[];
         for each(var name:String in ["cTransform","cTransformFon"]) {
            var c:Object=loc[name];
            out.push(c==null?null:c.toString());
         }
         return out;
      }
      public function RoomTerrainView(loc:Object) {
         try {
            room=loc;renderer=loc.grafon;width=int(loc.spaceX);height=int(loc.spaceY);
            if(renderer==null || renderer.loc!==loc || loc.isRebuild || loc.isRecalc
               || width<1 || height<1 || width>512 || height>256){diagnosticGuard("constructor",loc);return;}
            style=fields(loc,STYLE).concat(colors(loc));
            for each(var b:Object in loc.backobjs)
               backdrops.push([b,fields(b,BACKDROP)]);
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;if(tile==null){diagnosticReject("constructor","tileType",true,false,x,y);return;}
               rows.push(tileInputs(tile));
               contours.push(fields(tile,CONTOURS));
            }
            valid=true;diagnosticValid();
         } catch(e:*) {valid=false;diagnosticReject("constructor","exception",null,e);}
      }
      public function unchanged(loc:Object):Boolean {
         diagnosticContext("unchanged");
         if(!valid || loc!==room || loc.grafon!==renderer || renderer.loc!==room
            || loc.spaceX!=width || loc.spaceY!=height || loc.isRebuild || loc.isRecalc){diagnosticGuard("unchanged",loc);return false;}
         try {
            diagnosticContext("style",REASON_STYLE);
            if(!same(style,fields(loc,STYLE).concat(colors(loc))))return false;
            var i:int=0;
            for each(var b:Object in loc.backobjs) {
               diagnosticContext("backdrop",BACKDROP,-1,-1,i);
               if(i>=backdrops.length || backdrops[i][0]!==b
                  || !same(backdrops[i][1],fields(b,BACKDROP))){if(i>=backdrops.length)diagnosticReject("backdrop","extraEntry",true,false,-1,-1,i);else if(backdrops[i][0]!==b)diagnosticReject("backdrop","identity",true,false,-1,-1,i);return false;}
               i++;
            }
            if(i!=backdrops.length){diagnosticReject("backdrop","count",backdrops.length,i);return false;}
            i=0;
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;
               diagnosticContext("tile",REASON_TILE,x,y);
               if(tile==null || !same(rows[i++],tileInputs(tile))){if(tile==null)diagnosticReject("tile","tileType",true,false,x,y);return false;}
            }
            return true;
         } catch(e:*) {diagnosticReject("unchanged","exception",null,e);return false;}
         return false;
      }
      /** Keep the non-raster side effects of Grafon.drawLoc. Calling through
       * native methods preserves the installed renderer's lighting behavior. */
      public function refresh(world:Object):void {
         // ContinuousScene can give regions different backwall styles. Keep
         // the contours used to draw these exact cached pixels, rather than
         // recomputing every region under the current global room style.
         var index:int=0;
         for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
            var values:Array=contours[index++],tile:Object=room.space[x][y];
            for(var slot:int=0;slot<CONTOURS.length;slot++)tile[CONTOURS[slot]]=values[slot];
         }
         renderer.lightBmp.fillRect(renderer.lightBmp.rect,0xFF000000);
         renderer.setLight();renderer.visLight.visible=room.black && world.black;
         renderer.warShadow();renderer.drawAllObjs();
         world.cam.setLoc(room);world.gui.setAll();
      }
   }
}
