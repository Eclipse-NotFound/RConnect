"""Independent read-only admission of the exact host03 diagnostic artifact.

No JVM/AIR. The instruction check is an exact bounded stack/CFG audit, not a
replacement for the AVM2 verifier or a claim of gameplay/performance success.
"""
from pathlib import Path
from collections import deque
import hashlib, importlib.util, json, re, sys

ROOT=Path(__file__).resolve().parents[2]
HOST=ROOT/'build/m52/recovery-early-paint-host-03'
OUT=ROOT/'build/m52/recovery-early-paint-host-recheck-03/receipt.json'
V3=ROOT/'experimental/recovery-early-paint-timing-v3'
PIN='29d36cdd94aadc5368156f80e854808d78b74baf8347ebfcc80c644d73601ef7'
METHOD_PIN='0811bb90424bae6635404f8faacd4d2a90b037c7c500c14cd46d2c6aebb162fa'
PCODE_PIN='7a83e05a035573340ba3b282a41344dd8a271a0a3b58c058bd5f795605f4bbf3'
sys.path.insert(0,str(V3))
spec=importlib.util.spec_from_file_location('paint_v3_check',V3/'check.py')
c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
sys.path.insert(0,str(ROOT/'tools/validation'))
from prepare_recovery_native_travel import normalized,movie_header
from run_security_terminals import installation
sys.path.insert(0,str(ROOT/'tools/host_authority'))
from patch_native import swf_tags

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return Path(path).read_text(encoding='utf-8-sig')

def parse_code(method):
    lines=[x.strip() for x in method.splitlines()]
    code=lines[lines.index('code')+1:lines.index('end ; code')]
    instructions=[];labels={}
    for line in code:
        if not line:continue
        if re.fullmatch(r'ofs[0-9a-f]+:',line):labels[line[:-1]]=len(instructions)
        else:instructions.append(line)
    exceptions=[]
    for line in lines:
        if line.startswith('try from '):
            m=re.fullmatch(r'try from (ofs\w+) to (ofs\w+) target (ofs\w+) type null name QName\(PackageNamespace\(""\),"(\w+)"\) end',line)
            assert m,line
            start,end,target,name=m.groups()
            exceptions.append((labels[start],labels[end],labels[target],name))
    return instructions,labels,exceptions

def stack_cfg(method):
    ops,labels,exceptions=parse_code(method)
    fixed={'debug':(0,0),'label':(0,0),'getlocal':(0,1),'getscopeobject':(0,1),'getlex':(0,1),
      'findpropstrict':(0,1),'findproperty':(0,1),'newactivation':(0,1),'newcatch':(0,1),'setlocal':(1,0),
      'pushscope':(1,0),'popscope':(0,0),'kill':(0,0),'dup':(1,2),'pop':(1,0),'swap':(2,2),
      'setslot':(2,0),'getslot':(1,1),'getproperty':(1,1),'setproperty':(2,0),
      'convert_b':(1,1),'convert_i':(1,1),'coerce':(1,1),'coerce_a':(1,1),'not':(1,1),'increment':(1,1),
      'divide':(2,1),'multiply':(2,1),'equals':(2,1),'strictequals':(2,1),
      'ifeq':(2,0),'iffalse':(1,0),'jump':(0,0),'returnvoid':(0,0),'throw':(1,0)}
    todo=deque([(0,0,0)]);states={};exception_edges=set();peak=0;terminal=[]
    while todo:
        pc,depth,scope=todo.popleft()
        if pc in states:
            assert states[pc]==(depth,scope),('inconsistent merge',pc,ops[pc],states[pc],(depth,scope))
            continue
        states[pc]=(depth,scope);line=ops[pc];op=line.split()[0]
        if op.startswith('getlocal') and op!='getlocal':pop,push=0,1
        elif op.startswith('push') and op!='pushscope':pop,push=0,1
        elif op in ('callproperty','callpropvoid','constructprop'):
            count=int(line.rsplit(', ',1)[1]);pop=count+1;push=0 if op=='callpropvoid' else 1
        elif op=='newobject':pop=2*int(line.split()[1]);push=1
        else:assert op in fixed,op;pop,push=fixed[op]
        assert depth>=pop,('operand underflow',pc,line,depth,pop)
        depth+=push-pop;peak=max(peak,depth)
        if op=='pushscope':scope+=1
        if op=='popscope':scope-=1;assert scope>=0
        if op=='getscopeobject':assert int(line.split()[1])<scope,(pc,line,scope)
        # Conservative: every instruction in each protected interval gets an
        # exception edge; entry has only the thrown value and no local scopes.
        for lo,hi,target,name in exceptions:
            if lo<=pc<hi:
                exception_edges.add((pc,target));todo.append((target,1,0))
        if op in ('returnvoid','throw'):
            assert depth==0,(pc,line,depth)
            terminal.append((pc,op));continue
        if op=='jump':todo.append((labels[line.split()[1]],depth,scope))
        elif op in ('iffalse','ifeq'):
            todo.append((labels[line.split()[1]],depth,scope));todo.append((pc+1,depth,scope))
        else:todo.append((pc+1,depth,scope))
    assert len(states)==len(ops),(len(states),len(ops))
    assert peak==48 and len(terminal)==4
    return dict(instructions=len(ops),reachable_instructions=len(states),conservative_exception_edges=len(exception_edges),
       peak_operand_depth=peak,all_merge_depths_equal=True,no_operand_or_scope_underflow=True,
       terminal_paths=[dict(instruction=pc,operation=op) for pc,op in terminal],
       handler_entries={name:dict(operand_depth=states[target][0],scope_depth=states[target][1]) for _,_,target,name in exceptions},
       final_test_entry=dict(operand_depth=states[labels['ofs030a']][0],scope_depth=states[labels['ofs030a']][1])),(ops,labels,exceptions)

