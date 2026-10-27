"""Local capture allocation experiment; exact field22 base, no protocol or frequency change."""
from pathlib import Path
import difflib
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'build/ab/b190-field22-source'
OUT = ROOT / 'build/ab/b190-scalar01-source'

def replace(text, old, new):
    if text.count(old) != 1:raise ValueError('Non-unique replacement: '+old[:120])
    return text.replace(old,new)

def main():
    if OUT.exists():raise FileExistsError(OUT)
    OUT.mkdir()
    for folder in ('src','stubs'):shutil.copytree(BASE/folder,OUT/folder)
    changes={}
    name='src/authority/NativeFields.as';path=OUT/name
    before=text=path.read_text(encoding='utf-8')
    text=replace(text,'private static var retained:Dictionary=new Dictionary(true),deltas:Dictionary=new Dictionary(true);',
        'private static var retained:Dictionary=new Dictionary(true),deltas:Dictionary=new Dictionary(true);\n'
        '      private static var successors:Dictionary=new Dictionary(true);')
    text=replace(text,'''            var from:Dictionary=new Dictionary(true);from[previous]=true;
            deltas[out]={from:from,updates:updates,removed:removed};''',
        '''            // A scalar capture has one immediate successor. The token
            // carries no state reference, so both weak maps remain collectible;
            // avoid allocating a weak hash table for every changed unit/frame.
            var token:Object={};successors[previous]=token;
            deltas[out]={from:token,updates:updates,removed:removed};''')
    text=replace(text,'hint!=null && hint.from[before]===true?hint:null;',
        'hint!=null && successors[before]===hint.from?hint:null;')
    path.write_text(text,encoding='utf-8');changes[name]=(before,text)
    name='src/authority/VisualPose.as';path=OUT/name
    before=text=path.read_text(encoding='utf-8')
    text=replace(text,'      private static const EMPTY_FILTERS:Array=[];',
        '''      private static const EMPTY_FILTERS:Array=[];
      private static var classNames:Dictionary=new Dictionary(true);
      private static function displayClass(display:DisplayObject):String {
         var name:String=classNames[display];
         if(name==null){name=getQualifiedClassName(display);classNames[display]=name;}return name;
      }''')
    text=replace(text,'''         var s:Object={x:display.x,y:display.y,sx:display.scaleX,sy:display.scaleY,r:display.rotation,
            m:m,a:display.alpha,v:display.visible,c:c};
         var nativeFilters:Array=display.filters;''',
        '''         var px:Number=display.x,py:Number=display.y,sx:Number=display.scaleX,sy:Number=display.scaleY,rotation:Number=display.rotation;
         var alpha:Number=display.alpha,visible:Boolean=display.visible;
         var blend:String=display.blendMode,cache:Boolean=display.cacheAsBitmap;
         var nativeFilters:Array=display.filters;
         // A Bitmap is always a leaf: it has no timeline, children, text or
         // runtime vector commands. Compare its fixed recipe before allocating
         // a fresh object and doing the generic enumerable-property walk.
         if(display is Bitmap && !includePixels && nativeFilters.length==0) {
            var bitmap:Bitmap=Bitmap(display),smooth:Boolean=bitmap.smoothing,snapping:String=bitmap.pixelSnapping;
            if(previous!=null && previous.m===m && previous.c===c && previous.x===px && previous.y===py &&
               previous.sx===sx && previous.sy===sy && previous.r===rotation && previous.a===alpha && previous.v===visible &&
               previous.blend===blend && previous.cache===cache && previous.smoothing===smooth && previous.pixelSnapping===snapping &&
               previous.filters.length==0 && !previous.hasOwnProperty("pixels")) {
               if(depth==0)Timing.end("capture.pose",began);return previous;
            }
            var leaf:Object={x:px,y:py,sx:sx,sy:sy,r:rotation,m:m,a:alpha,v:visible,c:c,
               blend:blend,cache:cache,filters:EMPTY_FILTERS,smoothing:smooth,pixelSnapping:snapping};
            captured[display]=leaf;if(depth==0)Timing.end("capture.pose",began);return leaf;
         }
         var s:Object={x:px,y:py,sx:sx,sy:sy,r:rotation,m:m,a:alpha,v:visible,c:c};''')
    text=replace(text,'s.blend=display.blendMode;s.cache=display.cacheAsBitmap;', 's.blend=blend;s.cache=cache;')
    # Only display instances have immutable native class identity. Filters are
    # cloned by AIR getters and are deliberately left outside this cache.
    for expr in ('display','child','target','parent.getChildAt(int(child.i))'):
        old='getQualifiedClassName('+expr+')'
        # Do not rewrite the cache's one uncached native lookup.
        if expr=='display':
            text=replace(text,'clip==null || '+old+'=="flash.display::MovieClip"',
                'clip==null || displayClass(display)=="flash.display::MovieClip"')
        else:text=text.replace(old,'displayClass('+expr+')')
    text=replace(text,'delete captured[display];delete scriptless[display];',
        'delete captured[display];delete scriptless[display];delete classNames[display];')
    path.write_text(text,encoding='utf-8');changes[name]=(before,text)
    name='src/RConnectMod.as';path=OUT/name
    before=text=path.read_text(encoding='utf-8');text=replace(text,'B3-0.1-field4','B3-0.1-scalar1')
    path.write_text(text,encoding='utf-8');changes[name]=(before,text)
    folder=Path(__file__).parent
    (folder/'candidate.patch').write_text(''.join(''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile=n,tofile=n)) for n,(a,b) in changes.items()),encoding='utf-8')
    files={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.rglob('*.as'))}
    (folder/'source-plan.json').write_text(json.dumps(dict(base=str(BASE),output=str(OUT),files=files),indent=2)+'\n',encoding='utf-8')
    print(OUT)

if __name__=='__main__':main()
