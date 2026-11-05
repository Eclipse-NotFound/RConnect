from pathlib import Path
p = Path(__file__).resolve().parents[2] / 'build' / 'ab' / 'b-j11-diag-source-01' / 'src' / 'authority' / 'FrameDelta.as'
s = p.read_text(encoding='utf-8')
old = '''   public final class FrameDelta {
      private var prior:Object,serial:uint=0;'''
new = '''   public final class FrameDelta {
      public static var statsOps:int=0,statsGrouped:int=0,statsClone:int=0,statsFields:int=0,statsPose:int=0,statsFieldKeys:int=0;
      private var prior:Object,serial:uint=0;'''
assert s.count(old)==1
s=s.replace(old,new)
old='''            for each(var op:Array in packet.changes) {
               var path:Array=op[0];
               var grouped:Boolean=op[1]==2;'''
new='''            for each(var op:Array in packet.changes) {
               ++statsOps;
               var path:Array=op[0];
               var grouped:Boolean=op[1]==2;
               if(grouped){++statsGrouped;var statKey:String=path.length==0?"":String(path[path.length-1]);
                  if(statKey=="fields"){++statsFields;var statUpdates:Object=op[2];if(statUpdates!=null)for(var statFk:String in statUpdates)++statsFieldKeys;}
                  else if(statKey=="pose")++statsPose;}'''
assert s.count(old)==1
s=s.replace(old,new)
old='''      private static function branch(value:Object):Object {
         var result:Object=value is Array?[]:{};'''
new='''      private static function branch(value:Object):Object {
         ++statsClone;
         var result:Object=value is Array?[]:{};'''
assert s.count(old)==1
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
print('patched stats')
