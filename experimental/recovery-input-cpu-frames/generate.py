"""Reuse the pinned source-only generator; change only the helper's Stage argument."""
import importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
PREVIOUS=ROOT/'experimental/recovery-input-cpu-profile'
spec=importlib.util.spec_from_file_location('original_input_cpu_generate',PREVIOUS/'generate.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
BASE=base.BASE;BASE_PIN=base.BASE_PIN;strip=base.strip;sha=base.sha;read=base.read

def main():
    assert sha(PREVIOUS/'generate.py')=='930668ef09bf3911c462517cb73ae03f4fe1066d069c5106123a5e5bbd793995'
    original_after=base.after
    def after(source,needle,addition):
        if 'new RoomInputCpuProfile(' in addition:
            assert addition.count('new RoomInputCpuProfile(')==1
            addition=addition.replace('new RoomInputCpuProfile(','new RoomInputCpuProfile(mod.stage,',1)
        return original_after(source,needle,addition)
    original_here=base.HERE
    try:
        base.HERE=HERE;base.after=after;base.main()
    finally:
        base.HERE=original_here;base.after=original_after

if __name__=='__main__':main()
