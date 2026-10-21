"""Verify frozen room-loading sources and their compiled binary before use."""
from check_coop_bundle import inventory, read, sha, verify


def audit(candidate):
    meta = read(candidate/'prepared.json')
    if meta['kind'] == 'isolated-coop-bundle':
        meta = verify(candidate)
    else:
        assert meta['kind'] in ('isolated-room-entry-fast', 'isolated-recovery')
        assert meta['base_sha256'] == '574d2b51490ae8b25a1396555600f56a301f8a20ae50104c0e35cf2796441afe'
        assert inventory(candidate/'src') == meta['source'], 'Frozen production source changed'
        assert inventory(candidate/'tools') == meta['inputs'], 'Frozen build inputs changed'
        if meta['kind'] == 'isolated-recovery':
            assert sha(candidate/'integration.json') == meta['integration_sha256'], 'Integration receipt changed'
    assert meta['compiled'] and sha(candidate/'RConnectMod.swf') == meta['sha256']
    return meta
