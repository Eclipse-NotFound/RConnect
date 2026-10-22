"""Replace only the diagnostic finally with explicit saved-error propagation.

Offline source preparation only. Frozen v1/v2 and host02 rejection are inputs.
"""
from pathlib import Path
import difflib,hashlib,importlib.util,json,sys

HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
V2=HERE.parent/'recovery-early-paint-timing-v2'
spec=importlib.util.spec_from_file_location('frozen_paint_v2_prepare',V2/'prepare.py')
v2=importlib.util.module_from_spec(spec);spec.loader.exec_module(v2)
BASE=v2.BASE;HOST_SHA=v2.HOST_SHA;SOURCE_SHA=v2.SOURCE_SHA;SOURCE=v2.SOURCE
V1=v2.V1;ACC=v2.ACC;ACC_SOURCE=v2.ACC_SOURCE
water_proof=v2.water_proof;frozen_v1=v2.frozen_v1
PSEUDO_J=v2.PSEUDO_J
TARGET=HERE/'src/fe/graph/Grafon.as'
REJECTED=ROOT/'build/m52/recovery-early-paint-host-recheck-02/receipt.json'
REJECTED_HOST=ROOT/'build/m52/recovery-early-paint-host-02'
REJECTED_SHA='701562a9306ea15dfd4a1722b79626651f26b55e13d586a0fb0260db6678d560'
sys.path.insert(0,str(ROOT/'experimental/recovery-early-travel'))
from prepare_host import methods

NATIVE='''         var paintCompleted:Boolean = false;
         var paintFailed:Boolean = false;
         var paintFailure:*;
         try
         {
            if(this.scenePreload)
            {
               this.scenePreloadAll();
            }
            else
            {
               this.sceneEnsureUpcoming(left,top,width,height);
            }
            paintCompleted = true;
         }
         catch(paintNativeError:*)
         {
            paintFailed = true;
            paintFailure = paintNativeError;
         }
'''
RETHROW='''         if(paintFailed)
         {
            throw paintFailure;
         }
      }'''

def sha(data):return hashlib.sha256(data).hexdigest()
def lf(data):return data.decode('utf-8').replace('\r\n','\n')
def frozen_v2():
    meta=json.loads((V2/'handoff.json').read_text(encoding='utf-8'))
    assert all(sha((V2/p).read_bytes())==h for p,h in meta['files'].items())
    return meta

def transform(data):
    frozen_v2()
    source=lf(v2.transform(data));old=methods(source)['sceneEnsure']
    prefix,tail=old.split('         var paintCompleted:Boolean = false;',1)
    marker='         finally\n         {\n'
    assert tail.count(marker)==1 and tail.endswith('         }\n      }')
    observer=tail.split(marker,1)[1][:-len('         }\n      }')]
    # Move the same observer isolation out of finally; all clocks/fields stay.
    assert observer.startswith('            if(paintObserver != null)')
    observer='\n'.join(line[3:] if line.startswith('   ') else line for line in observer.split('\n'))
    new=prefix+NATIVE+observer+RETHROW
    assert 'finally' not in new and new.count('return;')==2
    assert new.count('this.scenePreloadAll();')==new.count('this.sceneEnsureUpcoming(left,top,width,height);')==1
    result=source.replace(old,new,1)
    assert [n for n,m in methods(result).items() if m!=methods(source)[n]]==['sceneEnsure']
    assert '§§' not in result
    return result.replace('\n','\r\n').encode('utf-8')

def main():
    assert sha((BASE/'pfe.swf').read_bytes())==HOST_SHA
    receipt=json.loads(REJECTED.read_text(encoding='utf-8'))
    assert receipt['compiled'] and receipt['validated'] is False and receipt['exception_cfg_passed'] is False
    assert receipt['candidate_sha256']==sha((REJECTED_HOST/'pfe.swf').read_bytes())==REJECTED_SHA
    before=(V2/'src/fe/graph/Grafon.as').read_bytes();after=transform(SOURCE.read_bytes())
    if TARGET.exists():assert TARGET.read_bytes()==after,'Refusing to overwrite changed source'
    else:TARGET.parent.mkdir(parents=True,exist_ok=True);TARGET.write_bytes(after)
    patch=''.join(difflib.unified_diff(before.decode().splitlines(True),after.decode().splitlines(True),fromfile='frozen-paint-v2/Grafon.as',tofile='paint-v3/Grafon.as'))
    (HERE/'explicit-error-propagation.patch').write_text(patch,encoding='utf-8',newline='')
    meta=dict(diagnostic_only=True,compiled=False,air_started=False,runtime_qualified=False,performance_qualified=False,
       original_host_sha256=HOST_SHA,original_source_sha256=SOURCE_SHA,
       prior_diagnostic_source_sha256=sha(before),prepared_source_sha256=sha(after),
       rejected_host_sha256=REJECTED_SHA,rejected_receipt_sha256=sha(REJECTED.read_bytes()),
       old_failure_preserved=True,modified_logic_methods=['sceneEnsure'],
       import_only_restoration={'sceneDrawSteps':['j++;','i++;']},pseudo_instructions_remaining=0,
       contract_changed=False,imports_changed=False,uses_finally=False,failed_flag_separate_from_thrown_value=True,
       original_wildcard_import_preserved=True,exception_semantics_review_required=True)
    (HERE/'prepared.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(meta,ensure_ascii=False))

if __name__=='__main__':main()
