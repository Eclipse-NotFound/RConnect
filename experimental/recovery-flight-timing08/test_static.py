"""Pure Python consistency/negative tests; never starts a child process."""
import ast
import importlib.util
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent


def load(name):
    spec=importlib.util.spec_from_file_location('timing08_'+name,HERE/(name+'.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


def main():
    for p in HERE.glob('*.py'):ast.parse(p.read_text(encoding='utf-8'),str(p))
    prep=load('prepare');manifest=prep.check_overlay();prep.check_baseline();recipe=load('make_overlay')
    runner=load('run')
    assert callable(runner.verify) and callable(runner.run) and runner.prepare.BASE==prep.BASE
    assert len(manifest['files'])==5 and all('RoomCodec' not in x['overlay'] and 'WallImpactVisuals' not in x['overlay'] for x in manifest['files'])
    for item in manifest['files']+[manifest['driver']]:
        assert recipe.plain((HERE/item['overlay']).read_text(encoding='utf-8'))==Path(item['source']).read_text(encoding='utf-8')
    assert set(manifest['driver_support'])=={'NativeFlightBounds.as'}
    for name,digest in manifest['driver_support'].items():
        assert prep.sha(prep.DRIVERS/'tests'/name)==digest
        assert not (HERE/'tests'/name).exists(), 'Frozen support must not be shadowed by mutable fixture input'
    assert 'NativeFlightBounds.empty(screen)' in (HERE/'tests/NativeFlightContinuityTestDoc.as').read_text(encoding='utf-8')
    assert 'NativeFlightBounds.evaluate(nativeFrames,frames)' in (HERE/'tests/NativeFlightContinuityTestDoc.as').read_text(encoding='utf-8')
    source=(HERE/'tests/FlightDiagnosticRecorder.as').read_text(encoding='utf-8')
    assert source.index('Log.d(')>source.index('public function finish()')
    assert 'MAX_ROWS:int=32768' in source and 'WIDTH:int=24' in source
    assert 'System.gc' not in source and 'payloadIds' not in source
    diagnostic='\n'.join((HERE/x).read_text(encoding='utf-8') for x in manifest['new_files'])
    assert not any(x in diagnostic for x in ['RoomCodec.timingEnabled','BitmapData','getPixels','JSON.stringify(state)','System.pause'])
    for p in list((HERE/'tests').glob('FlightDiagnosticRecorder.as'))+[HERE/'src/rconnect/diagnostics/FlightDiagnostics.as']:
        assert not re.search(r'\.(?:case|class|return|throw|try|catch|finally|new|delete|if|else|for|while|do|break|continue)\b',p.read_text(encoding='utf-8'))
    # Verify brace wrapping around return/throw/comments/string braces restores text.
    sample='private function f(e:Object):void { var s:String="}"; /* } */ if(e) return; throw new Error("{"); }'
    wrapped=recipe.span(sample,'f',1)
    assert recipe.plain(wrapped)==sample and 'finally' in wrapped
    analysis=load('analyze')
    header={'schema':8,'width':24,'capacity':32768,'numericBytes':6291456,'payloads':0,'codecDiagnostics':False,'rows':1}
    row=[10,10,0,0,-1,0,0]+[None]*17
    lines=['FLIGHT TIMING08 HEADER '+json.dumps(header),'FLIGHT TIMING08 ROWS '+json.dumps({'from':0,'rows':[row]}),
           'FLIGHT TIMING08 DONE '+json.dumps({'rows':1})]
    assert analysis.parse('\n'.join(lines))[1]==[row]
    for broken in [lines[:-1],lines+[lines[-1]], [lines[0],lines[1].replace('"from": 0','"from": 1'),lines[2]],
                   [lines[0].replace('"payloads": 0','"payloads": 1')]+lines[1:]]:
        rejected=False
        try:analysis.parse('\n'.join(broken))
        except (AssertionError,ValueError,KeyError):rejected=True
        assert rejected
    assert analysis.union_ms([(1,4),(2,6),(7,9)],0,8)==6
    rows=[]
    def add(kind,case,*payload):
        rows.append([kind,len(rows),case,0,case,0]+list(payload)+[None]*(18-len(payload)))
    for case in range(8):
        add(10,case,1,case)
        for phase in [1,2,3,4]:add(9,case,phase)
        for method in [1,3,10,11,12,13]:add(6,case,method,0,0,1,1)
        add(7,case,0,1,1,1,0,0)
    add(3,7,1,1,1,1,0,1,1,0,1,0);add(4,7,1,0,0,4,0,1,1,0,0,0,1,1,1,0)
    full=dict(header,role='join',diagnosticOnly=True,performanceQualified=False,complete=True,
              dropped=0,hookErrors=0,memoryErrors=0,identityOverflow=False,occupied=False)
    done={'diagnosticOnly':True,'performanceQualified':False,'complete':True,'round':7}
    assert analysis.summarize(full,rows,done,'join')['complete']
    assert not analysis.summarize(dict(full,dropped=1),rows,done,'join')['complete']
    assert not analysis.summarize(full,[r for r in rows if r[4]!=4],done,'join')['complete']
    assert not analysis.summarize(full,rows,done,'host')['complete']
    print(json.dumps({'static_passed':True,'overlays_stripped_equal':5,'driver_restored':True,
                      'frozen_driver_support':list(manifest['driver_support']),
                      'negative_export_cases':4,'negative_completeness_cases':3,'numeric_buffer_mib':6,'compiled':False,'AIR_started':False}))


if __name__=='__main__':main()
