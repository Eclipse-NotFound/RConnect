"""Root-only exact runtime freeze; reuse full existing host/native admission."""
from pathlib import Path
import baseline
HERE=Path(__file__).resolve().parent
PRIOR=HERE.parent/'recovery-early-paint-native/freeze.py'
def main():
    from sampler_admission import verify_component,verify_sampler_inputs
    verify_component();verify_sampler_inputs()
    assert baseline.sha(PRIOR)=='a3a25780b152997c29695ccbd2183b820b5fd344d6328bb87215032d44b884e8'
    text=PRIOR.read_text(encoding='utf-8-sig')
    text=baseline.replace_once(text,"out=HERE/'inputs.json'","out=HERE/'runtime-inputs.json'")
    text=baseline.replace_once(text,"p.name!='inputs.json'","p.name not in ('inputs.json','runtime-inputs.json')")
    text=baseline.replace_once(text,"DRIVER/'audit_profile.py'","DRIVER/'audit_runtime.py'")
    text=baseline.replace_once(text,'    files.update(host_files)',
        '    files.update(host_files)\n    files.update(read(HERE/"inputs.json")["originals"])')
    scope=dict(__file__=__file__,__name__='tail_exact_runtime_freeze')
    exec(compile(text,str(PRIOR),'exec'),scope);scope['main']()
if __name__=='__main__':main()
