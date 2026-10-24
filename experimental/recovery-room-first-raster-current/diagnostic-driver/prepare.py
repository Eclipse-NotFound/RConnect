"""Compile one scene diagnostic driver against frozen declarations; no AIR/deploy."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent; ROOT = HERE.parents[2]
M52 = ROOT/'build/m52'; GAME = ROOT.parents[1]
BASE = M52/'recovery-room-scene-driver-02'; PRODUCT = M52/'recovery-room-first-raster-product-01'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
SDK = GAME/'mods/Sandevistan/build/tools/flexsdk'
PRODUCT_SHA = '6d4655f30bc252e798304bbf99a21458d53eeec1538c6d49eeb04c1a0b655392'
TESTS = {'RoomTravelTimingTestDoc.as', 'RoomTravelSceneTestDoc.as', 'A22RoomMetrics.as', 'FirstRasterSceneProbe.as'}
BASE_FILES = {
 'tests/RoomTravelTimingTestDoc.as': '226001bfb880363615c98d697ef0b1ea224545f749123b14987160f91e0998e3',
 'tests/RoomTravelSceneTestDoc.as': '4192ba6668a9927ab08d8fa931a535106d425e2732d749cccd15cea42ef43d06',
 'ProductionDeclarations.swc': '598d39851de4299046148815f2b2b7b1a88379faa2981a114565f111408882a7',
 'GameCombatStubs.swc': '8aa240ed77522ded5236440b29b48d90f65b1c0bc971f21984b81ec1cd0ba61a',
 'scene/EffectsHarness.swf': 'd52ef4300c7d472ee05884d7b4709f4abf80b3e6ff935b695a9ed986db021086'}
FIXED = {BASE/name: digest for name, digest in BASE_FILES.items()}
FIXED.update({BASE/'prepared.json': 'bd4d38143b3b2f6bbba4d0e457cec4c69962e460150bde821ae1f97cf0d1959c',
 PRODUCT/'prepared.json': 'd4598712cd5d5457802b16a998136ecc3b30166183f6ac7aa38a48fd6c4bd278',
 PRODUCT/'compile.json': '5062269f806d92d28190c56bca9c7768d0fe13b8e43929a5699d921468c24695',
 PRODUCT/'RConnectMod.swf': PRODUCT_SHA})

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def save(path, value):
 with Path(path).open('x', encoding='utf-8') as stream:
  json.dump(value, stream, ensure_ascii=False, indent=2); stream.write('\n')
def inventory(folder):
 return {p.relative_to(folder).as_posix(): sha(p) for p in sorted(folder.rglob('*')) if p.is_file()}

def installation():
 names = read(PRODUCT/'prepared.json')['installation_before']; assert len(names) == 22
 assert all(not Path(n).is_absolute() and GAME in (GAME/n).resolve().parents for n in names)
 return {n: sha(GAME/n) for n in names}

def inputs():
 for path, digest in FIXED.items(): assert sha(path) == digest, str(path)
 base, product, built = read(BASE/'prepared.json'), read(PRODUCT/'prepared.json'), read(PRODUCT/'compile.json')
 assert base['compiled'] and all(base['files'][n] == h for n, h in BASE_FILES.items())
 assert built['compiled'] and built['candidate_sha256'] == PRODUCT_SHA
 assert built['sources_unchanged'] and built['inputs_unchanged'] and built['installation_unchanged']
 assert built['installation_before'] == built['installation_after'] == product['installation_before']
 assert len(built['commands']) == 2 and all(r['exit_code'] == 0 and r['reaped'] for r in built['commands'])
 assert inventory(PRODUCT/'src') == product['source']
 meta = read(HERE/'source-manifest.json')
 assert set(meta['sources']) == TESTS and inventory(HERE/'tests') == meta['sources']
 assert sha(HERE/'generate.py') == meta['generator_sha256']
 assert sha(HERE/'source.diff') == meta['source_diff_sha256']
 assert meta['inputs'] and all(Path(n).is_absolute() and sha(n) == h for n, h in meta['inputs'].items())
 for name in ('RoomTravelTimingTestDoc.as', 'RoomTravelSceneTestDoc.as'):
  assert (HERE/'tests'/name).read_bytes() == (BASE/'tests'/name).read_bytes(), name
 paths = list(FIXED) + [Path(__file__), HERE/'source-manifest.json', HERE/'generate.py', HERE/'source.diff',
  JAVA, SDK/'lib/mxmlc.jar', SDK/'frameworks/air-config.xml', SDK/'frameworks/libs/air/airglobal.swc',
  ROOT/'tools/validation/runtime_memory.py', GAME/'mods/ModLoader/tools/test_registry.py']
 paths += list((HERE/'tests').glob('*.as')) + [Path(n) for n in meta['inputs']]
 paths += [PRODUCT/'src'/n for n in product['source']]
 return {str(p): sha(p) for p in sorted(set(paths))}

def copied_check(out, files):
 assert all(sha(out/n) == h for n, h in files.items()), 'Copied source/declaration/harness changed'

def verify(out: Path) -> dict:
 """Read-only compiled scene verification; never grants native/performance qualification."""
 out = Path(out).resolve(); assert out.parent == M52
 prepared_path, compile_path = out/'prepared.json', out/'compile.json'
 meta, built = read(prepared_path), read(compile_path)
 prepared_sha, compile_sha = sha(prepared_path), sha(compile_path)
 assert meta['kind'] == 'first-raster-scene-diagnostic-driver' and meta['compiled'] is False
 assert built['compiled'] is True and built['compiler_succeeded'] is True
 assert meta['scene_only'] is True and built['scene_only'] is True
 assert meta['candidate_sha256'] == built['candidate_sha256'] == PRODUCT_SHA
 assert built['prepared_sha256'] == prepared_sha
 assert built['error'] is None and built['validation_error'] is None and built['inputs_unchanged'] is True
 for evidence in (meta, built):
  assert all(evidence[key] is False for key in ('air_started', 'installed', 'runtimeValidated', 'performanceQualified'))
 pins, current = inputs(), installation()
 assert meta['inputs'] == pins
 assert meta['installation_before'] == built['installation_before'] == built['installation_after'] == current
 copied = {**{'tests/'+name: sha(HERE/'tests'/name) for name in TESTS},
  **{name: BASE_FILES[name] for name in ('ProductionDeclarations.swc', 'GameCombatStubs.swc', 'scene/EffectsHarness.swf')}}
 assert meta['files'] == copied; copied_check(out, copied)
 assert inventory(out/'tests') == read(HERE/'source-manifest.json')['sources']
 assert set(built['artifacts']) == {'scene/EffectsDriver.swf', 'scene/EffectsHarness.swf'}
 assert all(sha(out/name) == digest for name, digest in built['artifacts'].items())
 assert built['artifacts']['scene/EffectsHarness.swf'] == BASE_FILES['scene/EffectsHarness.swf']
 assert len(built['commands']) == 1
 row = built['commands'][0]
 assert row['exit_code'] == 0 and row['reaped'] is True and isinstance(row['pid'], int) and row['pid'] > 0
 expected = [str(JAVA), '-Xmx384m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
  '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
  '-source-path='+str(out/'tests'), '-external-library-path+='+str(out/'ProductionDeclarations.swc'),
  '-external-library-path+='+str(out/'GameCombatStubs.swc'), '-output='+str(out/'scene/EffectsDriver.swf'),
  str(out/'tests/RoomTravelSceneTestDoc.as')]
 assert row['command'] == expected
 assert sha(prepared_path) == prepared_sha and sha(compile_path) == compile_sha
 return dict(verified=True, compiled=True, scene_only=True, candidate_sha256=PRODUCT_SHA,
  prepared={'path': str(prepared_path), 'sha256': prepared_sha},
  compile={'path': str(compile_path), 'sha256': compile_sha},
  artifacts=dict(built['artifacts']), files=dict(meta['files']), inputs=pins, installation=current,
  air_started=False, installed=False, runtimeValidated=False, performanceQualified=False)

def main():
 ap = argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--check', action='store_true'); ap.add_argument('--output', type=Path)
 ap.add_argument('--build', action='store_true'); ap.add_argument('--registry-wait', type=float, default=900)
 args = ap.parse_args(); assert args.registry_wait >= 0
 assert not args.check or not args.build and args.output is None
 pins, before = inputs(), installation()
 if args.check:
  print(json.dumps({'checked': True, 'installation_items': len(before), 'compiled': False, 'air_started': False})); return
 assert args.output is not None
 out = (ROOT/args.output).resolve(); assert out.parent == M52 and not out.exists()
 (out/'tests').mkdir(parents=True); (out/'scene').mkdir()
 for name in TESTS: shutil.copyfile(HERE/'tests'/name, out/'tests'/name)
 for name in ('ProductionDeclarations.swc', 'GameCombatStubs.swc', 'scene/EffectsHarness.swf'):
  shutil.copyfile(BASE/name, out/name)
 files = inventory(out); copied_check(out, files)
 assert inputs() == pins and installation() == before
 save(out/'prepared.json', dict(kind='first-raster-scene-diagnostic-driver', inputs=pins, files=files,
  candidate_sha256=PRODUCT_SHA, installation_before=before, scene_only=True,
  compiled=False, air_started=False, installed=False, runtimeValidated=False, performanceQualified=False))
 prepared_sha = sha(out/'prepared.json')
 if not args.build: print(out); return
 sys.path.insert(0, str(ROOT/'tools/validation')); from runtime_memory import snapshot, wait_owned
 sys.path.insert(0, str(GAME/'mods/ModLoader/tools')); from test_registry import Registration
 command = [str(JAVA), '-Xmx384m', '-jar', str(SDK/'lib/mxmlc.jar'), '+configname=air',
  '+flexlib='+str(SDK/'frameworks'), '-swf-version=38', '-debug=false', '-optimize=true',
  '-source-path='+str(out/'tests'), '-external-library-path+='+str(out/'ProductionDeclarations.swc'),
  '-external-library-path+='+str(out/'GameCombatStubs.swc'), '-output='+str(out/'scene/EffectsDriver.swf'),
  str(out/'tests/RoomTravelSceneTestDoc.as')]
 row = dict(command=command, pid=None, exit_code=None, reaped=False)
 succeeded = False; error = None
 try:
  with Registration(owner='RConnect / 首绘诊断驱动', resource='game', purpose='Compile one scene driver; no AIR',
                    run_dir=out, evidence=out/'compile.json', wait=args.registry_wait) as reg:
   process = None
   try:
    assert inputs() == pins and installation() == before; copied_check(out, files)
    assert snapshot()['free_commit_bytes'] >= 1024**3, 'Compilation requires 1 GiB commit headroom'
    reg.before_launch('one first-raster scene diagnostic compiler')
    with (out/'compile.log').open('x', encoding='utf-8') as log:
     process = subprocess.Popen(command, cwd=out, stdout=log, stderr=subprocess.STDOUT,
      env=dict(os.environ, AIR_HOME=str(SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
     row['pid'] = process.pid; reg.child(process.pid)
     row['exit_code'] = wait_owned(process, 300, out/'compile-memory.json')
     assert row['exit_code'] == 0 and (out/'scene/EffectsDriver.swf').is_file(), 'Scene compilation failed'
    succeeded = True
   finally:
    if process is not None:
     if process.poll() is None: process.kill()
     process.wait(); row['reaped'] = process.poll() is not None
    reg.child_stopped()
   assert inputs() == pins and installation() == before; copied_check(out, files)
   reg.outcome='passed'; reg.note='One diagnostic scene driver compiled; no runtime/performance qualification'
 except BaseException as exc:
  error = repr(exc); raise
 finally:
  after = None; unchanged = False; validation_error = None; artifacts = {}
  try:
   after = installation(); unchanged = inputs() == pins and after == before
   copied_check(out, files)
   assert sha(out/'prepared.json') == prepared_sha, 'Prepared metadata changed'
   if not unchanged: raise RuntimeError('Installed files or frozen inputs changed')
  except BaseException as exc: validation_error = repr(exc)
  try:
   for name in ('scene/EffectsDriver.swf', 'scene/EffectsHarness.swf'):
    if (out/name).is_file(): artifacts[name] = sha(out/name)
  except BaseException as exc: validation_error = (validation_error or '')+'; artifact validation: '+repr(exc)
  save(out/'compile.json', dict(compiled=succeeded and error is None and validation_error is None,
   compiler_succeeded=succeeded, commands=[row], error=error, validation_error=validation_error,
   prepared_sha256=prepared_sha, candidate_sha256=PRODUCT_SHA, artifacts=artifacts,
   installation_before=before, installation_after=after, inputs_unchanged=unchanged,
   scene_only=True, air_started=False, installed=False, runtimeValidated=False, performanceQualified=False))
  if validation_error is not None and error is None: raise RuntimeError(validation_error)
 print(out)

if __name__ == '__main__': main()
