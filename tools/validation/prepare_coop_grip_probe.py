"""Log exact native cost and projectile rejection state; no gameplay changes."""
import os
import shutil
import subprocess
import sys
from check_coop_bundle import M52, ROOT, JAVA, SDK, read, save, sha, inventory


def main():
    base=M52/'coop-bundle-04';out=M52/'coop-bundle-grip-probe-02'
    drivers=M52/'coop-bundle-drivers-03';testout=M52/'coop-bundle-grip-probe-drivers-02'
    m=read(base/'prepared.json');d=read(drivers/'prepared.json')
    assert not out.exists() and not testout.exists()
    assert d['candidate_sha256']==m['sha256']
    for n,h in {**m['source'],**m['inputs']}.items():assert sha(base/n)==h,n
    for n,h in d['files'].items():assert sha(drivers/n)==h,n
    for folder in ('src','tools'):shutil.copytree(base/folder,out/folder)
    p=out/'src/rconnect/core/ProjectileGrip.as';s=p.read_text(encoding='utf-8')
    old='               reject(link,p,"ineligible");return;'
    new='''               Log.d("GRIP REJECT PROBE "+JSON.stringify({id:p.id,token:p.token,at:getTimer(),alive:alive(b),
                  b:b==null?null:{chain:b.in_chain,babah:b.babah,liv:b.liv,poss:b.levitPoss,mass:b.massa,levit:b.levit,x:b.X,y:b.Y,localHeld:game.gg.teleObj===b},
                  actor:a==null?null:{sameLoc:a.loc===game.loc,hp:a.hp,sost:a.sost,x:a.X,y:a.Y},input:input}));
'''+old
    assert s.count(old)==1;s=s.replace(old,new)
    old='               incoming={id:String(p.id),token:int(p.token),target:b,link:link,stamp:p};'
    new='''               Log.d("GRIP ACCEPT PROBE "+JSON.stringify({id:p.id,token:p.token,at:getTimer(),liv:b.liv,x:b.X,y:b.Y,
                  dx:b.dx,dy:b.dy,levit:b.levit,babah:b.babah,input:p.input}));
'''+old
    assert s.count(old)==1;s=s.replace(old,new)
    old='         var rec:Object=incoming;incoming=null;if(rec==null)return;'
    new=old+'''
         Log.d("GRIP END PROBE "+JSON.stringify({id:rec.id,token:rec.token,at:getTimer(),reason:reason,
            liv:rec.target.liv,x:rec.target.X,y:rec.target.Y,dx:rec.target.dx,dy:rec.target.dy,
            levit:rec.target.levit,babah:rec.target.babah,chain:rec.target.in_chain}));'''
    assert s.count(old)==1;s=s.replace(old,new);p.write_text(s,encoding='utf-8')
    m.update(compiled=False,installed=False,diagnostic_only=True,diagnostic_parent=sha(base/'prepared.json'),
        source={'src/'+n:h for n,h in inventory(out/'src').items()})
    m.pop('sha256');m.pop('candidate_sha256');save(out/'prepared.json',m)
    command=[sys.executable,'-B','-X','utf8',str(out/'tools/build_mod.py'),
        '--java',str(JAVA),'--amxmlc',str(SDK/'bin/amxmlc.bat'),'--output',str(out/'RConnectMod.swf')]
    with (out/'compile.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    m.update(compiled=True,sha256=sha(out/'RConnectMod.swf'),candidate_sha256=sha(out/'RConnectMod.swf'))
    save(out/'prepared.json',m)
    shutil.copytree(drivers,testout)
    p=testout/'tests/PeerProjectileGripTestDoc.as';s=p.read_text(encoding='utf-8-sig')
    old='target:g.teleObj==null?null:getQualifiedClassName(g.teleObj),cel:cel==null?null:{cls:getQualifiedClassName(cel),'
    new='''cost:{sqrt:g.teleSqrtMassa,mult:g.pers.teleMult,all:g.pers.allDManaMult,threshold:g.pers.telePorog,
               dmana:g.dmana,mana:g.mana,god:mod.game.world.godMode},
            '''+old
    assert s.count(old)==1;s=s.replace(old,new)
    # Other installed mods rebuild Pers. Keep the already intended fixture
    # threshold at zero; do not change native cost or the original assertions.
    old='         g.invulner=true;g.transp=true;g.disabled=false;g.ggControl=true;g.isTake=0;c.active=true;'
    assert s.count(old)==1;s=s.replace(old,old+'\n         g.pers.telePorog=0;')
    # Observe one held frame after native cost has run.
    old='heldFrames++;minMana=Math.min(minMana,g.mana);'
    assert s.count(old)==1;s=s.replace(old,old+'\n            if(heldFrames==5)diagnostic("held-cost");')
    p.write_text(s,encoding='utf-8')
    command=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
        '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(testout/'tests'),
        '-external-library-path+='+str(testout/'ProductionDeclarations.swc'),
        '-external-library-path+='+str(out/'build/GameCombatStubs.swc'),
        '-output='+str(testout/'projectile-grip/EffectsDriver.swf'),str(p)]
    with (testout/'grip-probe-compile.log').open('w',encoding='utf-8') as log:
        subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    for p in testout.glob('*/driver-input.json'):
        row=read(p);row['candidate_sha256']=m['sha256'];save(p,row)
    (testout/'prepared.json').unlink()
    save(testout/'prepared.json',dict(candidate_sha256=m['sha256'],source_manifest=sha(out/'prepared.json'),
        recipe_sha256=sha(__file__),origins=dict(previous_manifest=sha(drivers/'prepared.json'),production_logging_only=True,
            fixture_change='Reapply intended telePorog=0 before native input; retain every assertion'),files=inventory(testout)))
    print('Diagnostic-only compiled '+m['sha256'],flush=True)


if __name__=='__main__':main()
