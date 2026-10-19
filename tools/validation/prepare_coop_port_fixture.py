"""Fix only the Q test's observed pre-travel setup race; retain all assertions."""
import os
import shutil
import subprocess
from check_coop_bundle import M52, ROOT, JAVA, SDK, read, save, sha, inventory

def main():
    base=M52/'coop-bundle-drivers-01';out=M52/'coop-bundle-drivers-02'
    candidate=M52/'coop-bundle-03';m=read(base/'prepared.json')
    assert not out.exists() and sha(candidate/'RConnectMod.swf')==m['candidate_sha256']
    for n,h in m['files'].items():assert sha(base/n)==h,n
    shutil.copytree(base,out)
    p=out/'tests/PeerPortTestDoc.as';text=p.read_text(encoding='utf-8-sig')
    changes=[
        ('return mod.session.rooms.ready && !mod.session.rooms.busy && !mod.game.isTransitioning();',
         'return mod.session.rooms.canSyncWorld && !mod.game.isTransitioning() && !mod.game.isPlayerDead() && mod.game.roomKey().indexOf("random_mane//")==0;'),
        ('if(host && p.stage=="ready" && phase=="boot"){',
         'if(host && p.stage=="ready" && phase=="boot" && stable() && p.room==mod.game.roomKey() && p.epoch==mod.session.rooms.epoch && p.term==mod.session.rooms.term){'),
        ('readyAt=getTimer();send("ready");',
         'readyAt=getTimer();send("ready",{room:mod.game.roomKey(),epoch:mod.session.rooms.epoch,term:mod.session.rooms.term});'),
        ('private function setup():void {',
         'private function setup():void {\n         check(stable(),"fixture starts after settled expedition room="+mod.game.roomKey());')]
    for before,after in changes:
        assert text.count(before)==1,before;text=text.replace(before,after)
    p.write_text(text,encoding='utf-8')
    driver=out/'peer-port';stub=candidate/'build/GameCombatStubs.swc'
    cmd=[str(JAVA),'-Xmx384m','-jar',str(SDK/'lib/mxmlc.jar'),'+configname=air','+flexlib='+str(SDK/'frameworks'),
        '-swf-version=38','-debug=false','-optimize=true','-source-path='+str(out/'tests'),
        '-external-library-path+='+str(out/'ProductionDeclarations.swc'),'-external-library-path+='+str(stub),
        '-output='+str(driver/'EffectsDriver.swf'),str(p)]
    with (out/'port-fixture-compile.log').open('w',encoding='utf-8') as log:
        subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True,env=dict(os.environ,AIR_HOME=str(SDK)))
    (out/'prepared.json').unlink()
    save(out/'prepared.json',dict(candidate_sha256=m['candidate_sha256'],source_manifest=m['source_manifest'],
        recipe_sha256=sha(__file__),origins=dict(previous_manifest=sha(base/'prepared.json'),changes=changes),files=inventory(out)))
    print('Compiled Q fixture only; production and other 24 drivers unchanged')

if __name__=='__main__':main()
