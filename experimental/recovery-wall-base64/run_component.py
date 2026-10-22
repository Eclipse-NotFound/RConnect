"""Original component runner; only freeze the immutable natural JSON fixture too."""
import importlib.util,sys
from pathlib import Path
from prepare import HERE,ROOT,sha,verify
def main():
    verify();sys.path.insert(0,str(ROOT/'tools/validation'))
    source=ROOT/'tools/validation/run_recovery_component.py'
    spec=importlib.util.spec_from_file_location('wall_base64_generic_component',source)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    def inventory(root):
        return {p.relative_to(root).as_posix():sha(p) for p in sorted(root.rglob('*'))
                if p.is_file() and (p.suffix=='.as' or p.name=='natural-payloads.json')}
    module.inventory=inventory
    pinned={p:sha(p) for p in (Path(__file__),HERE/'prepare.py',HERE/'inputs.json',source)}
    try:module.main()
    finally:
        for p,h in pinned.items():assert sha(p)==h,p
        verify()
if __name__=='__main__':main()
