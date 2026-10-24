"""Write only the inspectable text expansion/diff/manifest in this new directory."""
from pathlib import Path
import ast,difflib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('ui_runtime_v2_source',HERE/'run.py')
entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
def main():
    assert sys.argv[1:]==[]
    text=entry.adapted();ast.parse(text)
    with (HERE/'adapted-entry.py.txt').open('x',encoding='utf8',newline='\n') as f:f.write(text)
    diff=''.join(difflib.unified_diff(entry.SOURCE.read_text('utf8').splitlines(True),text.splitlines(True),
         fromfile='frozen-native/run.py',tofile='native-v2/adapted-entry.py.txt'))
    with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
    m=dict(kind='native-loading-runtime-host-verifier-v2',replacements=2,original_sha256=entry.SOURCE_SHA,
           original_manifest_sha256=entry.OLD_MANIFEST_SHA,host_verifier=entry.V2_PINS,
           files={p.name:entry.sha(p) for p in sorted(HERE.iterdir()) if p.is_file()},air_started=False,xml_parsed=False)
    with (HERE/'source-manifest.json').open('x',encoding='utf8') as f:json.dump(m,f,indent=2);f.write('\n')
    entry.exact_pins()
    print('Prepared new text only; no candidate verification, XML parsing, JVM or AIR')
if __name__=='__main__':main()