def error_identity(method,parsed):
    ops,labels,exceptions=parsed
    assert [x[3] for x in exceptions]==['paintCaptureError','paintNativeError','paintObserverError']
    assert [(lo,hi,target) for lo,hi,target,_ in exceptions]==[
       (labels['ofs009e'],labels['ofs0133'],labels['ofs0137']),
       (labels['ofs0173'],labels['ofs019f'],labels['ofs01a3']),
       (labels['ofs01cd'],labels['ofs02dd'],labels['ofs02e1'])]
    def block(a,b):return ops[labels[a]:labels[b]]
    assert block('ofs01a3','ofs01c4')==['getlocal0','pushscope','getlocal 6','pushscope','newcatch 1','dup','setlocal 7','dup','pushscope','swap','setslot 1',
       'getscopeobject 1','pushtrue','convert_b','setslot 17','getscopeobject 1','getscopeobject 2','getslot 1','coerce_a','setslot 18','popscope','kill 7']
    assert block('ofs0167','ofs0173')==['getscopeobject 1','pushfalse','convert_b','setslot 16','getscopeobject 1','pushfalse','convert_b','setslot 17']
    assert block('ofs030a','ofs0317')==['getscopeobject 1','getslot 17','iffalse ofs0317','getscopeobject 1','getslot 18','throw']
    assert ops.count('setslot 18')==1 and ops.count('setslot 17')==2
    assert not any(x.startswith('lookupswitch ') for x in ops)
    assert [x for x in ops if x=='throw']==['throw']
    assert not any(x in ('setslot 17','setslot 18') for x in block('ofs01c4','ofs030a'))
    native=block('ofs0173','ofs019f')
    assert native.count('callpropvoid QName(PrivateNamespace("fe.graph:Grafon"),"scenePreloadAll"), 0')==1
    assert native.count('callpropvoid QName(PrivateNamespace("fe.graph:Grafon"),"sceneEnsureUpcoming"), 4')==1
    assert native[:3]==['getlocal0','getproperty QName(PackageNamespace(""),"scenePreload")','iffalse ofs0184']
    assert native[5]=='jump ofs0199'
    assert block('ofs0199','ofs019f')==['getscopeobject 1','pushtrue','convert_b','setslot 16']
    slots=re.findall(r'trait slot QName\(PackageInternalNs\("fe.graph"\),"(\w+)"\)\s+slotid (\d+)\s+type ([^\r\n]+)',method)
    mapped={name:(int(index),typ) for name,index,typ in slots}
    assert mapped['paintFailed']==(17,'QName(PackageNamespace(""),"Boolean")')
    assert mapped['paintFailure']==(18,'null')
    # These are paths proven from the exact slot transfer and final Boolean
    # branch above, not execution of game code or a substitute test fixture.
    cases=[dict(native_value=v,observer_outcome=o,final_outcome='same native value rethrown')
       for v in ('object identity','null','undefined','false','0','empty string') for o in ('absent','success','throws')]
    return dict(native_error_slot=18,failed_boolean_slot=17,catch_value_transfer='catch slot1 -> coerce_a -> activation slot18',
       failed_branch='activation slot17, never truthiness of thrown value',observer_cannot_overwrite_native_failure=True,
       rethrow_outside_all_catch_ranges=True,each_original_branch_once=True,no_finally_or_selector=True,
       exact_value_path_cases=cases,normal_success='paintFailed remains false; observer errors only increment diagnostic fault counter')

