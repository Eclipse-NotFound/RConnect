"""Root explicitly freezes reviewed host and compiled driver; missing review always refuses."""
from pathlib import Path
import argparse,json
from native_inputs import (HERE,ROOT,M52,EXIT,DRIVER,HOST,REVIEW,HOST_SHA,RC_SHA,SOURCE_SHA,
    HOST_SOURCE,REJECTED_REVIEW,sha,read,early,driver,installation,validate_host,compatibility)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--drivers',required=True)
    ap.add_argument('--expected-host-sha',required=True)
    ap.add_argument('--expected-review-sha',required=True)
    ap.add_argument('--expected-driver-sha',required=True)
    a=ap.parse_args();out=HERE/'inputs.json'
    assert not out.exists(),'Do not alter frozen runtime admission'
    assert a.expected_host_sha.lower()==HOST_SHA
    early.verify_tools();driver.verify_tools()
    compatibility()
    candidate=Path(read(EXIT/'inputs.json')['candidate']);early.audit(candidate)
    drivers=(ROOT/a.drivers).resolve();assert drivers.parent==M52
    meta=read(drivers/'prepared.json');driver.verify_driver(drivers,meta,'scene')
    assert sha(drivers/'scene/EffectsDriver.swf')==a.expected_driver_sha.lower()
    _,host_files=validate_host(HOST,installation(),a.expected_review_sha.lower())
    originals=[EXIT/'inputs.json',EXIT/'native_inputs.py',EXIT/'run_native.py',DRIVER/'inputs.json',
        DRIVER/'binding.py',DRIVER/'audit_profile.py',HOST/'prepared.json',REVIEW,
        candidate/'prepared.json',drivers/'prepared.json',HOST_SOURCE/'handoff.json',REJECTED_REVIEW,
        HERE.parent/'recovery-early-revisit-frozen-rv/native_runner.py']
    originals += [HOST_SOURCE/n for n in read(HOST_SOURCE/'handoff.json')['files']]
    files={str(p):sha(p) for p in originals}
    files.update(host_files)
    files.update({str(drivers/n):h for n,h in meta['files'].items()})
    sources=[p for p in HERE.iterdir() if p.is_file() and p.name!='inputs.json']
    pins=dict(sources={p.name:sha(p) for p in sources},originals=files,
        candidate_sha256=RC_SHA,host_sha256=HOST_SHA,host_source_sha256=SOURCE_SHA,
        host_review_sha256=a.expected_review_sha.lower(),driver=str(drivers),
        driver_manifest_sha256=sha(drivers/'prepared.json'),driver_sha256=a.expected_driver_sha.lower(),
        diagnostic_only=True,performance_qualified=False)
    out.write_text(json.dumps(pins,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(out)

if __name__=='__main__':main()
