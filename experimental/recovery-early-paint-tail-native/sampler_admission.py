"""Known-code sampler exclusivity, exact component proof; no process/global changes."""
from pathlib import Path
import json,struct,zlib
import baseline
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
COMPONENT=ROOT/'build/m52/recovery-early-paint-tail-component-03'
HELPER=HERE.parent/'recovery-early-paint-tail-sampler-v3'
API=(b'flash.sampler',b'startSampling',b'pauseSampling',b'stopSampling',b'clearSamples',
     b'sampleInternalAllocs',b'getSamples',b'getSampleCount',b'setSamplerCallback')

def verify_component():
    receipt=baseline.read(COMPONENT/'receipt.json');intent=baseline.read(COMPONENT/'intent.json')
    raw=baseline.read(COMPONENT/'component-result.json')
    assert all(receipt.get(k) is True for k in ('passed','compiled','air_started','source_unchanged','installation_unchanged'))
    assert receipt['observed_checks']==31 and receipt['checks_failed']==0 and receipt['exit_code']==0
    assert receipt['component_sha256']==baseline.sha(COMPONENT/'Checks.swf')=='7052a19cca9859a5d68a70d668784125fa49136f35cc6d8033544b364404b243'
    assert intent['expected']==31 and intent['entry']=='PaintTailSamplerComponentDoc.as'
    assert Path(intent['source']).resolve()==(HELPER/'component').resolve()
    assert len(raw['assertions'])==31 and raw['passed'] is True and raw['failed']==0
    assert all(r['passed'] is True for r in raw['assertions'])
    for name,digest in intent['sources'].items():
        assert baseline.sha(HELPER/'component'/name)==baseline.sha(COMPONENT/'src'/name)==digest
    for name in ('PaintTailSampler.as','FlashPaintTailSampler.as'):
        assert baseline.sha(HERE/'tests'/name)==intent['sources'][name]
    return {str(COMPONENT/n):baseline.sha(COMPONENT/n) for n in
        ('receipt.json','intent.json','component-result.json','Checks.swf')}

def payload(path):
    data=path.read_bytes();assert len(data)>=8 and data[:3] in (b'FWS',b'CWS'),str(path)
    size=struct.unpack('<I',data[4:8])[0];assert 8<=size<=256*1024*1024,str(path)
    body=zlib.decompress(data[8:]) if data[:3]==b'CWS' else data[8:]
    assert len(body)==size-8,'SWF length mismatch '+str(path)
    return body

def inventory():
    # These are exactly the SWF-bearing branches of the unchanged runner's copy list.
    from native_runtime_assets import native_runtime_files
    paths={p.resolve() for p in native_runtime_files(GAME) if p.suffix.lower()=='.swf'}
    paths.remove((GAME/'pfe.swf').resolve());paths.add(ROOT/'build/m52/recovery-early-paint-host-03/pfe.swf')
    candidate=Path(baseline.read(HERE.parent/'recovery-early-exit-native/inputs.json')['candidate'])
    paths.add(candidate/'RConnectMod.swf')
    old,_=baseline.original.verify_original_driver();paths.add(old/'scene/EffectsHarness.swf')
    manifest=GAME/'mods/loader-manifest.txt'
    for line in manifest.read_text(encoding='utf-8-sig').splitlines():
        if '|' not in line or line.startswith('#'):continue
        name,entry=line.split('|')[:2]
        if name.lower()=='rconnect':continue
        path=GAME/'mods'/name/'release'/(entry+'.swf')
        if name.lower()=='realisticvision':path=baseline.frozen_vision()
        elif name.lower()=='sandevistan':path=Path(baseline.sandy_input('bridge')['candidate'])
        assert path.is_file(),str(path)
        paths.add(path.resolve())
    return sorted(paths),manifest

def scan_inputs():
    paths,manifest=inventory();rows=[]
    for path in paths:
        content=payload(path);hits=[token.decode('ascii') for token in API[1:] if token in content]
        assert not hits,('Other known sampler namespace/API in runtime input',str(path),hits)
        namespace=API[0] in content
        # Exact host03 contains the namespace token but none of the sampler API
        # names. A namespace constant alone cannot start sampling. No other input
        # receives this exception, and any API-name occurrence still refuses.
        if namespace:
            assert baseline.sha(path)=='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
        rows.append(dict(path=str(path),sha256=baseline.sha(path),sampler_tokens=hits,namespace_token=namespace))
    return dict(files=rows,manifest=str(manifest),manifest_sha256=baseline.sha(manifest),
        known_code_sampler_entry='FlashPaintTailSampler only',compiled_driver_excluded=True,
        evidence_limit='No explicit sampler API names in other loaded SWFs; exact host03 alone has a namespace-only token. Not a claim about arbitrary external profilers or obfuscated dynamic names',
        required_runner='same frozen runner with exclusive AIR, unique application id, no profiler launch or sampler callback',
        performance_qualified=False)

def verify_sampler_inputs():
    proof=baseline.read(HERE/'sampler-inputs.json')
    paths,manifest=inventory()
    assert [str(p) for p in paths]==[r['path'] for r in proof['files']]
    assert proof['manifest']==str(manifest) and proof['manifest_sha256']==baseline.sha(manifest)
    for row in proof['files']:
        assert not row['sampler_tokens'] and baseline.sha(row['path'])==row['sha256']
        if row['namespace_token']:assert row['sha256']=='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
    assert proof['compiled_driver_excluded'] is True and proof['performance_qualified'] is False
    return proof