def bindings(pcode,method,source):
    lines=[x.strip() for x in method.splitlines()]
    timer=[x for x in lines if '"getTimer"' in x]
    assert len(timer)==4
    lookups=[x for x in timer if x.startswith('findpropstrict ')];calls=[x for x in timer if x.startswith('callproperty ')]
    assert len(set(lookups))==len(set(calls))==1
    assert lookups[0][len('findpropstrict '):]==calls[0][len('callproperty '):-3]
    exact='Multiname("getTimer",[PackageNamespace(""),Namespace("http://adobe.com/AS3/2006/builtin"),PackageNamespace("fe.graph"),PackageInternalNs("fe.graph"),PackageNamespace("fe"),PackageNamespace("fe.loc"),PackageNamespace("flash.utils"),PrivateNamespace("fe.graph:Grafon"),ProtectedNamespace("fe.graph:Grafon"),StaticProtectedNs("fe.graph:Grafon"),PrivateNamespace("Grafon.as$34")])'
    assert lookups[0]=='findpropstrict '+exact and calls[0]=='callproperty '+exact+', 0'
    other=pcode.replace(method,'',1)
    assert other!=pcode
    old_lookup_count=sum(x.strip()==lookups[0] for x in other.splitlines())
    old_call_count=sum(x.strip()==calls[0] for x in other.splitlines())
    assert old_lookup_count==old_call_count and old_call_count>2
    assert re.search(r'public class Grafon\s*\{',source) and 'dynamic class Grafon' not in source
    assert 'import flash.utils.*;' in source
    assert not re.search(r'(?:function|var|const)\s+(?:getTimer|Date)\b',source)
    assert not re.search(r'(?m)^\s*trait[^\r\n]*"(?:getTimer|Date)"',pcode)
    assert not any(x.startswith('pushwith') for x in lines)
    dates=[x for x in lines if '"Date"' in x]
    assert dates==['findpropstrict QName(PackageNamespace(""),"Date")','constructprop QName(PackageNamespace(""),"Date"), 0']*2
    return dict(timer_lookup=lookups[0],timer_call=calls[0],new_timer_pairs=2,
       identical_unchanged_timer_pairs=old_call_count,global_date_constructors=2,
       grafon_base='implicit Object; sealed; original class shell/imports preserved',
       no_timer_or_date_class_or_activation_traits=True,no_with_scope=True,
       resolution='Exact original Grafon lexical namespace set; added activation/catch scopes contain no clock names; unchanged original call sites use the identical lookup and call. No new shadow or global flash property chain.',
       qualification='Static exact-scope/binding equivalence for diagnostic admission; first runtime sample still must report finite monotonic clock values.')

