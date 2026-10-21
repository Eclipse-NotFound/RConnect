package rconnect.game {
   import fe.loc.Tile;/*RCVIEWREASON:1:BEGIN*/
   import rconnect.core.Log;
   import flash.utils.getTimer;/*RCVIEWREASON:1:END*/

   /** A synchronous checkpoint restore may change HP/vision without changing
    * the terrain picture. Compare its inputs before object reconciliation,
    * not after it has already changed doors and supporting tiles. Unsupported
    * inputs and pending native rebuilds retain the complete redraw path. */
   public class RoomTerrainView {/*RCVIEWREASON:2:BEGIN*/
      private static var reasonSequence:uint=0;
      private var reasonId:uint=++reasonSequence,reasonWritten:Boolean=false,constructorInvalid:Boolean=false;
      private var reasonStage:String="construct",reasonValue:*;
      private static const REASON_TILES:Array=["X","Y","phis","shelf","phX1","phX2","phY1","phY2","zForm",
         "diagon","stair","water","vid","vid2","front","back","zad","fRear","vRear","v2Rear","opac",
         "mat","kontur","konturRot","floor","place","fake","doorPresent"];
      private static function reasonScalar(value:*):* {
         if(value===undefined)return "<undefined>";
         if(value===null || value is Boolean)return value;
         if(value is Number)return isFinite(Number(value))?value:String(value);
         if(value is String)return String(value).substr(0,256);
         return "<"+typeof(value)+">";
      }
      private static function reasonField(scope:String,index:int):String {
         if(scope=="style")return index<STYLE.length?String(STYLE[index]):(index==STYLE.length?"cTransform":"cTransformFon");
         if(scope=="backdrop")return String(BACKDROP[index]);
         return String(REASON_TILES[index]);
      }
      private function reason(outcome:String,scope:String,field:String,expected:*=null,actual:*=null,
                              item:int=-1,x:int=-1,y:int=-1):void {
         if(reasonWritten)return;reasonWritten=true;
         if(reasonStage=="construct")constructorInvalid=true;
         // Diagnostic failures must not replace the original return/exception.
         try {
            Log.d("RConnectViewReason "+JSON.stringify({diagnosticOnly:true,performanceQualified:false,
               id:reasonId,at:getTimer(),stage:reasonStage,outcome:outcome,scope:scope,field:field,
               expected:reasonScalar(expected),actual:reasonScalar(actual),item:item,x:x,y:y,width:width,height:height}));
         }catch(reasonError:*){}
      }
      private function reasonTrue(scope:String,field:String,expected:*=false,actual:*=true,
                                  item:int=-1,x:int=-1,y:int=-1):Boolean {
         reason("failure",scope,field,expected,actual,item,x,y);return true;
      }
/*RCVIEWREASON:2:END*/
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
      private static function same(a:Array,b:Array/*RCVIEWREASON:3:BEGIN*/,owner:RoomTerrainView,scope:String,item:int=-1,x:int=-1,y:int=-1/*RCVIEWREASON:3:END*/):Boolean {
         if(a.length!=b.length)/*RCVIEWREASON:4:BEGIN*/{owner.reason("failure",scope,"length",a.length,b.length,item,x,y);/*RCVIEWREASON:4:END*/return false;/*RCVIEWREASON:5:BEGIN*/}/*RCVIEWREASON:5:END*/
         for(var i:int=0;i<a.length;i++)if(a[i]!==b[i])/*RCVIEWREASON:6:BEGIN*/{owner.reason("failure",scope,reasonField(scope,i),a[i],b[i],item,x,y);/*RCVIEWREASON:6:END*/return false;/*RCVIEWREASON:7:BEGIN*/}/*RCVIEWREASON:7:END*/
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
            if(renderer==null/*RCVIEWREASON:11:BEGIN*/ && reasonTrue("identity","renderer-present",true,false)/*RCVIEWREASON:11:END*/ || renderer.loc!==loc/*RCVIEWREASON:12:BEGIN*/ && reasonTrue("identity","renderer.loc-is-input",true,false)/*RCVIEWREASON:12:END*/ || loc.isRebuild/*RCVIEWREASON:24:BEGIN*/ && reasonTrue("flags","isRebuild")/*RCVIEWREASON:24:END*/ || loc.isRecalc/*RCVIEWREASON:25:BEGIN*/ && reasonTrue("flags","isRecalc")/*RCVIEWREASON:25:END*/
               || width<1/*RCVIEWREASON:13:BEGIN*/ && reasonTrue("bounds","width-min",1,width)/*RCVIEWREASON:13:END*/ || height<1/*RCVIEWREASON:14:BEGIN*/ && reasonTrue("bounds","height-min",1,height)/*RCVIEWREASON:14:END*/ || width>512/*RCVIEWREASON:15:BEGIN*/ && reasonTrue("bounds","width-max",512,width)/*RCVIEWREASON:15:END*/ || height>256/*RCVIEWREASON:16:BEGIN*/ && reasonTrue("bounds","height-max",256,height)/*RCVIEWREASON:16:END*/)return;
            style=fields(loc,STYLE).concat(colors(loc));
            for each(var b:Object in loc.backobjs)
               backdrops.push([b,fields(b,BACKDROP)]);
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;if(tile==null/*RCVIEWREASON:32:BEGIN*/ && reasonTrue("tile","native-type","fe.loc::Tile","null-or-nonnative",-1,x,y)/*RCVIEWREASON:32:END*/)return;
               rows.push(tileInputs(tile));
               contours.push(fields(tile,CONTOURS));
            }
            valid=true;
         } catch(e:*) {valid=false;/*RCVIEWREASON:33:BEGIN*/reason("failure","exception","construct",null,e);/*RCVIEWREASON:33:END*/}
      }
      public function unchanged(loc:Object):Boolean {/*RCVIEWREASON:34:BEGIN*/
         reasonStage="unchanged";reasonWritten=constructorInvalid;/*RCVIEWREASON:34:END*/
         if(!valid/*RCVIEWREASON:17:BEGIN*/ && reasonTrue("identity","valid-capture",true,false)/*RCVIEWREASON:17:END*/ || loc!==room/*RCVIEWREASON:18:BEGIN*/ && reasonTrue("identity","input-is-captured-room",true,false)/*RCVIEWREASON:18:END*/ || loc.grafon!==renderer/*RCVIEWREASON:19:BEGIN*/ && reasonTrue("identity","room.grafon-is-captured-renderer",true,false)/*RCVIEWREASON:19:END*/ || renderer.loc!==room/*RCVIEWREASON:20:BEGIN*/ && reasonTrue("identity","renderer.loc-is-captured-room",true,false)/*RCVIEWREASON:20:END*/
            || /*RCVIEWREASON:26:BEGIN*/(reasonValue=/*RCVIEWREASON:26:END*/loc.spaceX/*RCVIEWREASON:27:BEGIN*/)/*RCVIEWREASON:27:END*/!=width/*RCVIEWREASON:28:BEGIN*/ && reasonTrue("bounds","spaceX",width,reasonValue)/*RCVIEWREASON:28:END*/ || /*RCVIEWREASON:29:BEGIN*/(reasonValue=/*RCVIEWREASON:29:END*/loc.spaceY/*RCVIEWREASON:30:BEGIN*/)/*RCVIEWREASON:30:END*/!=height/*RCVIEWREASON:31:BEGIN*/ && reasonTrue("bounds","spaceY",height,reasonValue)/*RCVIEWREASON:31:END*/ || loc.isRebuild/*RCVIEWREASON:24:BEGIN*/ && reasonTrue("flags","isRebuild")/*RCVIEWREASON:24:END*/ || loc.isRecalc/*RCVIEWREASON:25:BEGIN*/ && reasonTrue("flags","isRecalc")/*RCVIEWREASON:25:END*/)return false;
         try {
            if(!same(style,fields(loc,STYLE).concat(colors(loc))/*RCVIEWREASON:8:BEGIN*/,this,"style"/*RCVIEWREASON:8:END*/))return false;
            var i:int=0;
            for each(var b:Object in loc.backobjs) {
               if(i>=backdrops.length/*RCVIEWREASON:21:BEGIN*/ && reasonTrue("backdrop","extra-item",backdrops.length,i+1,i)/*RCVIEWREASON:21:END*/ || backdrops[i][0]!==b/*RCVIEWREASON:22:BEGIN*/ && reasonTrue("backdrop","item-identity",true,false,i)/*RCVIEWREASON:22:END*/
                  || !same(backdrops[i][1],fields(b,BACKDROP)/*RCVIEWREASON:9:BEGIN*/,this,"backdrop",i/*RCVIEWREASON:9:END*/))return false;
               i++;
            }
            if(i!=backdrops.length/*RCVIEWREASON:23:BEGIN*/ && reasonTrue("backdrop","count",backdrops.length,i)/*RCVIEWREASON:23:END*/)return false;
            i=0;
            for(var x:int=0;x<width;x++)for(var y:int=0;y<height;y++) {
               var tile:Tile=loc.space[x][y] as Tile;
               if(tile==null/*RCVIEWREASON:32:BEGIN*/ && reasonTrue("tile","native-type","fe.loc::Tile","null-or-nonnative",-1,x,y)/*RCVIEWREASON:32:END*/ || !same(rows[i++],tileInputs(tile)/*RCVIEWREASON:10:BEGIN*/,this,"tile",i-1,x,y/*RCVIEWREASON:10:END*/))return false;
            }
            /*RCVIEWREASON:35:BEGIN*/reason("success","unchanged","all-inputs",true,true);/*RCVIEWREASON:35:END*/return true;
         } catch(e:*) {/*RCVIEWREASON:36:BEGIN*/reason("failure","exception","unchanged",null,e);/*RCVIEWREASON:36:END*/return false;}
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
