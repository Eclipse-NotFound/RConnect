"""Bounded operand provenance for the exact current donor's local slots.

No bytecode is changed here. Unknown instructions/receivers fail closed. A slot
is accepted only on this invocation's activation or its own exception object.
"""
from collections import deque

def prove(abc, index, core):
 body=abc.bodies[index];rows,_=core.decode(bytes.fromhex(body.get('codeBytes')))
 by={r[0]:r for r in rows};exceptions=list(body.find('exceptions'))
 slots={int(t.get('slot_id')):t for t in body.findall('traits/traits/item')}
 assert len(slots)==len(body.findall('traits/traits/item')) and all(i>0 for i in slots)
 assert all(t.get('type')=='TraitSlotConst' for t in slots.values())
 assert not any(r[2] in (0x40,0x43,0x44,0x58,0x67,0x6e,0x6f) or any(k in ('m','c') for k,v in r[3]) for r in rows),'Unreviewed method/class/outer/global-slot reference'
 flags=int(abc.methods[index].get('flags'));init=int(body.get('init_scope_depth'));maximum=int(body.get('max_scope_depth'))
 # FFDec uses 4 for these plain instance methods and 5 with activation. Actual
 # saved declaring scope remains the original class/script; local capacity is
 # maximum-init. No getouterscope instruction is admitted.
 assert init==(5 if flags&2 else 4),'Unreviewed donor scope shape'
 unknown=('unknown',);this=('this',)
 start=((),(this,)+tuple(unknown for _ in range(int(body.get('max_regs'))-1)),())
 states={0:start};todo=deque([0]);proof={};visited=set();peak_stack=peak_scope=0
 def offer(pc,state):
  assert pc in by,('Bad control-flow target',pc)
  if pc not in states:states[pc]=state;todo.append(pc);return
  old=states[pc];assert len(old[0])==len(state[0]) and len(old[2])==len(state[2]),('Frame merge mismatch',pc)
  merged=tuple(tuple(x if x==y else unknown for x,y in zip(left,right)) for left,right in zip(old,state))
  if merged!=old:states[pc]=merged;todo.append(pc)
 def runtime_names(operands):
  mn=[v for k,v in operands if k=='n']
  if not mn:return 0
  kind=int(abc.cp['constant_multiname'][mn[0]].get('kind'))
  assert kind in (7,9,27),('Unreviewed runtime multiname',kind)
  return int(kind==27)
 while todo:
  pc=todo.popleft();stack,registers,scopes=map(list,states[pc]);row=by[pc];_,end,op,args=row;visited.add(pc)
  operand=lambda i=0:args[i][1]
  def pop(n=1):
   assert len(stack)>=n,('Operand underflow',pc,hex(op))
   if not n:return []
   values=stack[-n:];del stack[-n:];return values
  def replace(n):pop(n);stack.append(unknown)
  # Exceptional entry retains locals but resets operand/local-scope stacks.
  for e in exceptions:
   if int(e.get('start'))<=pc<int(e.get('end')):
    offer(int(e.get('target')),((unknown,),tuple(registers),()))
  branch=None;terminal=False
  if op in (0x09,0xef):pass
  elif op==0x08:registers[operand()]=unknown
  elif op in (0x20,0x21,0x24,0x25,0x26,0x27,0x2c,0x2d,0x2f):stack.append(unknown)
  elif op==0x29:pop()
  elif op==0x2a:assert stack;stack.append(stack[-1])
  elif op==0x2b:assert len(stack)>=2;stack[-2:]=reversed(stack[-2:])
  elif op==0x30:scopes.extend(pop())
  elif op==0x1d:assert scopes;scopes.pop()
  elif op==0x57:assert flags&2;stack.append(('activation',pc))
  elif op==0x5a:assert 0<=operand()<len(exceptions);stack.append(('catch',operand()))
  elif op==0x62:stack.append(registers[operand()])
  elif op==0x63:registers[operand()]=pop()[0]
  elif 0xd0<=op<=0xd3:stack.append(registers[op-0xd0])
  elif 0xd4<=op<=0xd7:registers[op-0xd4]=pop()[0]
  elif op==0x65:assert operand()<len(scopes);stack.append(scopes[operand()])
  elif op in (0x6c,0x6d):
   values=pop(1 if op==0x6c else 2);receiver=values[0];slot=operand()
   if receiver[0]=='activation':assert slot in slots,('Unknown activation slot',pc,slot)
   elif receiver[0]=='catch':assert slot==1 and int(exceptions[receiver[1]].get('name_index','0'))>0,('Unknown catch slot',pc)
   else:raise AssertionError(('Non-local/unknown slot receiver',pc,receiver,slot))
   proof[pc]={'offset':pc,'opcode':hex(op),'slot':slot,'receiver':list(receiver)}
   if op==0x6c:stack.append(unknown)
  elif op in (0x5d,0x60):replace(runtime_names(args))
  elif op==0x66:replace(1+runtime_names(args))
  elif op==0x61:pop(2+runtime_names(args))
  elif op in (0x46,0x4a,0x4f):
   pop(1+runtime_names(args)+operand(-1))
   if op!=0x4f:stack.append(unknown)
  elif op==0x56:replace(operand())
  elif op in (0x1e,0x23,0xa0,0xa1,0xa2,0xa3,0xab,0xac,0xad,0xae,0xaf,0xb3):replace(2)
  elif op in (0x73,0x75,0x76,0x80,0x90,0x91,0x96,0xc0,0xc1):replace(1)
  elif op==0x82:assert stack  # coerce_a preserves the operand itself.
  elif op==0xc2:registers[operand()]=unknown
  elif op==0x32:registers[operand()]=registers[operand(1)]=unknown;stack.append(unknown)
  elif 0x0c<=op<=0x1a:
   branch=operand();pop(0 if op==0x10 else (1 if op in (0x11,0x12) else 2))
  elif op in (0x47,0x48):
   if op==0x48:pop()
   terminal=True
  else:raise AssertionError(('Unsupported provenance opcode',pc,hex(op)))
  peak_stack=max(peak_stack,len(stack));peak_scope=max(peak_scope,len(scopes))
  assert len(stack)<=int(body.get('max_stack')) and len(scopes)<=maximum-init,('Frame capacity too small',pc)
  state=(tuple(stack),tuple(registers),tuple(scopes))
  if branch is not None:offer(branch,state)
  if not terminal and op!=0x10:offer(end,state)
 allslots={r[0] for r in rows if r[2] in (0x6c,0x6d)}
 assert allslots==set(proof),'Unreachable/unproved slot instruction'
 return {'passed':True,'slot_accesses':[proof[k] for k in sorted(proof)],'activation_slots':sorted(slots),
  'exception_count':len(exceptions),'all_slot_receivers_local':True,'no_outer_scope':True,
  'init_scope_depth':init,'max_scope_depth':maximum,'local_scope_capacity':maximum-init,
  'observed_local_scope_peak':peak_scope,'observed_operand_peak':peak_stack,'visited_instructions':len(visited)}
