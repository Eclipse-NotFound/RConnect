"""Thin binding to the unchanged roomfix5 bounded compiler; root executes it."""
from pathlib import Path
import importlib.util, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent

def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path)
 module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def main():
 prepared=load('roomperf_source_prepare',HERE/'prepare.py')
 prepared.verify()
 # The original builder imports BASE/inventory/sha from a module named prepare.
 # Supply this exact verified binding temporarily; never modify its old file.
 absent=object();prior=sys.modules.get('prepare',absent);old_argv=sys.argv[:];old_path=sys.path[:]
 try:
  sys.modules['prepare']=prepared
  bounded=load('roomperf_original_bounded_compiler',prepared.DELEGATE)
  bounded.HERE=HERE
  assert bounded.BASE==prepared.BASE and bounded.ROOT==prepared.ROOT
  assert bounded.inventory is prepared.inventory and bounded.sha is prepared.sha
  bounded.main()
 finally:
  sys.argv=old_argv;sys.path[:]=old_path
  if prior is absent:sys.modules.pop('prepare',None)
  else:sys.modules['prepare']=prior
  prepared.verify()
if __name__=='__main__':main()