def verify():
    meta_path=HOST/'prepared.json';manifest_hash=sha(meta_path);meta=json.loads(read(meta_path))
    installed=installation()
    assert meta['compiled'] and meta['source_readback_passed'] and meta['pcode_syntax_passed'] and not meta['validated'] and 'error' not in meta
    assert sha(HOST/'pfe.swf')==meta['candidate_sha256']==PIN
    assert sha(HOST/'pcode/scripts/fe/graph/Grafon.pcode')==PCODE_PIN
    assert installed==meta['installation_before'] and len(installed)==22
    assert all(sha(p)==h for p,h in meta['inputs'].items())
    assert all(sha(HOST/p)==h for p,h in meta['readback_files'].items())
    handoff=json.loads(read(V3/'handoff.json'))
    assert all(sha(V3/p)==h for p,h in handoff['files'].items())
    assert set(meta['import_sources'])=={'fe/graph/Grafon.as'}
    assert sha(HOST/'import/fe/graph/Grafon.as')==meta['import_sources']['fe/graph/Grafon.as']==sha(V3/'src/fe/graph/Grafon.as')
    source=read(V3/'src/fe/graph/Grafon.as');before=read(HOST/'before/scripts/fe/graph/Grafon.as');after=read(HOST/'after/scripts/fe/graph/Grafon.as')
    c.verify_source((V3/'src/fe/graph/Grafon.as').read_bytes())
    readback=c.verify_readback(before,after,source)
    pcode=read(HOST/'pcode/scripts/fe/graph/Grafon.pcode');facts,method=c.pcode_facts(pcode)
    assert facts['method_pcode_sha256']==METHOD_PIN and method==read(HOST/'sceneEnsure.pcode')
    flow,parsed=stack_cfg(method);identity=error_identity(method,parsed);clock=bindings(pcode,method,after)
    representatives={}
    for name in ('MainFE','fe.World','fe.loc.Game','fe.loc.Land','fe.loc.Location','fe.inter.Camera','fe.inter.GUI'):
        rel=Path(*name.split('.')).with_suffix('.as');a=normalized(read(HOST/'before/scripts'/rel));b=normalized(read(HOST/'after/scripts'/rel))
        assert a==b,name
        representatives[name]=hashlib.sha256(a.encode()).hexdigest()
    base=c.prepare.BASE/'pfe.swf';oldtags=swf_tags(base);newtags=swf_tags(HOST/'pfe.swf');assert len(oldtags)==len(newtags)
    changed=[]
    for index,(old,new) in enumerate(zip(oldtags,newtags)):
        assert old[0]==new[0]
        if old!=new:assert old[0] in (72,82);changed.append(index)
    assert changed==meta['changed_code_tags'] and movie_header(base)==movie_header(HOST/'pfe.swf')
    assert normalized(read(HOST/'before-classes.txt'))==normalized(read(HOST/'after-classes.txt'))
    for name in ('before.log','import.log','after.log','pcode.log','before-classes.txt','after-classes.txt'):
        for p in (HOST/name,HOST/(name+'.stderr.log')):
            assert not any(x in read(p) for x in ('SEVERE:','Unknown preprocessor instruction','Exception in thread')),str(p)
    assert installation()==installed and sha(meta_path)==manifest_hash
    assert all(sha(p)==h for p,h in meta['inputs'].items())
    return dict(kind='diagnostic-paint-host03-independent-recheck',candidate_sha256=PIN,builder_manifest_sha256=manifest_hash,
       compiled=True,source_readback_passed=True,pcode_bindings_passed=True,exception_cfg_passed=True,validated=True,
       diagnostic_only=True,installation_unchanged=True,source_unchanged=True,builder_manifest_unchanged=True,
       air_started=False,installed=False,gameplay_qualified=False,performance_qualified=False,
       source_readback=readback,pcode_facts=facts,stack_cfg=flow,error_identity=identity,clock_bindings=clock,
       representative_classes=representatives,changed_code_tags=changed,non_code_tags_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True,
       inputs={**meta['inputs'],str(HOST/'pfe.swf'):PIN,str(meta_path):manifest_hash},readback_files={str(HOST/p):h for p,h in meta['readback_files'].items()},
       source_handoff_sha256=sha(V3/'handoff.json'),audit_script_sha256=sha(__file__),
       primary_exception_semantics='https://github.com/adobe/avmplus/blob/master/core/Verifier.cpp',
       limitations=['Admission is for isolated diagnostic sampling only, not deployment.',
          'Static audit does not measure frame time or prove the loading-time target.',
          'No-subscriber path still has compiler activation/try overhead; it is not allocation-free.'])

if __name__=='__main__':
    assert not OUT.exists(),'Preserve existing independent receipt'
    result=verify();OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('candidate_sha256','compiled','source_readback_passed','pcode_bindings_passed','exception_cfg_passed','validated','installation_unchanged','source_unchanged')},ensure_ascii=False))
