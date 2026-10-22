"""Root-owned freeze after joint source/driver review; never starts AIR/JVM."""
from pathlib import Path
import baseline

HERE=Path(__file__).resolve().parent
PRIOR=HERE.parent/'recovery-early-paint-native/freeze.py'

def main():
    import native_inputs as admission
    pins=admission.read(PRIOR.parent/'inputs.json')
    assert baseline.sha(PRIOR)==pins['sources']['freeze.py']
    text=PRIOR.read_text(encoding='utf-8-sig')
    text=baseline.replace_once(text,"out=HERE/'inputs.json'","out=HERE/'runtime-inputs.json'")
    # Preserve construction provenance inputs.json; exclude only the new output.
    text=baseline.replace_once(text,"p.name!='inputs.json'","p.name not in ('inputs.json','runtime-inputs.json')")
    text=baseline.replace_once(text,'    files.update(host_files)',
       '    files.update(host_files)\n    files.update({str(p):h for p,h in _baseline.PINS.items()})\n    files.update({str(_old_native/n):h for n,h in read(_old_native/"inputs.json")["sources"].items()})')
    scope=dict(__file__=__file__,__name__='aggregate_exact_runtime_freeze',_baseline=baseline,_old_native=PRIOR.parent)
    exec(compile(text,str(PRIOR),'exec'),scope)
    scope['main']()

if __name__=='__main__':main()
