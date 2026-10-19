"""Opt-in native security hooks, on a pinned copy of the CURRENT game only."""
import argparse
import difflib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_security_terminals import ROOT, sha

CLASSES=('fe.serv.Interact','fe.unit.UnitTurret','fe.weapon.Bullet')
GAME=ROOT.parents[1]


def patch(name, text):
    def change(old,new,count=1):
        nonlocal text
        assert text.count(old)==count,(name,old[:110],text.count(old),count)
        text=text.replace(old,new)
    if name=='fe.serv.Interact':
        change('   import fe.unit.Unit;', '   import fe.unit.Unit;\n   import fe.unit.UnitTurret;')
        anchor='            World.w.gui.infoText("term1Act");'
        change(anchor, '''            if(UnitTurret.rconnectSecurity != null && UnitTurret.rconnectSecurity("terminal",this,World.w.pers.security) === true)
            {
               World.w.gui.infoText("term1Act");
               World.w.gui.bulb(this.X,this.Y);
               return;
            }
'''+anchor)
    elif name=='fe.unit.UnitTurret':
        anchor='      public function UnitTurret('
        change(anchor, '''      public static var rconnectSecurity:Function = null;

      public static function rconnectSecurityHit(source:Unit, target:Unit, original:Boolean) : Boolean
      {
         if(rconnectSecurity != null && source != null && target != null &&
            (source is UnitTurret || target is UnitTurret || source.fraction == Unit.F_PLAYER && target.fraction == Unit.F_PLAYER))
         {
            var answer:* = rconnectSecurity("hit",source,target);
            if(answer is Boolean) return Boolean(answer);
         }
         return original;
      }

'''+anchor)
        anchor='      override public function findCel(param1:Boolean = false) : Boolean\n      {'
        change(anchor,anchor+'''
         if(rconnectSecurity != null)
         {
            var rconnectAnswer:* = rconnectSecurity("find",this,param1);
            if(rconnectAnswer is Boolean) return Boolean(rconnectAnswer);
         }''')
        anchor='      override public function control() : *\n      {'
        change(anchor,anchor+'\n         if(rconnectSecurity != null) rconnectSecurity("step",this);')
    elif name=='fe.weapon.Bullet':
        change('   import fe.unit.Unit;', '   import fe.unit.Unit;\n   import fe.unit.UnitTurret;')
        # Read-only bounds checks run before the permission callback. Dense
        # ordinary firefights should not dispatch a callback for every missed
        # bullet/unit pair; only actual collision candidates need a relation.
        change('Boolean((this.targetObj || _loc2_.fraction != this.owner.fraction) && X >= _loc2_.X1 && X <= _loc2_.X2) && Boolean(Y >= _loc2_.Y1) && Y <= _loc2_.Y2',
               'X >= _loc2_.X1 && X <= _loc2_.X2 && Y >= _loc2_.Y1 && Y <= _loc2_.Y2 && UnitTurret.rconnectSecurityHit(this.owner,_loc2_,Boolean(this.targetObj || _loc2_.fraction != this.owner.fraction))')
        for unit in ('_loc1_','_loc3_'):
            cond=f'if(!({unit}.sost == 4 || {unit}.invulner || {unit}.disabled || {unit}.trigDis || {unit}.loc != loc))'
            change(cond,cond[:-1]+f' && UnitTurret.rconnectSecurityHit(this.owner,{unit},true))')
        change('Boolean(this.weap.owner.fraction == Unit.F_PLAYER) && _loc1_.player)',
               'Boolean(this.weap.owner.fraction == Unit.F_PLAYER) && _loc1_.player && !UnitTurret.rconnectSecurityHit(this.owner,_loc1_,false))')
        change('if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER)',
               'if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER && !UnitTurret.rconnectSecurityHit(this.owner,_loc3_,false))')
    # FFDec E4X attribute-filter import ambiguity: preserve explicit attribute
    # reads, matching the workspace's existing native patch recipe.
    term=r'(?:[A-Za-z_][\w.]*|"[^"\n]*")'
    pattern=r'([A-Za-z_][\w.]*)\.\(@([A-Za-z_]\w*)\s*==\s*('+term+r'(?:\s*\+\s*'+term+r')*)\)'
    text,queries=re.subn(pattern,lambda m:'rconnectSecurityXmlFind('+m[1]+',"'+m[2]+'",'+m[3]+')',text)
    if queries:
        anchor='      public function '+name.split('.')[-1]+'('
        change(anchor,'''      private static function rconnectSecurityXmlFind(nodes:XMLList, key:String, expected:*) : XMLList
      {
         var result:XMLList = new XMLList();
         for each(var node:XML in nodes) if(node.attribute(key) == expected) result += node;
         return result;
      }

'''+anchor)
    return text


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('output',type=Path)
    ap.add_argument('--game-sha',required=True)
    args=ap.parse_args()
    out=(ROOT/args.output).resolve();original=GAME/'pfe.swf'
    assert out.parent==ROOT/'build/m52' and not out.exists()
    assert sha(original)==args.game_sha
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from common import JAVA,FFDEC
    from patch_native import swf_tags
    out.mkdir();shutil.copyfile(original,out/'original.swf')
    def run(command,logname):
        assert sha(original)==args.game_sha,'Installed game changed during preparation'
        with (out/logname).open('w',encoding='utf-8') as log:
            subprocess.run([str(JAVA),'-Xmx512m','-jar',str(FFDEC),*map(str,command)],stdout=log,stderr=subprocess.STDOUT,check=True)
    names=','.join((*CLASSES,'MainFE'))
    run(['-selectclass',names,'-export','script',out/'before',out/'original.swf'],'export.log')
    patches=[]
    for name in CLASSES:
        rel=Path(*name.split('.')).with_suffix('.as')
        before=(out/'before/scripts'/rel).read_text(encoding='utf-8-sig')
        after=patch(name,before);dest=out/'import'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(after,encoding='utf-8')
        patches.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='before/'+str(rel),tofile='after/'+str(rel)))
    (out/'security.patch').write_text(''.join(patches),encoding='utf-8')
    run(['-importScript',out/'original.swf',out/'pfe.swf',out/'import'],'import.log')
    run(['-selectclass',names,'-export','script',out/'after',out/'pfe.swf'],'verify.log')
    assert (out/'before/scripts/MainFE.as').read_bytes()==(out/'after/scripts/MainFE.as').read_bytes(),'Loader changed'
    before_tags,after_tags=swf_tags(out/'original.swf'),swf_tags(out/'pfe.swf')
    assert len(before_tags)==len(after_tags)
    # Preserve all media/assets, scene tags and metadata. Only ABC code may change.
    for a,b in zip(before_tags,after_tags):
        assert a[0]==b[0]
        if a[0] not in (72,82):assert a==b
    result=dict(kind='security-native',original_sha256=args.game_sha,candidate_sha256=sha(out/'pfe.swf'),
                recipe_sha256=sha(__file__),patched_classes=list(CLASSES),non_code_tags_unchanged=True,
                loader_unchanged=True,installed_modified=False,gameplay_verified=False)
    (out/'prepared.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))


if __name__=='__main__':main()
