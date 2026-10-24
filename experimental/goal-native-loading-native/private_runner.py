"""Original shared runner plus one opt-in completion prefix, in this directory only."""
from pathlib import Path
import importlib.util,sys
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
_here=Path(__file__).resolve().parent
_spec=importlib.util.spec_from_file_location('loading_runtime_recipe',_here/'recipe.py')
_recipe=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(_recipe)
_recipe.check()
sys.path.insert(0,str(_recipe.ROOT/'tools'))
# Native ROOT derives from the actual shared runner, not this adapter directory.
__file__=str(_recipe.SHARED)
exec(compile(_recipe.runner_source(),str(_here/'adapted-runner.py.txt'),'exec'),globals())
