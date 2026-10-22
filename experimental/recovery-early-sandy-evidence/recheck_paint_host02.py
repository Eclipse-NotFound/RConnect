"""Read-only, exact host02 audit. Emits a rejection; never runs JVM/AIR.

Only this script's assigned new receipt is written. The compiled candidate and
the original failed receipt remain immutable. This is not an AVM2 verifier.
"""
from pathlib import Path
import hashlib, importlib.util, json, re, sys

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / 'build/m52/recovery-early-paint-host-02'
OUT = ROOT / 'build/m52/recovery-early-paint-host-recheck-02/receipt.json'
V2 = ROOT / 'experimental/recovery-early-paint-timing-v2'
PIN = '701562a9306ea15dfd4a1722b79626651f26b55e13d586a0fb0260db6678d560'
PCODE_PIN = '9aefba3fe8ba067a32d0e3e7aba3b2951154d92818c751f69f27fd0533f4e117'
sys.path.insert(0, str(V2))
spec = importlib.util.spec_from_file_location('paint_v2_check', V2 / 'check.py')
c = importlib.util.module_from_spec(spec); spec.loader.exec_module(c)
sys.path.insert(0, str(ROOT / 'tools/validation'))
from prepare_recovery_native_travel import normalized, movie_header
from run_security_terminals import installation
sys.path.insert(0, str(ROOT / 'tools/host_authority'))
from patch_native import swf_tags

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p): return Path(p).read_text(encoding='utf-8-sig')

DECLARATIONS = [('paintObserver','Function'),('paintWorld','Object'),
    ('paintGame','Object'),('paintLoc','Location'),('paintStarted','int'),
    ('paintStartedWall','Number'),('paintResident','int'),('paintPreload','Boolean'),
    ('paintWorldRenderer','Boolean'),('paintWorldLoc','Boolean'),
    ('paintCompleted','Boolean'),('paintFinished','int'),('paintFinishedWall','Number')]
KEYS = 'phase preload initial left top width height started finished startedWall finishedWall residentBefore residentAfter completed sameWorld sameGame sameLoc worldRendererAtStart worldRendererAtEnd worldLocAtStart worldLocAtEnd'.split()

def exact_source_mapping(expected, actual):
    value = c.token(expected)
    signature, body = value.split('{',1)
    prefix = ''
    for name, typ in DECLARATIONS:
        declaration = 'var'+name+':'+typ
        assert body.count(declaration)==1, name
        prefix += declaration+';'
        if declaration+'=' in body:
            body=body.replace(declaration+'=', name+'=',1)
        else:
            assert declaration+';' in body
            body=body.replace(declaration+';','',1)
    head, payload=body.split('paintObserver(this,paintWorld,paintGame,paintLoc,{',1)
    payload, tail=payload.split('});',1)
    for key in KEYS:
        matches=list(re.finditer(r'(^|,)'+key+':',payload))
        assert len(matches)==1,(key,len(matches))
        payload=re.sub(r'(^|,)'+key+':',lambda m:m[1]+'"'+key+'":',payload,count=1)
    value=signature+'{'+prefix+head+'paintObserver(this,paintWorld,paintGame,paintLoc,{'+payload+'});'+tail
    assert value==c.token(actual), 'Only exact uninitialized hoists and 21 payload key quotes allowed'
    return dict(uninitialized_declarations_hoisted=len(DECLARATIONS),payload_keys_quoted=len(KEYS),executable_tokens_changed=False)

