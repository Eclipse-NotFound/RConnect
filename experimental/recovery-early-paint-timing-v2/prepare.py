"""Exact two-statement import repair on the frozen diagnostic source.

No JVM/AIR. The original failed v1 and output are retained unchanged.
"""
from pathlib import Path
import difflib,hashlib,importlib.util,json,sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
V1=HERE.parent/'recovery-early-paint-timing'
spec=importlib.util.spec_from_file_location('frozen_paint_v1_prepare',V1/'prepare.py')
v1=importlib.util.module_from_spec(spec);spec.loader.exec_module(v1)
BASE=v1.BASE;HOST_SHA=v1.HOST_SHA;SOURCE_SHA=v1.SOURCE_SHA;SOURCE=v1.SOURCE
TARGET=HERE/'src/fe/graph/Grafon.as'
ACC=ROOT/'build/m52/recovery-wall-surfaces-host-01'
ACC_SOURCE=ACC/'import/fe/graph/Grafon.as'
ACC_SOURCE_SHA='625db5c71c4319f4c942e581e039b7419dc070065dc3fb148e23003b715abb04'
ACC_HOST_SHA='acc336b5f28012a5f0d2ef57d0a3bf46be46f72f1e4c3a69a2f063cae0535dfd'
DRAW_METHOD='sceneDrawSteps'
ACC_METHOD_SHA='d83fcb7e451b825cba40e86bead2780d2b3dedaf378a8269b1bf40cae59b6478'
BASE_METHOD_SHA='0f89c3dd2cbedfea92b040dccf4002f27dded07eca8cb6fd15ae3228d2f329cb'
sys.path.insert(0,str(ROOT/'experimental/recovery-early-travel'))
from prepare_host import methods

PSEUDO_J='''                  var _loc1_:* = §§findproperty(j);
                  var _loc2_:Number = Number(_loc1_.j) + 1;
                  _loc1_.j = _loc2_;'''
PSEUDO_I='''               _loc1_ = §§findproperty(i);
               _loc2_ = Number(_loc1_.i) + 1;
               _loc1_.i = _loc2_;'''
SOURCE_J='                  j++;'
SOURCE_I='               i++;'

def sha(data):return hashlib.sha256(data).hexdigest()
def lf(data):return data.decode('utf-8').replace('\r\n','\n')
def frozen_v1():
    meta=json.loads((V1/'handoff.json').read_text(encoding='utf-8'))
    assert all(sha((V1/p).read_bytes())==h for p,h in meta['files'].items())
    return meta

def water_proof():
    assert sha(ACC_SOURCE.read_bytes())==ACC_SOURCE_SHA
    assert sha((ACC/'pfe.swf').read_bytes())==ACC_HOST_SHA
    assert (ACC/'after/scripts/fe/graph/Grafon.as').read_bytes()==SOURCE.read_bytes()
    b=methods(lf(SOURCE.read_bytes()))[DRAW_METHOD]
    a=methods(lf(ACC_SOURCE.read_bytes()))[DRAW_METHOD]
    assert sha(b.encode())==BASE_METHOD_SHA and sha(a.encode())==ACC_METHOD_SHA
    assert b.count(PSEUDO_J)==b.count(PSEUDO_I)==1 and b.count('§§')==2
    repaired=b.replace(PSEUDO_J,SOURCE_J,1).replace(PSEUDO_I,SOURCE_I,1)
    assert repaired==a,'Entire restored method must equal the known compiler input'
    return b,a

def transform(data):
    frozen_v1();before,known=water_proof()
    source=lf(v1.transform(data))
    # Only this exact method and these exact statements may be restored.
    assert methods(source)[DRAW_METHOD]==before
    repaired=source.replace(before,known,1)
    assert '§§' not in repaired,'Any other decompiler pseudo-instruction is rejected before import'
    assert methods(repaired)['sceneEnsure']==methods(source)['sceneEnsure']
    return repaired.replace('\n','\r\n').encode('utf-8')

def main():
    assert sha((BASE/'pfe.swf').read_bytes())==HOST_SHA
    failed=ROOT/'build/m52/recovery-early-paint-host-01/prepared.json'
    failure=json.loads(failed.read_text(encoding='utf-8'))
    assert failure['compiled'] is False and failure['validated'] is False
    before=(V1/'src/fe/graph/Grafon.as').read_bytes();after=transform(SOURCE.read_bytes())
    if TARGET.exists():assert TARGET.read_bytes()==after,'Refusing to overwrite changed source'
    else:TARGET.parent.mkdir(parents=True,exist_ok=True);TARGET.write_bytes(after)
    patch=''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='frozen-paint-v1/Grafon.as',tofile='paint-v2/Grafon.as'))
    (HERE/'water-loop-import-repair.patch').write_text(patch,encoding='utf-8',newline='')
    meta=dict(diagnostic_only=True,compiled=False,air_started=False,runtime_qualified=False,performance_qualified=False,
       original_host_sha256=HOST_SHA,original_source_sha256=SOURCE_SHA,
       prior_diagnostic_source_sha256=sha(before),prepared_source_sha256=sha(after),
       original_failed_receipt_sha256=sha(failed.read_bytes()),original_failed_output_preserved=True,
       acc_source_sha256=ACC_SOURCE_SHA,acc_host_sha256=ACC_HOST_SHA,
       acc_after_equals_2d_after=True,acc_method_sha256=ACC_METHOD_SHA,base_method_sha256=BASE_METHOD_SHA,
       modified_logic_methods=['sceneEnsure'],import_only_restoration={'sceneDrawSteps':['j++;','i++;']},
       pseudo_instructions_remaining=0,contract_changed=False)
    (HERE/'prepared.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(meta,ensure_ascii=False))

if __name__=='__main__':main()
