"""Try shape-key reuse inside the immutable confirmation decoder; retain exact field values."""
from pathlib import Path
import shutil,difflib,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'build/ab/b190-field22-source';prior=ROOT/'build/ab/b190-scalar02-source';out=ROOT/'build/ab/b190-scalar03-source'
if out.exists():raise FileExistsError(out)
shutil.copytree(prior,out)
p=out/'src/authority/FrameDelta.as';text=p.read_text(encoding='utf-8')
def change(old,new):
 global text
 assert text.count(old)==1,old
 text=text.replace(old,new)
change('private var prior:Object,serial:uint=0;', 'private var prior:Object,serial:uint=0;\n      private var branchKeys:Dictionary=new Dictionary(true);')
change('''                  if(updates!=null)for(var key:String in updates)target[key]=updates[key];
                  if(op[3]!=null)for each(key in op[3])delete target[key];
               }else if(op[1]==0)delete target[path[path.length-1]];else target[path[path.length-1]]=op[2];''',
'''                  var cached:Boolean=branchKeys[target]!=null;
                  if(updates!=null)for(var key:String in updates) {
                     if(cached && (!target.hasOwnProperty(key) || target is Array && key=="length")){delete branchKeys[target];cached=false;}
                     target[key]=updates[key];
                  }
                  if(op[3]!=null){delete branchKeys[target];for each(key in op[3])delete target[key];}
               }else {
                  key=String(path[path.length-1]);
                  if(op[1]==0){delete branchKeys[target];delete target[key];}
                  else {
                     if(!target.hasOwnProperty(key) || target is Array && key=="length")delete branchKeys[target];
                     target[key]=op[2];
                  }
               }''')
change('''      private static function branch(value:Object):Object {
         var result:Object=value is Array?[]:{};
         for(var key:String in value)result[key]=value[key];
         return result;
      }''',
'''      private function branch(value:Object):Object {
         var result:Object=value is Array?[]:{},keys:Vector.<String>=branchKeys[value];
         if(keys==null) {
            keys=new Vector.<String>();
            for(var key:String in value){keys.push(key);result[key]=value[key];}
            branchKeys[value]=keys;
         }else {
            var length:int=keys.length;
            for(var index:int=0;index<length;index++){key=keys[index];result[key]=value[key];}
         }
         // Only immutable property names are shared. Every changed data branch
         // is still freshly copied; alias handling and old frames are preserved.
         // A key addition/deletion invalidates this new object's shape only.
         branchKeys[result]=keys;
         return result;
      }''')
p.write_text(text,encoding='utf-8')
p=out/'src/RConnectMod.as';p.write_text(p.read_text(encoding='utf-8').replace('B3-0.1-scalar2','B3-0.1-scalar3'),encoding='utf-8')
patch=''
for name in ['src/authority/NativeFields.as','src/authority/VisualPose.as','src/authority/FrameDelta.as','src/RConnectMod.as']:
 a=(base/name).read_text(encoding='utf-8');b=(out/name).read_text(encoding='utf-8')
 patch+=''.join(difflib.unified_diff(a.splitlines(True),b.splitlines(True),fromfile=name,tofile=name))
(Path(__file__).parent/'candidate03.patch').write_text(patch,encoding='utf-8')
files={p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*.as'))}
(Path(__file__).parent/'source-plan03.json').write_text(json.dumps(dict(base=str(base),output=str(out),files=files),indent=2)+'\n',encoding='utf-8')
print(out)
