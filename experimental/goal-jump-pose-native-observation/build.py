"""Bind the existing bounded compiler to one passive native-jump driver."""
from pathlib import Path
import ast, hashlib, importlib.util, json, sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];M52=ROOT/'build/m52'
OLD=HERE.with_name('goal-three-issues-native');HISTORY=HERE.with_name('goal-self-echo-native')
PINS={'run.py':'8f0ee63334966456c618aee14f862d3f94ecb75baf8bc65636f3b01f95097c48',
 'source-manifest.json':'cfc69dd83d953cf28f732965852bc18f73ed5dfafd469c9556e8caa6d59c7f4d'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text('utf-8-sig'))
def load(p,n):
 spec=importlib.util.spec_from_file_location(n,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def historical():
 for n,h in PINS.items():assert sha(HISTORY/n)==h,n
 h=load(HISTORY/'run.py','jump_observation_historical_binding')
 reference,environment=h.binding();proof=reference.verify(h.DRIVERS)
 return h,reference,environment,proof
def installed():
 # The original implementation hashes actual files, not a supplied historical inventory.
 original=load(OLD/'build.py','jump_observation_actual_inventory')
 return original.installed()
def expanded_verify():
 assert sha(OLD/'build.py')=='8b85f7e63f4b6f4294ef25eef928f21fa5949fb06f521b6e3eaf6d662dc94944'
 h=load(HISTORY/'run.py','jump_observation_function_reader')
 text=h.function_text(OLD/'build.py','verify')
 assert text.count(" assert len(c['commands'])==2")==1
 return text.replace(" assert len(c['commands'])==2"," assert len(c['commands'])==1",1)
def inputs():
 prepared=load(HERE/'prepare.py','jump_observation_source_check');m=prepared.verify()
 h,reference,environment,proof=historical()
 assert (HERE/'adapted-build.py.txt').read_text('utf8')==expanded_verify()
 pins=dict(proof['inputs'])
 pins.update({str(HERE/n):v for n,v in m['files'].items()})
 pins.update({str(HERE/'tests'/n):v for n,v in m['sources'].items()})
 pins[str(HERE/'source-manifest.json')]=sha(HERE/'source-manifest.json')
 return pins
def delegate():
 d=load(OLD/'build.py','jump_observation_original_bounded_compiler')
 d.HERE=HERE;d.CASES={'native-jump':'NativeJumpNetworkTestDoc.as'}
 d.inputs=inputs;d.installed=installed
 exec(compile(expanded_verify(),str(HERE/'adapted-build.py.txt'),'exec'),vars(d))
 return d
def verify(output):
 out=Path(output).resolve()
 assert out.name.startswith('goal-jump-pose-observation-driver-') and out.parent==M52
 assert (out/'compile.json').is_file(),'Driver not compiled'
 proof=delegate().verify(out)
 proof['build_environment']=read(out/'prepared.json')['installation_before']
 proof['runtime_environment']=installed();proof['cursorAvailable']=False
 return proof
def main():
 if '--output' in sys.argv:
  out=(ROOT/sys.argv[sys.argv.index('--output')+1]).resolve()
  assert out.parent==M52 and out.name.startswith('goal-jump-pose-observation-driver-')
 delegate().main()
if __name__=='__main__':main()
