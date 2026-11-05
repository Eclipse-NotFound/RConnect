"""Static extraction/fixture checks only; optionally freeze this small adapter."""
import argparse
import ast
import json
from pathlib import Path
import re

from prepare import HERE, ROOT, OLD, BRIDGE, sha, read, module, digest
from run_negative import accepted_error


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--freeze',action='store_true')
    args=parser.parse_args()
    rows=[]
    def check(ok,label):
        rows.append(dict(passed=bool(ok),label=label))
        assert ok,label
    info=json.loads(read(HERE/'extraction.json'))
    check(all(sha(Path(p))==h for p,h in info['inputs'].items()),'exact extraction inputs unchanged')
    old=module('old_probe_extract',OLD/'prepare.py')
    base=read(BRIDGE)
    before=read(HERE/'components/probecheck/ProbeBefore.as')
    after=read(HERE/'components/probecheck/ProbeAfter.as')
    check(before==old.class_source('ProbeBefore',base),'before class is exact recovery13 extracted members')
    for name in ('probe','probeOptional'):
        check(old.function(before,name)==old.function(base,name),'before real '+name+' is verbatim')
    check(old.function(before,'probeOptional')==old.function(after,'probeOptional'),'protected optional path unchanged')
    original=old.constants(base)
    check(old.constants(after)[2:]==original,'all three original whitelists unchanged')
    check(len(old.constants(after))==5,'only two new native slot tables')
    old_test=read(OLD/'components/ProbeFastChecks.as')
    doc=read(HERE/'components/ProbeFastChecks.as')
    check(old_test.split('            var config:File=')[0]==doc.split('            if(failed==0)benchmark();')[0],
          'all original semantic cases unchanged before benchmark enable')
    check(old_test.split('   internal dynamic class DynamicWeapon')[1]==doc.split('   internal dynamic class DynamicWeapon')[1],
          'getter/Proxy and subclass counterexamples unchanged')
    check('benchmark-enabled.txt' not in doc and 'if(failed==0)benchmark();' in doc,'benchmark explicitly enabled without marker')
    check('assertions:checks' in doc and 'checks:checks' not in doc,'generic runner assertions schema')
    check('Event.ADDED_TO_STAGE,start' in doc and 'File.applicationStorageDirectory.resolvePath("result.json")' in doc
          and 'NativeApplication.nativeApplication.exit(failed?1:0);' in doc,'native component lifecycle and result outlet')
    check('benchmarks.length==6' in doc and 'measured.pairs.length==6' in doc,'runtime asserts all six groups and six pairs executed')
    check('pass<6' in doc and 'iterations:60000' in doc and 'pass%2==0?"before-after":"after-before"' in doc,
          'original six AB/BA pairs of 60000 reads preserved')
    check('run(ProbeBefore.probe,set.rows,10000);run(ProbeAfter.probe,set.rows,10000);' in doc
          and 'run(probe,rows,20000)' in doc,'original warmup and allocation sample sizes preserved')
    check('unmatched Pt path' in doc and 'generic/display misses' in doc and 'Proxy protected' in doc,
          'unfavorable fallback and non-Pt groups retained')
    check('mixed fixture, not measured game weights' in doc and 'productionTiming:false' in doc,
          'no native workload or whole-frame performance claim')
    primitive={'Number','int','uint','Boolean','String','Array','*','Object'}
    for cls in ('Weapon','Bullet'):
        stub=read(HERE/'components/fe/weapon'/(cls+'.as'))
        traits=info['exact_host_traits']['fe.weapon::'+cls]['slots']
        check(set(traits)==set(info['added_fields'][cls]),cls+' all added slots verified in exact FD92 host')
        declared=dict(re.findall(r'public var (\w+):(\w+|\*);',stub))
        expected={k:(v['type'] if v['type'] in primitive else 'Object') for k,v in traits.items()}
        check(declared==expected,cls+' fixture slot names/types exactly mirror allowed primitive/reference boundary')
        check('extends fe.Obj' in stub,cls+' true inheritance shape retained')
    for relative in ['fe/Pt.as','fe/Obj.as','fe/unit/Unit.as','fe/serv/Interact.as',
                     'fe/weapon/PhisBullet.as','fe/weapon/SmartBullet.as','probecheck/FieldLists.as']:
        check(read(HERE/'components'/relative)==read(OLD/'components'/relative),'old fixture unchanged: '+relative)
    for cls,field in [('IllegalWeaponGetter','hold'),('IllegalBulletGetter','babah')]:
        good=cls+'.as(6): col: 36 Error: Incompatible override.\noverride public function get '+field+'():int {}'
        check(accepted_error(good,cls,field),'negative parser accepts specific '+field+' override diagnosis')
        check(not accepted_error(good.replace('Incompatible override.','Type was not found.'),cls,field),
              'negative parser rejects missing-type error for '+field)
        check(not accepted_error(good.replace(cls+'.as','Unrelated.as'),cls,field),
              'negative parser rejects unrelated-file failure for '+field)
        check(not accepted_error(good+'\nBad.as(2): Error: Syntax error.',cls,field),
              'negative parser rejects mixed syntax failure for '+field)
    check(not (HERE/'src').exists(),'no whole GameBridge or production overlay produced')
    for path in sorted(HERE.glob('*.py')):
        ast.parse(read(path),filename=str(path))
        check(True,'Python syntax: '+path.name)
    result=dict(passed=True,assertions=rows,checks=len(rows),JVM_started=False,AIR_started=False,
                component_compiled=False,benchmark_run=False)
    (HERE/'static-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    if args.freeze:
        files={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
               if p.is_file() and p.name!='manifest.json' and '__pycache__' not in p.parts}
        (HERE/'manifest.json').write_text(json.dumps(dict(kind='exact13-probe-fast-component-only',files=files,
             runtime_executed=False),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(checks=len(rows),passed=True,JVM_started=False,AIR_started=False),ensure_ascii=False))


if __name__=='__main__':
    main()