def exception_evidence(pcode):
    start=pcode.index('private function sceneEnsure(')
    end=pcode.index('end ; method',start)+len('end ; method')
    method=pcode[start:end]
    lines=[s.strip() for s in method.splitlines()]
    table=[s for s in lines if s.startswith('try from ')]
    assert table==[
      'try from ofs009e to ofs0133 target ofs0137 type null name QName(PackageNamespace(""),"paintCaptureError") end',
      'try from ofs016d to ofs01a5 target ofs01a9 type null name null end',
      'try from ofs016d to ofs01ba target ofs01be type null name null end',
      'try from ofs01e6 to ofs02f6 target ofs02fa type null name QName(PackageNamespace(""),"paintObserverError") end']
    handler=lines[lines.index('ofs02fa:')+1:lines.index('ofs0323:')]
    expected=['getlocal0','pushscope','getlocal 6','pushscope','newcatch 3','dup','setlocal 10','dup','pushscope','swap','setslot 1',
      'findproperty QName(PackageNamespace(""),"rconnectPaintTimingFaults")','dup','setlocal 11',
      'getproperty QName(PackageNamespace(""),"rconnectPaintTimingFaults")','increment','setlocal 12','getlocal 11','getlocal 12',
      'setproperty QName(PackageNamespace(""),"rconnectPaintTimingFaults")','kill 12','kill 11','popscope','kill 10']
    assert handler==expected, 'Review is restricted to the exact actual handler'
    rules={'getlocal0':(0,1),'getlocal':(0,1),'pushscope':(1,0),'newcatch':(0,1),'dup':(1,2),'setlocal':(1,0),
       'swap':(2,2),'setslot':(2,0),'findproperty':(0,1),'getproperty':(1,1),'increment':(1,1),'setproperty':(2,0),'kill':(0,0),'popscope':(0,0)}
    depth=1; trace=[]
    for instruction in handler:
        before=depth; pop,push=rules[instruction.split()[0]]
        assert depth>=pop,(instruction,depth)
        depth+=push-pop
        trace.append(dict(instruction=instruction,before=before,after=depth))
    switch=lines[lines.index('ofs0323:')+1]
    assert switch=='lookupswitch ofs032e, [ofs0188, ofs01d7]' and depth==0
    for marker in ('pushbyte 0','pushbyte -1','pushbyte 1'):
        assert marker in lines
    assert lines[lines.index('ofs01d7:')+1:lines.index('ofs01dd:')]==['label','getlocal 8','kill 8','throw']
    return dict(method_sha256=hashlib.sha256(method.encode()).hexdigest(),exception_table=table,
       handler_entry_operand_depth=1,handler_before_switch_operand_depth=depth,switch_required_depth=1,
       normal_finally_selector_values=[0,-1,1],exception_discards_prior_operand_stack=True,
       original_error_saved_in_local=8,observer_error_selector_restored=False,stack_trace=trace,
       definite_defect='The observer exception path reaches the shared finally lookupswitch with no selector; native-error propagation and observer isolation are not valid.',
       primary_semantics_source='https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp',
       primary_semantics_lines='Exception edges clear operand/scope depth then push one thrown value (raw lines 919-940); OP_lookupswitch requires one operand (1000-1005).',
       runtime_not_attempted=True)

