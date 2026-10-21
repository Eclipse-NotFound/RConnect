"""Insertion-only RoomTerrainView reasons against exact recovery11; no process."""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / 'build/m52/recovery-11'
BASE_SHA = 'cd721f0e56679302747ab2c9e687e20bd877a1ee8f520d6d589c7c43fa64ebb5'
REL = 'rconnect/game/RoomTerrainView.as'
MARK = re.compile(r'/\*RCVIEWREASON:(\d+):BEGIN\*/.*?/\*RCVIEWREASON:\1:END\*/', re.S)


def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))


def stripped(text):
    result = MARK.sub('', text)
    assert 'RCVIEWREASON:' not in result
    return result


def transformed(original):
    sequence = 0
    def block(code):
        nonlocal sequence
        sequence += 1
        return f'/*RCVIEWREASON:{sequence}:BEGIN*/{code}/*RCVIEWREASON:{sequence}:END*/'
    def once(text, old, new):
        assert text.count(old) == 1, old
        return text.replace(old, new)
    text = original
    text = once(text, '   import fe.loc.Tile;', '   import fe.loc.Tile;'+
        block('\n   import rconnect.core.Log;\n   import flash.utils.getTimer;'))
    helper = '''
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
'''
    text = once(text, 'public class RoomTerrainView {', 'public class RoomTerrainView {'+block(helper))
    text = once(text, 'same(a:Array,b:Array)', 'same(a:Array,b:Array'+block(',owner:RoomTerrainView,scope:String,item:int=-1,x:int=-1,y:int=-1')+')')
    text = once(text, 'if(a.length!=b.length)return false;', 'if(a.length!=b.length)'+
        block('{owner.reason("failure",scope,"length",a.length,b.length,item,x,y);')+'return false;'+block('}'))
    text = once(text, 'if(a[i]!==b[i])return false;', 'if(a[i]!==b[i])'+
        block('{owner.reason("failure",scope,reasonField(scope,i),a[i],b[i],item,x,y);')+'return false;'+block('}'))
    for expression, args in (
        ('same(style,fields(loc,STYLE).concat(colors(loc)))', ',this,"style"'),
        ('same(backdrops[i][1],fields(b,BACKDROP))', ',this,"backdrop",i'),
        ('same(rows[i++],tileInputs(tile))', ',this,"tile",i-1,x,y')):
        text = once(text, expression, expression[:-1]+block(args)+')')
    # These insertions only run after the original guard has become truthy.
    # AND has higher precedence than the surrounding original OR chain.
    guards = [
        ('renderer==null','"identity","renderer-present",true,false'),
        ('renderer.loc!==loc','"identity","renderer.loc-is-input",true,false'),
        ('width<1','"bounds","width-min",1,width'),
        ('height<1','"bounds","height-min",1,height'),
        ('width>512','"bounds","width-max",512,width'),
        ('height>256','"bounds","height-max",256,height'),
        ('!valid','"identity","valid-capture",true,false'),
        ('loc!==room','"identity","input-is-captured-room",true,false'),
        ('loc.grafon!==renderer','"identity","room.grafon-is-captured-renderer",true,false'),
        ('renderer.loc!==room','"identity","renderer.loc-is-captured-room",true,false'),
        ('i>=backdrops.length','"backdrop","extra-item",backdrops.length,i+1,i'),
        ('backdrops[i][0]!==b','"backdrop","item-identity",true,false,i'),
        ('i!=backdrops.length','"backdrop","count",backdrops.length,i')]
    for expression, args in guards:
        # !valid occurs only in unchanged, not in the helper definitions.
        matches=list(re.finditer(r'(?<![\w.])'+re.escape(expression)+r'(?!\w)',text))
        assert len(matches)==1,expression
        match=matches[0]
        text=text[:match.end()]+block(' && reasonTrue('+args+')')+text[match.end():]
    for field in ('isRebuild','isRecalc'):
        expression = 'loc.'+field
        assert text.count(expression) == 2
        text = text.replace(expression, expression+block(' && reasonTrue("flags","'+field+'")'))
    for field, expected in (('spaceX','width'),('spaceY','height')):
        old = 'loc.'+field+'!='+expected
        # Retain a failed getter's value without evaluating the getter twice.
        new = block('(reasonValue=')+'loc.'+field+block(')')+'!='+expected+block(
            ' && reasonTrue("bounds","'+field+'",'+expected+',reasonValue)')
        text = once(text, old, new)
    assert text.count('tile==null') == 2
    text = text.replace('tile==null', 'tile==null'+block(' && reasonTrue("tile","native-type","fe.loc::Tile","null-or-nonnative",-1,x,y)'))
    text = once(text, '} catch(e:*) {valid=false;}', '} catch(e:*) {valid=false;'+
        block('reason("failure","exception","construct",null,e);')+'}')
    text = once(text, 'public function unchanged(loc:Object):Boolean {', 'public function unchanged(loc:Object):Boolean {'+
        block('\n         reasonStage="unchanged";reasonWritten=constructorInvalid;'))
    text = once(text, '            return true;\n         } catch(e:*) {return false;}',
        '            '+block('reason("success","unchanged","all-inputs",true,true);')+'return true;\n         } catch(e:*) {'+
        block('reason("failure","exception","unchanged",null,e);')+'return false;}')
    assert stripped(text) == original
    return text


def main():
    assert sha((BASE/'RConnectMod.swf').read_bytes()) == BASE_SHA
    original = (BASE/'src'/REL).read_bytes()
    candidate = transformed(original.decode('utf-8')).encode('utf-8')
    out = HERE/'src'/REL
    assert not out.exists(), 'Do not regenerate a delivered overlay'
    out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(candidate)
    (HERE/'diagnostic.patch').write_text(''.join(difflib.unified_diff(original.decode().splitlines(True),
        candidate.decode().splitlines(True),fromfile='recovery-11/'+REL,tofile='recovery-view-reason/'+REL)),encoding='utf-8')
    manifest=dict(kind='view-reason-proposal',base=str(BASE.relative_to(ROOT)),base_sha256=BASE_SHA,
        base_manifest_sha256=sha((BASE/'prepared.json').read_bytes()),source={REL:sha(original)},overlay={REL:sha(candidate)},
        generator_sha256=sha(Path(__file__).read_bytes()),stripped_equal=True,
        diagnostic_only=True,compiled=False,air_started=False,gameplay_qualified=False,performance_qualified=False)
    (HERE/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(generated=True,stripped_equal=True,production_overlays=1,air_started=False)))


if __name__=='__main__':main()
