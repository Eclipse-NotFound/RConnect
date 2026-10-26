package {
 import flash.system.ApplicationDomain;
 import flash.utils.ByteArray;

 /** External component checks. Native Tile + the actual product capture,
  * AMF/delta transport and death-patch predicate; no world simulation, bitmap
  * edits or direct Tile.die pretending to be a weapon hit. */
 public final class BTerrainBoundsChecks {
  public static function run(access:Object,domain:ApplicationDomain,check:Function):void {
   var Snapshot:Class=domain.getDefinition("authority.SceneSnapshot") as Class;
   var Delta:Class=domain.getDefinition("authority.FrameDelta") as Class;
   var Patch:Class=domain.getDefinition("authority.TerrainPatch") as Class;
   var Tile:Class=domain.getDefinition("fe.loc.Tile") as Class;
   var fields:Array=Snapshot["TILE"],names:Array=["phX1","phX2","phY1","phY2"],indices:Object={},complete:Boolean=true;
   for(var i:int=0;i<fields.length;i++)indices[fields[i]]=i;
   for each(var name:String in names)complete=complete && fields.indexOf(name)>=0;
   check(complete,"native physical bounds belong to the confirmed tile schema");
   if(!complete)return;

   // A private one-tile capture fixture has no native world side effects. Its
   // dedicated graphics identity has no dirty pixels or object display roots.
   var tile:Object=new Tile(0,0),room:Object={spaceX:1,spaceY:1,space:[[tile]],
    land:{act:{id:"terrain-bounds-component",fon:""},rconnectLayoutSeed:1},landX:0,landY:0,landZ:0,landProb:"",
    grafon:{visObjs:[]},units:[],objs:[],acts:[],bonuses:[],firstObj:null,cTransform:null,cTransformFon:null};
   var capture:Object=new Snapshot(access),encoder:Object=new Delta(),decoder:Object=new Delta(),tick:int=0;
   var expected:Array,state:Object,wire:Object,before:Object;
   for(var form:int=0;form<=3;form++) {
    tile.mainFrame("A");tile.setZForm(form);
    expected=[0,40,form*10,40];
    state=capture.capture(room,[],++tick);wire=transmit(encoder,decoder,state);
    check(equalBounds(state.tiles[0].v,expected,indices,names),"native quarter-height form "+form+" captured exactly");
    check(equalBounds(wire.scene.tiles[0].v,expected,indices,names),"native quarter-height form "+form+" survives actual AMF/delta transport");
   }
   // Updating only the edges must produce a tile delta, preserve fractional
   // positions and leave the previous confirmation immutable.
   before=state;
   tile.phX1=1.25;tile.phX2=38.5;tile.phY1=30.75;tile.phY2=39.5;
   expected=[1.25,38.5,30.75,39.5];state=capture.capture(room,[],++tick);wire=transmit(encoder,decoder,state);
   check(!state.full && state.tiles.length==1 && equalBounds(state.tiles[0].v,expected,indices,names),"moving only native bounds produces a precise tile delta");
   check(equalBounds(wire.scene.tiles[0].v,expected,indices,names),"fractional moving bounds survive AMF/delta transport");
   check(equalBounds(before.tiles[0].v,[0,40,30,40],indices,names),"previous half-height confirmation stays immutable");

   tile.mainFrame("A");tile.indestruct=false;tile.hp=100;tile.setZForm(0);tile.phX1=0;tile.phX2=40;tile.phY1=0;tile.phY2=40;
   state=capture.capture(room,[],++tick);
   var intact:Array=state.tiles[0].v,dead:Array=intact.concat();
   dead[indices.hp]=-1;dead[indices.phis]=0;dead[indices.front]="";dead[indices.opac]=dead[indices.vid]=dead[indices.vid2]=0;
   check(Patch["isFrontDestruction"](intact,dead,true),"ordinary wall death with unchanged bounds still permits incremental pixels");
   for each(name in names) {
    var changed:Array=dead.concat();changed[indices[name]]=Number(changed[indices[name]])+.25;
    check(!Patch["isFrontDestruction"](intact,changed,true),"wall death plus changed "+name+" requires full native geometry handling");
   }
  }
  private static function transmit(encoder:Object,decoder:Object,scene:Object):Object {
   var bytes:ByteArray=new ByteArray();bytes.writeObject(encoder.encode({session:"terrain-bounds-component",scene:scene}));bytes.position=0;
   return decoder.decode(bytes.readObject());
  }
  private static function equalBounds(values:Array,expected:Array,indices:Object,names:Array):Boolean {
   if(values==null)return false;
   for(var i:int=0;i<names.length;i++)if(Number(values[indices[names[i]]])!==Number(expected[i]))return false;
   return true;
  }
 }
}
