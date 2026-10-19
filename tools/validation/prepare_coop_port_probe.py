"""Freeze diagnostic-only Q release observations, without changing decisions."""
import shutil
from check_coop_bundle import ROOT,M52,read,save,sha,inventory

def main():
    base=M52/'coop-bundle-03';out=M52/'coop-bundle-port-probe-01';assert not out.exists()
    m=read(base/'prepared.json')
    for n,h in {**m['source'],**m['inputs']}.items():assert sha(base/n)==h,n
    for folder in ('src','tools'):shutil.copytree(base/folder,out/folder)
    p=out/'src/rconnect/core/PeerVisionTeleport.as';s=p.read_text(encoding='utf-8')
    anchor='      private function castable():Boolean {'
    probe='''      private function audit(stage:String,a:Object,r:Object):void {
         var rows:Array=[];
         for(var key:Object in links) {
            var p:Object=links[key].proof;
            rows.push({ready:ready(key as TcpLink),age:p==null?-1:getTimer()-int(p.at),same:p!=null && a!=null && p.tile===a.tile});
         }
         var g:Object=game.gg;
         Log.d("PORT RELEASE PROBE "+JSON.stringify({stage:stage,at:getTimer(),release:r!=null,castable:castable(),
            charge:g.t_port,mana:g.mana,cooldown:g.t_culd,x:g.X,y:g.Y,aimX:a==null?-1:a.x,aimY:a==null?-1:a.y,
            sight:a==null?-1:a.tile.visi,permitted:permitted(a),proofs:rows}));
      }
'''
    assert s.count(anchor)==1;s=s.replace(anchor,probe+anchor)
    anchor='            var a:Object=aim(),g:Object=game.gg;'
    assert s.count(anchor)==1;s=s.replace(anchor,anchor+'\n            if(!game.world.ctr.keyTele && g.t_port>0)audit("before",a,null);')
    anchor='            var a:Object=aim();\n            if(r!=null'
    assert s.count(anchor)==1;s=s.replace(anchor,'            var a:Object=aim();\n            if(r!=null)audit("after",a,r);\n            if(r!=null')
    p.write_text(s,encoding='utf-8')
    m.update(compiled=False,installed=False,diagnostic_only=True,diagnostic_parent=sha(base/'prepared.json'),source=inventory(out/'src'))
    m['source']={'src/'+n:h for n,h in m['source'].items()};m.pop('sha256');m.pop('candidate_sha256')
    save(out/'prepared.json',m)
    print('Diagnostic source only; no production decisions changed')

if __name__=='__main__':main()
