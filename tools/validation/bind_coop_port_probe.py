"""Bind the unchanged Q driver to the private-logging-only production probe."""
import shutil
from check_coop_bundle import M52,read,save,sha,inventory

def main():
    candidate=M52/'coop-bundle-port-probe-01';parent=M52/'coop-bundle-03'
    base=M52/'coop-bundle-drivers-02';out=M52/'coop-bundle-port-probe-drivers-01'
    m=read(candidate/'prepared.json');old=read(parent/'prepared.json');d=read(base/'prepared.json')
    assert m['diagnostic_only'] and m['diagnostic_parent']==sha(parent/'prepared.json') and not out.exists()
    assert [n for n in m['source'] if m['source'][n]!=old['source'][n]]==['src/rconnect/core/PeerVisionTeleport.as']
    for n,h in {**m['source'],**m['inputs']}.items():assert sha(candidate/n)==h,n
    for n,h in d['files'].items():assert sha(base/n)==h,n
    m.update(compiled=True,sha256=sha(candidate/'RConnectMod.swf'),candidate_sha256=sha(candidate/'RConnectMod.swf'))
    save(candidate/'prepared.json',m)
    shutil.copytree(base,out)
    for p in out.glob('*/driver-input.json'):
        data=read(p);data['candidate_sha256']=m['sha256'];save(p,data)
    (out/'prepared.json').unlink()
    save(out/'prepared.json',dict(candidate_sha256=m['sha256'],source_manifest=sha(candidate/'prepared.json'),
        recipe_sha256=sha(__file__),origins=dict(previous_manifest=sha(base/'prepared.json'),private_logging_only=True),files=inventory(out)))
    print(m['sha256'])

if __name__=='__main__':main()