def verify():
    meta_path=HOST/'prepared.json'; original_hash=sha(meta_path)
    meta=json.loads(read(meta_path)); before_install=installation()
    assert meta['compiled'] and not meta['validated'] and meta['error']=="('method readback', 'sceneEnsure')"
    assert sha(HOST/'pfe.swf')==meta['candidate_sha256']==PIN
    assert sha(HOST/'pcode/scripts/fe/graph/Grafon.pcode')==PCODE_PIN
    assert all(sha(p)==digest for p,digest in meta['inputs'].items())
    assert all(sha(HOST/p)==digest for p,digest in meta['readback_files'].items())
    assert before_install==meta['installation_before'] and len(before_install)==22
    expected=read(V2/'src/fe/graph/Grafon.as'); before=read(HOST/'before/scripts/fe/graph/Grafon.as'); after=read(HOST/'after/scripts/fe/graph/Grafon.as')
    c.verify_source((V2/'src/fe/graph/Grafon.as').read_bytes())
    old_method=c.methods(expected)['sceneEnsure']; new_method=c.methods(after)['sceneEnsure']
    source_mapping=exact_source_mapping(old_method,new_method)
    source_checks=c.verify_readback(before,after.replace(new_method,old_method,1),expected)
    negatives=[]
    for name,bad in [('wrong-initializer',new_method.replace('paintCompleted = false;','paintCompleted = true;',1)),
      ('wrong-type',new_method.replace('var paintStarted:int;','var paintStarted:Number;',1)),
      ('observer-swapped',new_method.replace('paintObserver(this,paintWorld','paintObserver(this,null',1))]:
        assert bad!=new_method
        try:exact_source_mapping(old_method,bad)
        except AssertionError:negatives.append(name)
        else:raise AssertionError('Mutation accepted '+name)
    representative={}
    for name in ('MainFE','fe.World','fe.loc.Game','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI'):
        path=Path(*name.split('.')).with_suffix('.as')
        a=normalized(read(HOST/'before/scripts'/path));b=normalized(read(HOST/'after/scripts'/path))
        assert a==b,name
        representative[name]=hashlib.sha256(a.encode()).hexdigest()
    base=c.prepare.BASE/'pfe.swf'; oldtags=swf_tags(base); newtags=swf_tags(HOST/'pfe.swf')
    assert len(oldtags)==len(newtags)
    changed=[]
    for index,(old,new) in enumerate(zip(oldtags,newtags)):
        assert old[0]==new[0]
        if old!=new:assert old[0] in (72,82);changed.append(index)
    assert changed and movie_header(base)==movie_header(HOST/'pfe.swf')
    assert normalized(read(HOST/'before-classes.txt'))==normalized(read(HOST/'after-classes.txt'))
    pcode=read(HOST/'pcode/scripts/fe/graph/Grafon.pcode')
    cfg=exception_evidence(pcode)
    actual_method=pcode[pcode.index('private function sceneEnsure('):]
    actual_method=actual_method[:actual_method.index('end ; method')]
    timer_lines=[s.strip() for s in actual_method.splitlines() if '"getTimer"' in s]
    date_lines=[s.strip() for s in actual_method.splitlines() if '"Date"' in s]
    assert len(timer_lines)==4 and len(date_lines)==4
    assert all('Multiname("getTimer",' in s and 'PackageNamespace("flash.utils")' in s for s in timer_lines)
    assert date_lines==['findpropstrict QName(PackageNamespace(""),"Date")','constructprop QName(PackageNamespace(""),"Date"), 0']*2
    assert installation()==before_install and sha(meta_path)==original_hash
    return dict(kind='diagnostic-paint-host02-independent-rejection',candidate_sha256=PIN,
       original_failed_receipt_sha256=original_hash,compiled=True,source_readback_passed=True,
       pcode_bindings_passed=False,exception_cfg_passed=False,validated=False,diagnostic_only=True,
       installation_unchanged=True,source_unchanged=True,air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
       original_failed_receipt_preserved=True,source_mapping=source_mapping,source_checks=source_checks,negative_checks=negatives,
       representative_classes=representative,non_code_tags_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True,changed_code_tags=changed,
       exception_cfg=cfg,bindings_review=dict(status='not fully qualified after independent decisive CFG rejection',
          actual_timer_lines=timer_lines,actual_date_lines=date_lines,date_global_constructor=True,
          limitation='A Multiname is not itself a wrong binding. Full exact scope/domain resolution is not established in this rejected candidate.'),
       inputs=meta['inputs'],readback_files={str(HOST/p):digest for p,digest in meta['readback_files'].items()},
       audit_script_sha256=sha(__file__))

if __name__=='__main__':
    assert not OUT.exists(), 'Preserve existing receipt'
    result=verify()
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('candidate_sha256','compiled','source_readback_passed','pcode_bindings_passed','exception_cfg_passed','validated','installation_unchanged','source_unchanged')},ensure_ascii=False))
