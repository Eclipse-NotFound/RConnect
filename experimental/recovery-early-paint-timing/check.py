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
    source=value.decode('utf-8').replace('\r\n','\n')
    assert source.replace(prepare.NEW,prepare.OLD,1).replace(prepare.ADDED,prepare.SLOT,1)==before.decode('utf-8').replace('\r\n','\n')
    b,a=methods(before.decode('utf-8').replace('\r\n','\n')),methods(source)
    assert len(b)==len(a)==91 and set(b)==set(a)
    assert [n for n in b if a[n]!=b[n]]==['sceneEnsure']
    return dict(methods=91,unchanged_methods=90,changed_methods=['sceneEnsure'],source_sha256=prepare.sha(value))

def shell(source):
    for body in methods(source).values():
        source=source.replace(body,'__method__',1)
    return token(source)

def verify_readback(before,after,expected):
    assert '§§' not in after
    b,a,e=methods(before),methods(after),methods(expected)
    assert len(b)==len(a)==len(e)==91 and set(b)==set(a)==set(e)
    for name in a:
        assert token(a[name])==token(e[name] if name=='sceneEnsure' else b[name]),('method readback',name)
    assert shell(after)==shell(expected),'Unreviewed field/import/signature change'
    return dict(exact_methods=91,unchanged_methods=90,field_shell_exact=True,
                lexical_readback_only=True,exception_semantics_qualified=False)

def pcode_facts(text):
    """Extract evidence, not a generic exception-equivalence permission.

    Timer and Date binding are strict. Exception coverage must be reviewed from
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
    assert timer and all(s in (timer_lookup,timer_call) for s in timer),'getTimer is not the direct flash.utils package function'
    assert timer.count(timer_lookup)==timer.count(timer_call)>=2,'Missing/unpaired timer lookup/call'
    date_lookup='findpropstrict QName(PackageNamespace(""),"Date")'
    date_construct='constructprop QName(PackageNamespace(""),"Date"), 0'
    assert dates and all(s in (date_lookup,date_construct) for s in dates),'Date is not the global zero-argument constructor'
    assert dates.count(date_lookup)==dates.count(date_construct)>=2,'Missing/unpaired Date constructor'
    assert not any('"flash"' in s and s.startswith(('findpropstrict','findproperty','getlex')) for s in lines),'Global flash property chain is forbidden'
    exceptions=[s for s in lines if s.startswith('try from ')]
    assert exceptions,'Original work finally coverage is absent'
    assert any('"paintCaptureError"' in s for s in exceptions),'Start observer isolation is absent'
    assert any('"paintObserverError"' in s for s in exceptions),'End observer isolation is absent'
    assert any(' name null ' in (' '+s+' ') for s in exceptions),'Native work finally catch is absent'
    native_calls=[s for s in lines if s.startswith(('callproperty','callpropvoid')) and any('"'+n+'"' in s for n in ('scenePreloadAll','sceneEnsureUpcoming'))]
    assert len(native_calls)==2,'Both original drawing branches must remain present exactly once'
    assert any(s=='throw' for s in lines),'Original work rethrow path is absent'
    return dict(method_pcode_sha256=hashlib.sha256(method.encode()).hexdigest(),
                direct_timer_calls=timer.count(timer_call),global_date_constructors=dates.count(date_construct),
                native_calls=native_calls,exception_table=exceptions,
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
       'swallowed-native-error':source.replace(b'         finally\r\n',b'         catch(ignored:*){} finally\r\n',1),
       'timer-after-observer':source.replace(b'var paintFinished:int = int(getTimer());',b'var paintFinished:int = 0;',1),
       'missing-fault-signal':source.replace(b'++rconnectPaintTimingFaults;',b';',1),
       'observer-not-captured':source.replace(b'paintObserver(this,paintWorld',b'rconnectPaintTimingBridge(this,paintWorld',1),
       'wrong-world-identity':source.replace(b'sameWorld:World.w === paintWorld',b'sameWorld:true',1),
       'unrelated-scene-tick':source.replace(b'this.sceneCullSurfaces();',b';',1),
    }
    for name,bad in mutations.items():
        assert bad!=source,name
        try:verify_source(bad)
        except AssertionError:rejected.append(name)
        else:raise AssertionError('Mutation accepted: '+name)
    result['source_mutations_rejected']=rejected
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
