"""Read-only source checks. Does not compile AS3, execute its component, or launch AIR."""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def main():
    files = [HERE / 'src/PaintTailSampler.as', HERE / 'src/FlashPaintTailSampler.as',
             HERE / 'tests/PaintTailSamplerChecks.as', HERE / 'tests/PaintTailSamplerComponentDoc.as',
             HERE / 'README.md']
    helper, adapter, component, doc, _ = [p.read_text(encoding='utf-8-sig') for p in files]
    fake = (HERE / 'tests/FakePaintTailApi.as').read_text(encoding='utf-8-sig')
    checks = []

    def check(value, label):
        assert value, label
        checks.append(label)

    check('import flash.sampler' not in helper and 'import flash.sampler' not in component,
          'only real adapter imports flash.sampler')
    check('import flash.sampler.*;' in adapter, 'real sampler isolated in explicit adapter')
    check('exclusiveInputConfirmed:Boolean=false' in adapter and '!admitted' in adapter,
          'real adapter defaults to unadmitted')
    check('setSamplerCallback(' not in helper + adapter + component, 'no global sampler callback replacement')
    check('rconnectPaintTimingBridge=' not in helper.replace(' ', ''), 'helper does not replace native observer')
    check('Log.d(' not in helper and 'flash.filesystem' not in helper, 'no per-frame file logging')
    check('Event.ENTER_FRAME,onEnter,false,1000000' in helper, 'exact requested stage priority')
    check('pending=true;api.start(token);' in helper, 'partly-started sampler has cleanup path')
    check('finish("segment-change");\n         if(blocked)' in helper,
          'old-window cleanup failure prevents new segment')
    close = helper.split('private function close(', 1)[1].split('private function collect(', 1)[0]
    check(close.index('api.pause(token)') < close.index('if(paused && row.started)collect()'),
          'pause before enumeration')
    check('if(!row.claimed)return;' in close and 'sampler-ownership-lost' in close,
          'unclaimed or lost sampler never paused')
    check('samplingComplete=row.complete && !row.sampleTruncated' in helper
          and all('row.' + name + '==0' in helper for name in
                  ('stackOverflow', 'depthTruncated', 'textTruncated', 'textOverflow')),
          'all truncation categories deny complete CPU evidence')
    for name, value in [('SEGMENTS', 3), ('SAMPLE_LIMIT', 32768), ('STACK_LIMIT', 1024),
                        ('DEPTH_LIMIT', 64), ('TEXT_LIMIT', 262144), ('FRAME_TEXT_LIMIT', 512)]:
        check(re.search(r'\b' + name + r':int=' + str(value) + r'\b', helper), 'budget ' + name)
    check('private static var owner:Object;' in adapter and 'requireOwner(token)' in adapter,
          'real adapter guards operations with its exact lease')
    check('new FakePaintTailApi()' in component and 'new FlashPaintTailSampler(' not in component,
          'component uses fake sampler only')
    check('throw undefined;' in fake, 'fake exception path includes undefined thrown value')
    origin = json.loads((HERE / 'split-origin.json').read_text(encoding='utf-8'))
    prior = Path(origin['source'])
    for name, digest in origin['originals'].items():
        check(hashlib.sha256((prior / name).read_bytes()).hexdigest() == digest, 'frozen original ' + name)
    for name in ('src/PaintTailSampler.as', 'src/FlashPaintTailSampler.as', 'tests/PaintTailSamplerComponentDoc.as'):
        check((HERE / name).read_bytes() == (prior / name).read_bytes(), 'unchanged v2 ' + name)
    restored = component[:-2] + fake[len('package {\n'):].replace(
        '   public final class FakePaintTailApi {', '   internal final class FakePaintTailApi {', 1)
    check(restored == (prior / 'tests/PaintTailSamplerChecks.as').read_text(encoding='utf-8'),
          'exact reverse of fake-class split')
    check('new FlashPaintTailSampler(' not in doc and 'REAL_ADAPTER:Class=FlashPaintTailSampler' in doc,
          'AIR entry links real adapter without using it')
    manifest = json.loads((HERE / 'component-inputs.json').read_text(encoding='utf-8'))
    for name, digest in manifest['source_sha256'].items():
        source = HERE / name
        copy = HERE / 'component' / source.name
        check(hashlib.sha256(source.read_bytes()).hexdigest() == digest
              and copy.read_bytes() == source.read_bytes(), 'exact component copy ' + source.name)
    check(manifest['expected'] == 31 and manifest['compiled'] is False, 'component expected count; source only')
    check('row.visited>row.totalSamples' in helper and 'f.api.countOverride=0' in component,
          'sample count contradiction is rejected and has fake negative case')
    host = ROOT / 'build/m52/recovery-early-paint-host-03/pfe.swf'
    host_sha = hashlib.sha256(host.read_bytes()).hexdigest()
    check(host_sha == '29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7',
          'host03 remains exact read-only input')
    result = dict(kind='paint-tail-source-check', source_checks=len(checks), checks=checks,
                  source_checks_passed=True, as3_component_executed=False, compiled=False,
                  air_started=False, performance_qualified=False, host_sha256=host_sha,
                  component_assertion_calls=len(re.findall(r'\bcheck\(', component)) - 1,
                  files={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files})
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
