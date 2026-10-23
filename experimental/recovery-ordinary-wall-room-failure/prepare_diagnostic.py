"""Prepare only: first-failure evidence overlay for exact C6A3 source. No compiler/AIR."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-ordinary-wall-sv-production-01/src'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def replace(text, old, new):
    if text.count(old) != 1:
        raise RuntimeError('Expected one exact source match: ' + old[:90])
    return text.replace(old, new)

def main():
    product = BASE.parent / 'RConnectMod.swf'
    if sha(product) != 'c6a3b1136bde63c32d23c4e555dfc240f3a573384d19c4fe9636a4138193496d':
        raise RuntimeError('Wrong frozen product')
    records, patches = {}, []
    for name in ('WallImpactVisuals', 'WallSurfaceBridge'):
        rel = Path('rconnect/game') / (name + '.as')
        source = BASE / rel
        original = source.read_text(encoding='utf-8')
        text = original
        if name == 'WallImpactVisuals':
            text = replace(text, '      private var bitmapDiagnostics:int=0;', '''      private var bitmapDiagnostics:int=0;
      // Isolated diagnostic only: no fields enter room checkpoints or wire cells.
      private var firstOrdinaryFailure:Object=null;
      private var failedPreparations:Dictionary=new Dictionary(true);
      private static function diagnosticBounds(value:Object):Object
      {
         var r:Rectangle=value as Rectangle;
         return r==null?null:{x:r.x,y:r.y,width:r.width,height:r.height};
      }
      private function diagnosticEvent(event:Object):Object
      {
         var t:Object=get(event,"tile"),g:Object=get(event,"grafon"),l:Object=get(event,"loc");
         return {kind:get(event,"kind"),valid:get(event,"valid"),error:String(get(event,"error")).substr(0,256),
            bounds:diagnosticBounds(get(event,"bounds")),ordinaryPhysical:get(event,"ordinaryPhysical"),
            oldFront:get(event,"oldFront"),oldVid:get(event,"oldVid"),oldVid2:get(event,"oldVid2"),oldMaterial:get(event,"oldMaterial"),
            room:{x:get(l,"landX"),y:get(l,"landY"),z:get(l,"landZ"),active:get(l,"active"),width:get(l,"spaceX"),height:get(l,"spaceY")},
            grafonRoom:g!=null && get(g,"loc")===l,bitmapCurrent:g!=null && get(g,"frontBmp")===get(event,"bitmap"),
            tile:{x:get(t,"X"),y:get(t,"Y"),front:get(t,"front"),vid:get(t,"vid"),vid2:get(t,"vid2"),mat:get(t,"mat"),phis:get(t,"phis")}};
      }
      private function diagnoseOrdinaryFailure(reason:String,event:Object,prepared:Object=null):void
      {
         if(firstOrdinaryFailure!=null)return;
         // Diagnostic formatting must not change native failure propagation.
         firstOrdinaryFailure={reason:reason};
         try {
            var l:Object=get(event,"loc"),s:Object=l==null?null:state(l);
            firstOrdinaryFailure.event=diagnosticEvent(event);
            firstOrdinaryFailure.authority=get(s,"authority");
            firstOrdinaryFailure.prepared=prepared==null?null:{valid:get(prepared,"valid"),bounds:diagnosticBounds(get(prepared,"bounds")),
               locMatches:get(prepared,"loc")===l,stateMatches:get(prepared,"state")===s,tileMatches:get(prepared,"tile")===get(event,"tile"),
               origin:failedPreparations[prepared]};
            Log.d("RConnectWall FIRST FAILURE "+JSON.stringify(firstOrdinaryFailure));
         }catch(diagnosticError:*) {}
      }
      private function ordinaryFailureText(s:Object):String
      {
         var reason:String=firstOrdinaryFailure==null?"unrecorded":String(firstOrdinaryFailure.reason);
         return " [native="+(s.nativeFailure===true)+",raster="+(s.rasterFailure===true)+",bridge="+surfaces.ordinaryFailed+",first="+reason+",observer="+surfaces.ordinaryFailureText+"]";
      }''')
            text = replace(text, 'throw new Error("Unqualified native wall checkpoint");', 'throw new Error("Unqualified native wall checkpoint"+ordinaryFailureText(s));')
            text = replace(text, 'if(!success){s.rasterFailure=true;return false;}', 'if(!success){s.rasterFailure=true;diagnoseOrdinaryFailure("nativeRaster-false",{kind:"nativeRaster",loc:loc,grafon:get(loc,"grafon"),bitmap:b});return false;}')
            text = replace(text, 'if(kind=="raster-failed"){s.rasterFailure=true;return null;}', 'if(kind=="raster-failed"){s.rasterFailure=true;diagnoseOrdinaryFailure("raster-failed",event);return null;}')
            text = replace(text, 'if(kind=="ink-failed" || kind=="structure-failed"){s.nativeFailure=true;return null;}', 'if(kind=="ink-failed" || kind=="structure-failed"){s.nativeFailure=true;diagnoseOrdinaryFailure(kind,event);return null;}')
            text = replace(text, 'if(kind=="structure-prepare")return {loc:loc,state:s,tile:event.tile,bounds:r==null?null:r.clone(),valid:event.valid!==false && r!=null};', '''if(kind=="structure-prepare") {
            var diagnosticPrepared:Object={loc:loc,state:s,tile:event.tile,bounds:r==null?null:r.clone(),valid:event.valid!==false && r!=null};
            if(diagnosticPrepared.valid!==true)try {failedPreparations[diagnosticPrepared]=diagnosticEvent(event);}catch(diagnosticPrepareError:*) {}
            return diagnosticPrepared;
         }''')
            text = replace(text, 'if(!valid && s.authority!==false)s.nativeFailure=true;', 'if(!valid && s.authority!==false){s.nativeFailure=true;diagnoseOrdinaryFailure("structure-before-invalid",event,prepared);}')
            text = replace(text, 'if(event.valid===false || r==null || event.token==null || event.token.state!==s)s.nativeFailure=true;', 'if(event.valid===false || r==null || event.token==null || event.token.state!==s){s.nativeFailure=true;diagnoseOrdinaryFailure("structure-pending-invalid",event,event.token);}')
            text = replace(text, 'if(event.valid===false){s.nativeFailure=true;return null;}', 'if(event.valid===false){s.nativeFailure=true;diagnoseOrdinaryFailure("ink-before-invalid",event);return null;}')
        else:
            text = replace(text, '      private var ordinaryFault:Boolean=false;', '''      private var ordinaryFault:Boolean=false;
      private var firstOrdinaryFault:String="none";
      public function get ordinaryFailureText():String {return firstOrdinaryFault;}''')
            text = replace(text, 'catch(error:*) {ordinaryFault=true;throw error;}', '''catch(error:*) {
            ordinaryFault=true;
            if(firstOrdinaryFault=="none")try {
               firstOrdinaryFault=String(event==null?"null":event.kind)+":"+String(error).substr(0,256);
               rconnect.core.Log.d("RConnectWall FIRST OBSERVER FAILURE "+firstOrdinaryFault);
            }catch(diagnosticFaultError:*) {}
            throw error;
         }''')
        target = HERE / 'src' / rel
        if target.exists():
            raise RuntimeError('Refusing to overwrite diagnostic source ' + str(target))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8', newline='\n')
        records[str(rel).replace('\\','/')] = {'source':str(source),'source_sha256':sha(source),'overlay_sha256':sha(target)}
        patches.extend(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile='frozen/'+rel.as_posix(), tofile='diagnostic/'+rel.as_posix()))
    (HERE / 'diagnostic.patch').write_text(''.join(patches), encoding='utf-8', newline='\n')
    (HERE / 'diagnostic-inputs.json').write_text(json.dumps({'kind':'first-failure-only-overlay','product_sha256':sha(product),'files':records,'compiled':False,'runtime_validated':False}, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
    print(json.dumps(records, ensure_ascii=False))

if __name__ == '__main__':
    main()
