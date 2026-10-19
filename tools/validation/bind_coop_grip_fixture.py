"""Bind corrected native-cost fixture to unchanged production bundle2."""
import shutil
from check_coop_bundle import M52, read, save, sha, inventory, verify


def main():
    candidate=M52/'coop-bundle-04';original=M52/'coop-bundle-drivers-03'
    fixture=M52/'coop-bundle-grip-probe-drivers-02';out=M52/'coop-bundle-drivers-04'
    m=verify(candidate);a=read(original/'prepared.json');b=read(fixture/'prepared.json')
    assert not out.exists() and m['sha256']==a['candidate_sha256']
    for folder,data in ((original,a),(fixture,b)):
        for n,h in data['files'].items():assert sha(folder/n)==h,n
    # Only the one fixture is replaced. Its diagnostics are read-only; all
    # gameplay assertions and ten scenarios remain present.
    before=(original/'tests/PeerProjectileGripTestDoc.as').read_text(encoding='utf-8-sig')
    after=(fixture/'tests/PeerProjectileGripTestDoc.as').read_text(encoding='utf-8-sig')
    assert [s.strip() for s in before.splitlines() if 'check(' in s]==[s.strip() for s in after.splitlines() if 'check(' in s]
    assert '         g.pers.telePorog=0;' in after
    shutil.copytree(original,out)
    for name in ('tests/PeerProjectileGripTestDoc.as','projectile-grip/EffectsDriver.swf'):
        shutil.copyfile(fixture/name,out/name)
    (out/'prepared.json').unlink()
    save(out/'prepared.json',dict(candidate_sha256=m['sha256'],source_manifest=sha(candidate/'prepared.json'),
        recipe_sha256=sha(__file__),origins=dict(original_manifest=sha(original/'prepared.json'),
            fixture_manifest=sha(fixture/'prepared.json'),unchanged_assertions=True,
            reason='Maintain intended telePorog=0 after installed mods rebuild native Pers'),files=inventory(out)))
    print('Bound fixture to unchanged production '+m['sha256'])


if __name__=='__main__':main()
