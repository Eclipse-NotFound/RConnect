"""Use the unchanged recovery13/FD92 native runner, replacing only driver audit."""
import importlib.util,sys
from pathlib import Path
from prepare import ROOT,HERE,sha,verify_driver

ORIGINAL=ROOT/'experimental/recovery-first-raster-native'
RUNNER_SHA='69d6e237b642821479f6d05c9af9a74f7cd62a4884578d4072fbeb7b7402ea6a'

def main():
    source=ORIGINAL/'run_native.py'
    assert sha(source)==RUNNER_SHA,'Underlying runner changed'
    # Candidate/FD92/22-input/memory/600s/registration/COOP assertions all remain
    # in the original runner. The only replacement accepts this pinned external
    # driver, whose original suite and assertion bodies are verified byte-exact.
    sys.path.insert(0,str(ORIGINAL))
    sys.path.insert(0,str(ROOT/'tools/validation'))
    spec=importlib.util.spec_from_file_location('room_entry_unchanged_native_runner',source)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.verify_driver=verify_driver
    pinned={p:sha(p) for p in (Path(__file__),HERE/'prepare.py',HERE/'generate.py',source)}
    try:module.main()
    finally:
        for p,h in pinned.items():assert sha(p)==h,p

if __name__=='__main__':main()
