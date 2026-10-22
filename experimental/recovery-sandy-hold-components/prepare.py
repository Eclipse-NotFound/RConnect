"""Freeze exact proposal bridge + two unreachable ASC returns; never compile or run."""
from pathlib import Path
import argparse, ast, hashlib, json, re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
PROPOSAL=ROOT/'experimental/recovery-sandy-travel-hold-proposal'
CEC=ROOT.parent/'Sandevistan/build/out/keybind-20261015-006'
SOURCE=CEC/'frozen/src/SandevistanMod.as'
EXPECTED=76
PINS={
 SOURCE:'ad931f4f0cc374f9f084f61227d6b1fd1bf61e7a156cd69e2b0c79141584492d',
 CEC/'SandevistanMod.swf':'cec6a3061cb90380579d8a95aa1254e0328bd0dae6e239fc4ca5205d6cccf942',
 PROPOSAL/'SandyTravelHoldBridge.as':'5b195a60fedcd94b416a7f0f3fa82db5cc5423a843ec3d90ef6bcc78037a2890',
 PROPOSAL/'entry-changes.patch':'fd21e2bdf79e61b5b6f0bf8238ed476d88517e120c2f7a12f636b8c7b3e478c3',
}
GUARD='         if (travelHold != null && travelHold.isHeld()) return;\n'
DECL='      private var travelHold:SandyTravelHoldBridge;\n'
KEY_UP='''         if (travelHold != null && travelHold.isHeld())
         {
            keyDownSeen[e.keyCode] = null;
            keyPressTime[e.keyCode] = null;
            return;
         }
'''
INIT='''         inst.travelHold = new SandyTravelHoldBridge(
            function():Object {
               var wc:Class = ApplicationDomain.currentDomain.getDefinition("fe.World") as Class;
               return wc != null ? wc["w"] : null;
            },
            function():Object {
               return {phase:inst.sandyActive ? "active" : (inst.replaying ? "replay" : "idle"),
                  sandyLeft:inst.sandyLeft,cooldownLeft:inst.cooldownLeft,replayIndex:inst.replayIdx,
                  enemyEnabled:inst.cfgESEnabled,debugTest:inst.debugTest};
            });
         main.addChild(inst.travelHold);
'''

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def digest(text):return hashlib.sha256(text.encode('utf-8')).hexdigest()
def save(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def inventory(path):return {p.relative_to(path).as_posix():sha(p) for p in sorted(path.rglob('*.as'))}

def helper_source():
 raw=(PROPOSAL/'SandyTravelHoldBridge.as').read_bytes()
 for old,new in [
  (b'} catch(e:*) {return null;}\n      }',b'} catch(e:*) {return null;}\n         return null; // ASC definite-return compatibility; unreachable.\n      }'),
  (b'} catch(e:*) {return false;}\n      }',b'} catch(e:*) {return false;}\n         return false; // ASC definite-return compatibility; unreachable.\n      }')]:
  assert raw.count(old)==1,'Exact proposal return boundary changed'
  raw=raw.replace(old,new)
 return raw

def apply_patch(base,patch):
 lines=base.splitlines(True);diff=patch.splitlines();out=[];cursor=0;added=0;hunks=0;i=0
 while i<len(diff):
  m=re.match(r'@@ -(\d+),(\d+) \+(\d+),(\d+) @@',diff[i])
  if not m:i+=1;continue
  start,old_count,new_start,new_count=map(int,m.groups());hunks+=1
  assert start-1>=cursor
  out.extend(lines[cursor:start-1]);cursor=start-1
  assert len(out)==new_start-1,'New hunk position disagrees'
  i+=1;old=[];new=[]
  while i<len(diff) and not diff[i].startswith('@@'):
   line=diff[i];assert line and line[0] in ' +-','Unsupported patch syntax'
   if line[0] in ' -':old.append(line[1:]+'\n')
   if line[0] in ' +':new.append(line[1:]+'\n')
   if line[0]=='+':added+=1
   assert line[0]!='-','This exact entry patch must not remove old lines'
   i+=1
  assert len(old)==old_count and len(new)==new_count
  assert lines[cursor:cursor+old_count]==old,'Old context does not match exact CEC6'
  out.extend(new);cursor+=old_count
 out.extend(lines[cursor:]);assert hunks==7 and added==22
 return ''.join(out)

def methods(text):
 # CEC6 outer methods all use exactly six spaces, with a same-indent close.
 # Anonymous callbacks are nested more deeply and are not separate entries.
 lines=text.splitlines(True);result={}
 for i,line in enumerate(lines):
  m=re.match(r'^      (?:public|private|protected|internal)(?: static)? function (\w+)\(',line)
  if not m:continue
  name=m.group(1);assert name not in result
  assert lines[i+1]=='      {\n',name
  end=next(j for j in range(i+2,len(lines)) if lines[j]=='      }\n')
  result[name]=''.join(lines[i:end+1])
 return result

def audit_pair(base,patched):
 old,new=methods(base),methods(patched);assert old.keys()==new.keys()
 changed={'init','onFrame','startSandy','onMouseDown','onKeyUp','onKey'}
 assert {name for name in old if old[name]!=new[name]}==changed
 rows=[]
 for name,prior in old.items():
  after=new[name];projected=after
  if name in {'onFrame','startSandy','onMouseDown','onKey'}:
   prefix=''.join(after.splitlines(True)[:2]);assert after.startswith(prefix+GUARD),name
   assert after.count(GUARD)==1,name
   projected=after.replace(GUARD,'',1)
  elif name=='onKeyUp':
   prefix=''.join(after.splitlines(True)[:2])+'         if (keybinds != null) keybinds.releaseKey(e.keyCode);\n'
   assert after.startswith(prefix+KEY_UP),'Key release must precede hold early return'
   assert after.count(KEY_UP)==1
   projected=after.replace(KEY_UP,'',1)
  elif name=='init':
   anchor='         inst.cfgHotkey = int(inst.keybinds.binding.code);\n'
   assert after.count(INIT)==1 and anchor+INIT in after
   projected=after.replace(INIT,'',1)
  assert projected==prior,'No-hold source projection changed '+name
  rows.append(dict(method=name,changed=name in changed,original_sha256=digest(prior),
   patched_sha256=digest(after),no_hold_projection_sha256=digest(projected),equal=True))
 projected=patched
 for block,count in [(GUARD,4),(KEY_UP,1),(INIT,1),(DECL,1)]:
  assert projected.count(block)==count
  projected=projected.replace(block,'')
 assert projected==base,'Change outside approved insertions'
 assert new['onMouseUp']==old['onMouseUp'] and new['onDeactivateClear']==old['onDeactivateClear']
 return rows

def static_audit():
 for p,h in PINS.items():assert sha(p)==h,str(p)
 build=read(CEC/'build-input.json')
 assert build['candidate_sha256']==PINS[CEC/'SandevistanMod.swf']
 assert build['sources']['src/SandevistanMod.as']==PINS[SOURCE]
 base=SOURCE.read_text(encoding='utf-8');patch=(PROPOSAL/'entry-changes.patch').read_text(encoding='utf-8')
 patched=apply_patch(base,patch)
 crlf=digest(patched.replace('\n','\r\n'))
 assert crlf=='577679b9da303a2959e50512a51c5cd0e39f37dfc46416615f8fb15ecf0cd352'
 rows=audit_pair(base,patched)
 bad={
  'missing_onFrame_guard':patched.replace(GUARD,'',1),
  'inverted_first_guard':patched.replace('travelHold != null && travelHold.isHeld()','travelHold != null && !travelHold.isHeld()',1),
  'guard_after_key_step':patched.replace(GUARD+'         if (keybinds != null) keybinds.step();\n','         if (keybinds != null) keybinds.step();\n'+GUARD,1),
  'key_up_early_return_before_release':patched.replace('         if (keybinds != null) keybinds.releaseKey(e.keyCode);\n'+KEY_UP,KEY_UP+'         if (keybinds != null) keybinds.releaseKey(e.keyCode);\n',1),
  'mouse_up_regression':patched.replace('try { mouseAtkDown = false; }','try { mouseAtkDown = true; }',1),
  'replay_method_change':patched.replace('      private function stepReplay():void','      private function stepReplayDifferent():void',1),
 }
 rejected=[]
 for label,text in bad.items():
  assert text!=patched,label+' mutation was not applied'
  try:audit_pair(base,text)
  except (AssertionError,StopIteration):rejected.append(label)
  else:raise AssertionError('Static negative accepted: '+label)
 fixture=(HERE/'components/SandyTravelHoldChecks.as').read_text(encoding='utf-8')
 labels=re.findall(r'"(\d\d [^"\n]+)"',fixture)
 assert len(labels)==EXPECTED and [int(s[:2]) for s in labels]==list(range(1,EXPECTED+1))
 for p in [HERE/'prepare.py',HERE/'run_component.py']:ast.parse(p.read_text(encoding='utf-8'))
 return dict(passed=True,entry_patch_hunks=7,entry_patch_added_lines=22,
  baseline_sha256=PINS[SOURCE],entry_crlf_patched_sha256=crlf,
  proposal_bridge_sha256=PINS[PROPOSAL/'SandyTravelHoldBridge.as'],
  component_bridge_sha256=hashlib.sha256(helper_source()).hexdigest(),
  methods=rows,methods_count=len(rows),unchanged_methods_count=sum(not r['changed'] for r in rows),
  negative_mutations_rejected=rejected,expected_component_checks=EXPECTED,
  unheld_projection_only=True,full_sandevistan_execution_verified=False,compiled=False,air_started=False,
  limitations=['init adds a Sprite and requires the real main.addChild contract',
   'five added predicates execute even when no lease exists; source projection is not zero-cost proof',
   'full Sandy stepping, event dispatch, asynchronous callbacks and cross-peer travel require native validation'])

def verify():
 m=read(HERE/'inputs.json')
 for p,h in m['inputs'].items():assert sha(Path(p))==h,p
 assert inventory(HERE/'components')==m['components']
 assert (HERE/'components/SandyTravelHoldBridge.as').read_bytes()==helper_source()
 result=static_audit();assert result==read(HERE/'static-checks.json')
 return dict(passed=True,expected_checks=EXPECTED,methods_count=result['methods_count'],
  actual_bridge=True,compatibility_only=True,compiled=False,air_started=False)

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--verify',action='store_true');args=parser.parse_args()
 if args.verify:print(json.dumps(verify(),ensure_ascii=False));return
 assert not (HERE/'inputs.json').exists(),'Frozen preparation already exists'
 target=HERE/'components/SandyTravelHoldBridge.as';assert not target.exists();target.write_bytes(helper_source())
 result=static_audit();save(HERE/'static-checks.json',result)
 inputs=list(PINS)+[CEC/'build-input.json',HERE/'prepare.py',HERE/'run_component.py',ROOT/'tools/validation/run_recovery_component.py']
 save(HERE/'inputs.json',dict(kind='sandy-travel-hold-exact-bridge-component',expected_checks=EXPECTED,
  inputs={str(p):sha(p) for p in inputs},components=inventory(HERE/'components'),
  bridge_delta='only unreachable return null/false tails for ASC definite-return compatibility',
  native_game_test=False,performance_qualified=False))
 print(json.dumps(verify(),ensure_ascii=False))

if __name__=='__main__':main()
