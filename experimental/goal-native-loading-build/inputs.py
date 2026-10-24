"""Exact native UI source/build inputs; read-only until an explicit build."""
from pathlib import Path
import hashlib, importlib.util, json, sys
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];GAME=ROOT.parents[1]
UI=ROOT/'experimental/goal-native-loading-ui'
BASE=ROOT/'build/m52/recovery-room-production-05'
OLD=ROOT/'experimental/recovery-room-first-raster-host-current'
HOST=GAME/'pfe.swf'
HOST_SHA='a796827173af7d6fab9885fb66ecc62182ab5335918a30c7cce4c44914a238b7'
PRODUCT_SHA='78c052aea963f1689b705ae1e14d274916ae1a1f7e81933390caf8d1a88f4699'
MANIFEST_SHA='a4792939834f8ff197be63374034e1e6e0c479b8f5d3c09816ef1c754a5bb5c7'
WORLD_SHA='62a99505e9467b27a0dff8c0f16323764a6462fbad2c25e1ec56120dad0753f3'
BASE_XML=GAME/'mods/ContinuousScene/build/generated/scene-compat-20261024/tint/product/pfe.xml'
BASE_XML_SHA='1d2642c7d55d1f97121738e6ae84996a140ebfeff686e6706c88cef82a7338da'
EXPORT=ROOT/'build/m52/recovery-room-first-raster-current-source-02'
WORLD_BASE_SHA='f9b5d270ad95a223ca37b0e339dcee1380856dff6254a5b1a0d9b12d997aaf16'
CLASSES=('fe.World',)
BORROWED_PINS={
 OLD/'retain_v2.py':'1811657e117327c018536667fbca59a13be9e54448578361adc44ac4e795be55',
 OLD/'activation_slots.py':'3d83359870b024faf6761676decd7822bfd4ec06e9df20160ff38887e5ced7e2',
 OLD/'build.py':'bc532bd6b6bd0fd7857f8a0749a14fefd94c5c0d2daa5ba8a2985cccd3212bc0',
 OLD/'prepare.py':'0885c01911aff1110dc326d6c6f131a309eee82638628d0dc71536cea88d1f89',
 ROOT/'experimental/recovery-room-production-v5/build.py':'1889514c5563c5af44ee3e50c4cf08cb3108a1cda0d2904078fcab366ee142b9',
}
PREFIX_METHODS=('resizeScreen','loadGame','ativateLoc','setLoadScreen','offLoadScreen','showScene','unshowScene','endgame','newGame')
HELPERS=('rconnectLoadingView','rconnectUiViewOwned','rconnectUiBlocked','rconnectUiWrite','rconnectUiRestore','rconnectUiNativeDisplay','rconnectUiAfterExitDisplay')
FIELDS=(('rconnectUiOwner','Object'),('rconnectUiGame','Object'),('rconnectUiPlayer','Object'),('rconnectUiWrites','Array'),('rconnectUiGeneration','uint'),('rconnectLoadingUiFaults','uint'))
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):
 with Path(p).open('x',encoding='utf-8') as f:json.dump(v,f,ensure_ascii=False,indent=2)
def load(name,p):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def inventory(p):return {f.relative_to(p).as_posix():sha(f) for f in sorted(Path(p).rglob('*')) if f.is_file()}
def paths(c):return Path(*c.split('.')).with_suffix('.as')
def reviewed():
 for p,h in BORROWED_PINS.items():assert sha(p)==h,str(p)
 assert sha(UI/'source-manifest.json')==MANIFEST_SHA
 assert sha(UI/'prepare.py')=='39065b8e02b5141e47cd38b7337f2ca044b19405d32da1155c21c6e7274570d7'
 s=load('native_ui_source_check',UI/'prepare.py');s.verify()
 meta=read(UI/'source-manifest.json');assert meta['host_source_sha256']==WORLD_SHA
 assert sha(BASE/'RConnectMod.swf')==PRODUCT_SHA
 old=read(BASE/'prepared.json');compiled=read(BASE/'compile.json')
 assert inventory(BASE/'src')==old['source'] and inventory(BASE/'tools')==old['inputs']
 assert compiled['compiled'] and compiled['candidate_sha256']==PRODUCT_SHA
 assert sha(BASE_XML)==BASE_XML_SHA
 assert sha(EXPORT/'source/scripts/fe/World.as')==WORLD_BASE_SHA
 export=read(EXPORT/'receipt.json');assert export['passed'] and export['source_sha256']==HOST_SHA
 assert export['installation_unchanged'] and export['inputs_unchanged'] and not export['air_started']
 for p,h in export['files'].items():assert sha(EXPORT/p)==h,p
 for p,h in export['inputs'].items():assert sha(p)==h,p
 assert meta['product_overlay']==inventory(UI/'src')
 return meta
def pins():
 m=reviewed();result={str(UI/p):h for p,h in m['inputs'].items()}|{str(p):h for p,h in BORROWED_PINS.items()}
 for p in (UI/'source-manifest.json',UI/'source.diff',BASE/'prepared.json',BASE/'compile.json',BASE/'RConnectMod.swf',
           BASE_XML,EXPORT/'receipt.json',EXPORT/'source/scripts/fe/World.as',EXPORT/'pcode/scripts/fe/World.pcode'):
  result[str(p)]=sha(p)
 for p in sorted(HERE.glob('*')):
  if p.is_file() and p.suffix in ('.py','.md','.diff'):result[str(p)]=sha(p)
 return result
def current():
 sys.path.insert(0,str(ROOT/'tools/validation'))
 from run_security_terminals import installation
 value=installation();assert len(value)==22
 assert value['pfe.swf']==HOST_SHA and value['mods/Rconnect/release/RConnectMod.swf']==PRODUCT_SHA
 return value
