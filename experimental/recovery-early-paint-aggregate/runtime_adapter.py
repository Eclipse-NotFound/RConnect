"""Exact in-memory adapters; unchanged owned AIR runner, root invocation only."""
from pathlib import Path
import types
import baseline

HERE=Path(__file__).resolve().parent
PRIOR=HERE.parent/'recovery-early-paint-native/adapt.py'
PRIOR_SHA='4cfb3b069912628c202b3ba91d26d7adec8566db982a1b910571a30149703d5d'
RUNNER=HERE.parent/'recovery-early-revisit-frozen-rv/native_runner.py'
RUNNER_SHA='d311e5f5104095492949057184725a789a80c811bc9d9780383951281ac005f2'
OLD_RUNNER='RUNNER=Path(__file__).resolve().parent.parent/"recovery-early-revisit-frozen-rv/native_runner.py"'
NEW_RUNNER='RUNNER=Path(__file__).resolve().parent/"runtime_adapter.py"'
KIND='ensure-work-aggregate-v1'

def original_paint_source():
    assert baseline.sha(PRIOR)==PRIOR_SHA
    text=baseline.replace_once(PRIOR.read_text(encoding='utf-8-sig'),
       'from native_inputs import EXIT,sha','# Exact dependency injection only')
    scope=dict(__file__=str(PRIOR),__name__='aggregate_prior_paint_adapter',EXIT=baseline.EXIT,sha=baseline.sha)
    exec(compile(text,str(PRIOR),'exec'),scope)
    return scope['source']()

def outer_source():
    text=original_paint_source()
    assert text.count("'ensure-work'")==2
    text=text.replace("'ensure-work'",repr(KIND),2)
    return baseline.replace_once(text,OLD_RUNNER,NEW_RUNNER)

def runner_source():
    assert baseline.sha(RUNNER)==RUNNER_SHA
    return RUNNER.read_text(encoding='utf-8-sig')

def main():
    # Starting this child directly still requires final exact runtime admission.
    from native_inputs import verify_tools
    verify_tools()
    scope=dict(__file__=__file__,__name__='aggregate_unchanged_owned_air_runner')
    exec(compile(runner_source(),str(RUNNER),'exec'),scope)
    scope['main']()

if __name__=='__main__':main()
