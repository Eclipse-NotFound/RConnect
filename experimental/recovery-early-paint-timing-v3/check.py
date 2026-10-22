"""Offline-only source and narrow FFDec readback checks. No JVM/AIR."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys
import prepare

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(prepare.ROOT/'experimental/recovery-early-travel'))
from prepare_host import methods,token

def verify_source(value):
    before=prepare.SOURCE.read_bytes()
    assert value==prepare.transform(before), 'Prepared diagnostic source differs'
    source=prepare.lf(value)
    assert '§§' not in source,'No pseudo-instruction may be imported'
    pseudo,known=prepare.water_proof()
    old=methods(prepare.lf(prepare.v2.transform(before)))
    b,a=methods(before.decode('utf-8').replace('\r\n','\n')),methods(source)
    assert len(b)==len(a)==91 and set(b)==set(a)
    assert [n for n in b if a[n]!=b[n]]==['sceneEnsure','sceneDrawSteps']
    assert a['sceneDrawSteps']==known
    assert all(a[n]==old[n] for n in a if n!='sceneEnsure')
    assert shell(source)==shell(prepare.lf(prepare.v2.transform(before)))
    assert 'finally' not in a['sceneEnsure'] and a['sceneEnsure'].count('return;')==2
    return dict(methods=91,unchanged_import_methods=89,changed_logic_methods=['sceneEnsure'],
                restored_import_methods=['sceneDrawSteps'],pseudo_instructions_remaining=0,
                source_sha256=prepare.sha(value))

def shell(source):
    for body in methods(source).values():
        source=source.replace(body,'__method__',1)
    return token(source)

DECLARATIONS=[('paintObserver','Function'),('paintWorld','Object'),
    ('paintGame','Object'),('paintLoc','Location'),('paintStarted','int'),
    ('paintStartedWall','Number'),('paintResident','int'),('paintPreload','Boolean'),
    ('paintWorldRenderer','Boolean'),('paintWorldLoc','Boolean'),
    ('paintCompleted','Boolean'),('paintFailed','Boolean'),('paintFailure','*'),
    ('paintFinished','int'),('paintFinishedWall','Number')]
KEYS='phase preload initial left top width height started finished startedWall finishedWall residentBefore residentAfter completed sameWorld sameGame sameLoc worldRendererAtStart worldRendererAtEnd worldLocAtStart worldLocAtEnd'.split()

def ensure_readback_form(expected,hoist=False,quote=False):
    """Only explicit declarations, keeping initializers at their exact positions."""
    value=token(expected);signature,body=value.split('{',1);prefix=''
    if hoist:
        for name,typ in DECLARATIONS:
            declaration='var'+name+':'+typ
            assert body.count(declaration)==1,name
            prefix+=declaration+';'
            if declaration+'=' in body:body=body.replace(declaration+'=',name+'=',1)
            else:
                assert declaration+';' in body,name
                body=body.replace(declaration+';','',1)
    if quote:
        head,payload=body.split('paintObserver(this,paintWorld,paintGame,paintLoc,{',1)
        payload,tail=payload.split('});',1)
        for key in KEYS:
            assert len(list(re.finditer(r'(^|,)'+key+':',payload)))==1,key
            payload=re.sub(r'(^|,)'+key+':',lambda m:m[1]+'"'+key+'":',payload,count=1)
        body=head+'paintObserver(this,paintWorld,paintGame,paintLoc,{'+payload+'});'+tail
    return signature+'{'+prefix+body

def verify_readback(before,after,expected):
    # The only permitted decompiler pseudo representation is this complete,
    # byte-pinned original method, never arbitrary pseudo-op stripping.
    pseudo,known=prepare.water_proof()
    b,a,e=methods(before),methods(after),methods(expected)
    assert len(b)==len(a)==len(e)==91 and set(b)==set(a)==set(e)
    assert token(b['sceneDrawSteps'])==token(pseudo)
    assert token(e['sceneDrawSteps'])==token(known)
    assert '§§' not in after.replace(a['sceneDrawSteps'],'__exact_reviewed_water_loop__',1)
    assert token(a['sceneDrawSteps']) in (token(pseudo),token(known)),'Changed anonymous water loop is not the exact known representation'
    for name in a:
        if name=='sceneDrawSteps':continue
        if name=='sceneEnsure':
            allowed={ensure_readback_form(e[name],hoist,quote) for hoist in (False,True) for quote in (False,True)}
            assert token(a[name]) in allowed,'Only the explicit 15 declaration hoists and 21 callback key quotes are allowed'
        else:assert token(a[name])==token(b[name]),('method readback',name)
    assert shell(after)==shell(expected),'Unreviewed field/import/signature change'
    return dict(exact_methods=90,exact_known_water_method_representations=2,unchanged_semantic_methods=90,field_shell_exact=True,
                explicit_declaration_hoists_allowed=15,exact_callback_key_quotes_allowed=21,
                lexical_readback_only=True,exception_semantics_qualified=False)

def pcode_facts(text):
    """Extract evidence, not a generic exception-equivalence permission.

    Preserve the original wildcard import. Multiname spelling is checked against
    unchanged calls; actual trait/scope resolution remains independently reviewed.
    Exception coverage must be reviewed from
    the actual compiler result; its CFG/rethrow correctness is not inferred
    from source text or a mere count of catch entries.
    """
    anchor=re.search(r'\bfunction sceneEnsure\(',text)
    assert anchor,'sceneEnsure p-code missing'
    start=text.index('\n',anchor.start())
    end=text.index('end ; method',start)+len('end ; method')
    method=text[anchor.start():end]
    lines=[line.strip() for line in method.splitlines()]
    timer=[s for s in lines if '"getTimer"' in s]
    dates=[s for s in lines if '"Date"' in s]
    timer_lookup='findpropstrict QName(PackageNamespace("flash.utils"),"getTimer")'
    timer_call='callproperty QName(PackageNamespace("flash.utils"),"getTimer"), 0'
    lookups=[s for s in timer if s.startswith('findpropstrict ')]
    calls=[s for s in timer if s.startswith('callproperty ') and s.endswith(', 0')]
    assert len(timer)==4 and len(lookups)==len(calls)==2,'Exactly two timer lookup/call pairs required'
    assert len(set(lookups))==len(set(calls))==1 and lookups[0].removeprefix('findpropstrict ')==calls[0].removeprefix('callproperty ')[:-3]
    if set(timer)=={timer_lookup,timer_call}:timer_form='direct-flash.utils-QName'
    else:
        other={line.strip() for line in text.replace(method,'',1).splitlines()}
        assert lookups[0].startswith('findpropstrict Multiname("getTimer",[')
        assert 'PackageNamespace("flash.utils")' in lookups[0] and set(timer)<=other
        timer_form='exact-Multiname-shared-with-unchanged-calls'
    date_lookup='findpropstrict QName(PackageNamespace(""),"Date")'
    date_construct='constructprop QName(PackageNamespace(""),"Date"), 0'
    assert dates and all(s in (date_lookup,date_construct) for s in dates),'Date is not the global zero-argument constructor'
    assert dates.count(date_lookup)==dates.count(date_construct)>=2,'Missing/unpaired Date constructor'
    assert not any('"flash"' in s and s.startswith(('findpropstrict','findproperty','getlex')) for s in lines),'Global flash property chain is forbidden'
    exceptions=[s for s in lines if s.startswith('try from ')]
    assert len(exceptions)==3,'Expected capture/native/observer catch only'
    assert any('"paintCaptureError"' in s for s in exceptions),'Start observer isolation is absent'
    assert any('"paintObserverError"' in s for s in exceptions),'End observer isolation is absent'
    assert any('"paintNativeError"' in s for s in exceptions),'Native work explicit catch is absent'
    assert not any(' name null ' in (' '+s+' ') for s in exceptions),'Unexpected implicit finally catch'
    assert not any(s.startswith('lookupswitch ') for s in lines),'No finally selector is allowed'
    native_calls=[s for s in lines if s.startswith(('callproperty','callpropvoid')) and any('"'+n+'"' in s for n in ('scenePreloadAll','sceneEnsureUpcoming'))]
    assert len(native_calls)==2,'Both original drawing branches must remain present exactly once'
    assert any(s=='throw' for s in lines),'Original work rethrow path is absent'
    return dict(method_pcode_sha256=hashlib.sha256(method.encode()).hexdigest(),
                timer_calls=len(calls),timer_form=timer_form,global_date_constructors=dates.count(date_construct),
                native_calls=native_calls,exception_table=exceptions,
                binding_semantics_review_required=True,binding_semantics_qualified=False,
                exception_semantics_review_required=True,exception_semantics_qualified=False),method

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--before',type=Path);ap.add_argument('--after',type=Path);ap.add_argument('--pcode',type=Path)
    ap.add_argument('--output',type=Path)
    args=ap.parse_args()
    source=prepare.TARGET.read_bytes();result=verify_source(source)
    rejected=[]
    mutations={
       'waiting-return':source.replace(b'if(this.rconnectRasterWaiting())',b'if(false)',1),
       'preload-shortcut':source.replace(b'if(this.scenePreload && this.sceneResident ==',b'if(false && this.sceneResident ==',1),
       'duplicate-native-call':source.replace(b'this.scenePreloadAll();',b'this.scenePreloadAll();this.scenePreloadAll();',1),
       'swallowed-native-error':source.replace(b'            throw paintFailure;',b'            return;',1),
       'null-or-undefined-swallowed':source.replace(b'if(paintFailed)',b'if(paintFailure)',1),
       'replaced-native-error':source.replace(b'paintFailure = paintNativeError;',b'paintFailure = null;',1),
       'timer-after-observer':source.replace(b'var paintFinished:int = int(getTimer());',b'var paintFinished:int = 0;',1),
       'missing-fault-signal':source.replace(b'++rconnectPaintTimingFaults;',b';',1),
       'observer-not-captured':source.replace(b'paintObserver(this,paintWorld',b'rconnectPaintTimingBridge(this,paintWorld',1),
       'wrong-world-identity':source.replace(b'sameWorld:World.w === paintWorld',b'sameWorld:true',1),
       'unrelated-scene-tick':source.replace(b'this.sceneCullSurfaces();',b';',1),
       'wrong-water-j-increment':source.replace(b'                  j++;',b'                  j+=2;',1),
       'pseudo-reintroduced':source.replace(b'                  j++;',prepare.PSEUDO_J.encode(),1),
    }
    for name,bad in mutations.items():
        assert bad!=source,name
        try:verify_source(bad)
        except AssertionError:rejected.append(name)
        else:raise AssertionError('Mutation accepted: '+name)
    result['source_mutations_rejected']=rejected
    before=prepare.lf(prepare.SOURCE.read_bytes());expected=prepare.lf(source)
    pseudo,known=prepare.water_proof();canonical=expected.replace(known,pseudo,1)
    verify_readback(before,expected,expected)
    verify_readback(before,canonical,expected)
    em=methods(expected)['sceneEnsure']
    mapped=em.split('{',1)[0]+'{\n'+ensure_readback_form(em,True,True).split('{',1)[1]
    hoisted=expected.replace(em,mapped,1)
    verify_readback(before,hoisted,expected)
    readback_bad={
       'wrong-pseudo-addend':canonical.replace('Number(_loc1_.j) + 1','Number(_loc1_.j) + 2',1),
       'wrong-pseudo-target':canonical.replace('_loc1_ = §§findproperty(i);','_loc1_ = §§findproperty(j);',1),
       'extra-pseudo-elsewhere':expected.replace('this.sceneCullSurfaces();','§§findproperty(z);this.sceneCullSurfaces();',1),
       'changed-water-body':canonical.replace('self.loc.tileKontur(i,j,t);','self.loc.tileKontur(i,j,null);',1),
       'changed-water-closure-scope':canonical.replace('var j:* = undefined;','var j:Number = 0;',1),
       'changed-hoisted-type':hoisted.replace('varpaintFailure:*;','varpaintFailure:Object;',1),
       'changed-hoisted-initializer':hoisted.replace('paintFailed=false;','paintFailed=true;',1),
    }
    rejected_readback=[]
    for name,bad in readback_bad.items():
        assert bad!=canonical and bad!=expected,name
        try:verify_readback(before,bad,expected)
        except AssertionError:rejected_readback.append(name)
        else:raise AssertionError('Readback mutation accepted: '+name)
    result['readback_mutations_rejected']=rejected_readback
    if args.before or args.after:
        assert args.before and args.after
        result['readback']=verify_readback(args.before.read_text(encoding='utf-8-sig'),args.after.read_text(encoding='utf-8-sig'),source.decode())
    if args.pcode:
        facts,body=pcode_facts(args.pcode.read_text(encoding='utf-8-sig'))
        result['pcode']=facts
        if args.output:args.output.with_suffix('.sceneEnsure.pcode').write_text(body,encoding='utf-8')
    result.update(compiled=False,runtime_qualified=False,performance_qualified=False)
    if args.output:args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__':main()
