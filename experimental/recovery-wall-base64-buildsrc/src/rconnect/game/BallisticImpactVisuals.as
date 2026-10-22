package rconnect.game {
   import flash.display.MovieClip;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getDefinitionByName;
   import flash.utils.Dictionary;

   /** Bullet.popadalo's native hard-surface impact, separate from flight expiry.
    * Only emit cosmetic sparks; the source already owns damage and wall marks. */
   public class BallisticImpactVisuals {
      private static var claimed:Dictionary=new Dictionary(true);
      private static var checked:Dictionary=new Dictionary(true);
      private static var scanLoc:Object,scanStamp:int=-1,fresh:Object={};
      public static function reset():void {claimed=new Dictionary(true);checked=new Dictionary(true);scanLoc=null;scanStamp=-1;fresh={};}
      private static function get(o:Object,k:String):* {return GameBridge.probe(o,k);}
      private static function scan(loc:Object,stamp:int,world:Object):void {
         if(scanLoc===loc && scanStamp==stamp)return;
         scanLoc=loc;scanStamp=stamp;fresh={};
         var names:Array=["sprBlood","sprGBlood","sprPBlood","sprIskr"];
         var kinds:Array=["blood","gblood","pblood","iskr_bul"],atlases:Array=[];
         for each(var name:String in names)atlases.push(world.grafon.getSpriteList(name,1));
         for(var p:Object=get(loc,"firstObj"),guard:int=0;p!=null && guard++<10000;p=get(p,"nobj")) {
            if(getQualifiedClassName(p)!="fe.graph::Part" || claimed[p] || Number(p.mliv)-Number(p.liv)>1)continue;
            var index:int=atlases.indexOf(get(p,"blitData"));if(index<0)continue;
            // sprIskr is also used by fire and explosions. Bullet sparks have
            // the native 15..19-tick lifetime; other recipes start at 20.
            if(index==3 && (Number(p.mliv)<15 || Number(p.mliv)>=20))continue;
            var cell:String=int(Math.floor(Number(p.X)/32))+":"+int(Math.floor(Number(p.Y)/32));
            if(fresh[cell]==null)fresh[cell]=[];
            fresh[cell].push({part:p,kind:kinds[index]});
         }
      }
      public static function capture(b:Object,stamp:int):Object {
         if(b==null || GameBridge.probe(b,"babah")!==true || Number(GameBridge.probe(b,"explRadius"))>0
            || getQualifiedClassName(b)=="fe.weapon::PhisBullet")return null;
         // popadalo emits synchronously. Once its first ended frame has been
         // inspected, a later neighbour's particles cannot belong to this shot.
         // This also avoids rescanning every expired/no-spark shot each frame.
         if(checked[b])return null;
         checked[b]=true;
         var speed:Number=Number(GameBridge.probe(b,"vel"));
         if(!isFinite(speed)||speed<=0)return null;
         var world:Object=getDefinitionByName("fe.World").w;
         var hit:Array=get(b,"parr") as Array,allowed:Object={};
         if(get(b,"tilehit")!==true && (hit==null || hit.length==0))return null;
         if(hit!=null)for each(var unit:Object in hit) {
            var blood:int=int(get(unit,"blood"));
            if(blood>=1 && blood<=3)allowed[["","blood","gblood","pblood"][blood]]=true;
         }
         var decal:int=int(get(b,"tipDecal")),clip:MovieClip=get(b,"vis") as MovieClip;
         if(decal>=1 && decal<=6 && clip!=null && clip.currentFrame>=2)allowed.iskr_bul=true;
         scan(get(b,"loc"),stamp,world);
         var counts:Object={},groups:Array=[];
         var cx:int=int(Math.floor(Number(b.X)/32)),cy:int=int(Math.floor(Number(b.Y)/32));
         for(var ix:int=cx-1;ix<=cx+1;ix++)for(var iy:int=cy-1;iy<=cy+1;iy++)
         for each(var item:Object in fresh[ix+":"+iy]) {
            var p:Object=item.part;
            if(claimed[p] || allowed[item.kind]!==true || Math.abs(Number(p.X)-Number(b.X))>20
               || Math.abs(Number(p.Y)-Number(b.Y))>25)continue;
            claimed[p]=true;counts[item.kind]=int(counts[item.kind])+1;
         }
         for(var kind:String in counts) {
            var force:Number=kind=="iskr_bul"?-10:5;
            // Several shotgun pellets can hit the same point in one frame.
            // Do not truncate their combined native particles at the wire cap.
            for(var remaining:int=int(counts[kind]);remaining>0;remaining-=50)
               groups.push({kind:kind,count:Math.min(50,remaining),dx:Number(b.dx)/speed*force,dy:Number(b.dy)/speed*force});
         }
         // Require actual newly emitted native particles. A shield, dodge,
         // lifetime end, or animated magic clip cannot invent a blood/spark hit.
         return groups.length==0?null:{x:Number(b.X),y:Number(b.Y),groups:groups};
      }
      public static function play(main:Object,loc:Object,s:Object):void {
         if(main==null||loc==null||s==null||GameBridge.probe(loc,"active")!==true)return;
         if(!isFinite(Number(s.x)) || !isFinite(Number(s.y)) || !(s.groups is Array))return;
         var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         var before:Object=get(loc,"lastObj");
         for each(var group:Object in s.groups) {
            var kind:String=String(group.kind);
            if(kind!="iskr_bul" && kind!="blood" && kind!="gblood" && kind!="pblood")continue;
            if(!isFinite(Number(group.dx)) || !isFinite(Number(group.dy)))continue;
            var count:int=Math.max(0,Math.min(50,int(group.count)));if(count==0)continue;
            emitter.emit(kind,loc,Number(s.x),Number(s.y),{dx:Number(group.dx),dy:Number(group.dy),kol:count});
         }
         // Cosmetic native Parts must never be mistaken for another local hit.
         for(var p:Object=before==null?get(loc,"firstObj"):get(before,"nobj");p!=null;p=get(p,"nobj"))claimed[p]=true;
      }
   }
}
