"""Generate inspectable source expansions and pins in this directory only."""
from pathlib import Path
import ast,difflib,importlib.util,json,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('selfecho_native_source',HERE/'run.py')
entry=importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
def main():
    assert sys.argv[1:]==[]
    sources={'adapted-run.py.txt':entry.expanded_run(),'adapted-build.py.txt':entry.expanded_build()}
    before={'adapted-run.py.txt':(entry.OLD/'run.py').read_text('utf8'),
            'adapted-build.py.txt':entry.function_text(entry.OLD/'build.py','inputs')+'\n'+entry.function_text(entry.OLD/'build.py','verify')}
    diff=''
    for name,text in sources.items():
        ast.parse(text)
        with (HERE/name).open('x',encoding='utf8',newline='\n') as f:f.write(text)
        diff+=''.join(difflib.unified_diff(before[name].splitlines(True),text.splitlines(True),fromfile='original/'+name,tofile='selfecho/'+name))
    with (HERE/'source.diff').open('x',encoding='utf8',newline='\n') as f:f.write(diff)
    paths=[folder/n for folder,pins in ((entry.OLD,entry.OLD_PINS),(entry.ENV,entry.ENV_PINS),(entry.DRIVERS,entry.DRIVER_PINS)) for n in pins]
    paths += [entry.RECIPE/n for n in ('build.py','prepare.py','source-manifest.json')]
    environment=entry.load(entry.ENV/'run.py','selfecho_environment_pin_reader')
    paths.append(environment.RV_RECEIPT)
    history=entry.read(entry.OLD/'environment.json')['installation']
    for n in entry.read(environment.RV_RECEIPT)['before']:
        if n not in history:paths.append(entry.ROOT.parents[1]/n)
    assert all(p.is_file() for p in paths),'Wait for the actual frozen product builder'
    manifest=dict(kind='self-echo-native-motion-binding-v1',run_replacements=3,build_replacements=3,
                  files={p.name:entry.sha(p) for p in sorted(HERE.iterdir()) if p.is_file()},
                  inputs={str(p):entry.sha(p) for p in paths},compiled=False,air_started=False)
    with (HERE/'source-manifest.json').open('x',encoding='utf8',newline='\n') as f:json.dump(manifest,f,indent=2);f.write('\n')
    entry.inputs();print('Prepared source only; no JVM/AIR or candidate admission')
if __name__=='__main__':main()
