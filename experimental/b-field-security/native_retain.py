"""B security: five small donor helpers, three raw prefixes, no native body import.

All original constructors, static initializers, traits, constant indices and
method bodies survive. Only allAct/findCel/control get a bounded entry prefix.
The original instruction bytes (and relative branch offsets) remain exact.
"""
from pathlib import Path
import copy, hashlib, importlib.util, sys, types, xml.etree.ElementTree as ET, zlib
if sys.flags.optimize: raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/ab/native-hooks-019/pfe.swf'
BASE_SHA='1028a49a4af4d8e1b4bd215a44d38a742723438e24056e2336ea875d82efdba9'
SUPPORT=ROOT/'experimental/recovery-room-first-raster-host-current/retain_v2.py'
SUPPORT_SHA='1811657e117327c018536667fbca59a13be9e54448578361adc44ac4e795be55'
CLASSES=('fe.unit.Unit','fe.serv.Interact','fe.unit.UnitTurret')
NEW=(('fe.serv.Interact','rconnectSecurityActivate'),('fe.serv.Interact','rconnectSecurityState'),
     ('fe.unit.UnitTurret','rconnectSecurityCall'),('fe.unit.UnitTurret','rconnectSecurityState'),
     ('fe.unit.UnitTurret','rconnectSecurityClear'))
NEW_NAMES=tuple(c+'::0:1:'+n for c,n in NEW)
TARGETS=('fe.serv.Interact::0:1:allAct','fe.unit.UnitTurret::0:1:findCel','fe.unit.UnitTurret::0:1:control')
FIELDS=('RCONNECT_SECURITY_B','rconnectSecurityB')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def require(ok,message):
 if not ok:raise AssertionError(message)
def load(name,p):
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
require(sha(SUPPORT)==SUPPORT_SHA,'Retainer dependency changed')
legacy=load('b_security_original_retainer',SUPPORT)
support=legacy.support;core=support.core;canonical=support.canonical
traits=legacy.traits;table=legacy.table;namespace=legacy.namespace;nsname=legacy.nsname;u30=legacy.u30

def prove(abc,index,decoder):
 body=abc.bodies[index];rows,addresses=decoder.decode(bytes.fromhex(body.get('codeBytes')))
 require(not int(abc.methods[index].get('flags'))&2,'Helpers must not create activation objects')
 require(not list(body.find('traits/traits')) and not list(body.find('exceptions')),'Helpers must not have activation/catch state')
 forbidden={0x40,0x43,0x44,0x58,0x67,0x6c,0x6d,0x6e,0x6f}
 require(not any(r[2] in forbidden or any(k in ('m','c') for k,v in r[3]) for r in rows),
         'Helper has unrelocated method/class/slot/outer-scope operand')
 decoder.Compare.exceptions(body,abc,addresses)
 return dict(no_method_class_slot_outer_relocation=True,instructions=len(rows))

# Reuse only the audited declaration-anchored namespace normalization.
legacy.prep=types.SimpleNamespace(CLASSES=CLASSES)
legacy.TARGETS=();legacy.NEW_NAMES=NEW_NAMES;legacy.slotproof=types.SimpleNamespace(prove=prove)

def public_binding(abc,cls,name,kind='1',scope='0'):
 typ='TraitMethodGetterSetter' if kind=='1' else 'TraitSlotConst'
 t=table(abc,cls,scope)[(typ,kind,name)];mn=int(t.get('name_index'));ns=namespace(abc,mn)
 require(abc.cp['constant_multiname'][mn].get('kind')=='7' and abc.cp['constant_namespace'][ns].get('kind')=='22'
         and nsname(abc,ns)=='','Expected public QName '+cls+'.'+name)
 return mn
def string_index(abc,text):
 indices=[i for i in range(len(abc.cp['constant_string'])) if abc.string(i)==text]
 require(bool(indices),'String constant is missing '+text);return indices[0]
def prefix(abc,name):
 if name==TARGETS[0]:
  mn=public_binding(abc,'fe.serv.Interact','rconnectSecurityActivate')
  # if (!helper()) enter original body; otherwise return undefined.
  return b'\xd0\x46'+u30(mn)+b'\x00\x12\x02\x00\x00\x21\x48',2
 mn=public_binding(abc,'fe.unit.UnitTurret','rconnectSecurityCall')
 if name==TARGETS[1]:
  # Keep result on stack; null enters original body, Boolean returns early.
  return (b'\xd0\x2c'+u30(string_index(abc,'find'))+b'\xd1\x46'+u30(mn)+b'\x02'
          b'\x2a\x20\x19\x02\x00\x00\x76\x48\x29'),3
 require(name==TARGETS[2],'Unknown prefix target')
 return b'\xd0\x2c'+u30(string_index(abc,'step'))+b'\x4f'+u30(mn)+b'\x01',2
def prefixed_body(a,b,name):
 old=a.bodies[a.named[name]];code=bytes.fromhex(old.get('codeBytes'));head,peak=prefix(b,name);delta=len(head)
 rows,addresses=core.decode(code);core.Compare.exceptions(old,a,addresses)
 result=copy.deepcopy(old);result.set('codeBytes',(head+code).hex())
 result.set('max_stack',str(max(int(old.get('max_stack')),peak)))
 for e in result.find('exceptions'):
  for k in ('start','end','target'):e.set(k,str(int(e.get(k))+delta))
 after,bounds=core.decode(head+code);added,_=core.decode(head);core.Compare.exceptions(result,b,bounds)
 require(len(after)==len(rows)+len(added),'Prefix changed instruction count')
 for before,now in zip(rows,after[len(added):]):
  require(now[0:2]==(before[0]+delta,before[1]+delta) and now[2]==before[2],'Native opcode/offset drift')
  require(now[3]==[(k,v+delta if k=='target' else v) for k,v in before[3]],'Native relative operand drift')
 require(not any(k=='target' and v not in bounds for r in after for k,v in r[3]),'Prefix branch misses instruction boundary')
 return result,dict(prefix_hex=head.hex(),original_suffix_sha256=hashlib.sha256(code).hexdigest(),
  original_suffix_byte_exact=True,original_relative_branches_exact=True,exception_offset_shift=delta)

def helper_signature(a,b,cls,name):
 signature={
  ('fe.serv.Interact','rconnectSecurityActivate'):([],'Boolean',False),
  ('fe.serv.Interact','rconnectSecurityState'):(['Object'],'Object',True),
  ('fe.unit.UnitTurret','rconnectSecurityCall'):(['String','*'],'*',True),
  ('fe.unit.UnitTurret','rconnectSecurityState'):([],'Object',False),
  ('fe.unit.UnitTurret','rconnectSecurityClear'):(['Function'],'void',False)}[(cls,name)]
 idx=b.named[cls+'::0:1:'+name];m=b.methods[idx]
 typename=lambda i:'*' if i==0 else b.qualified(i)
 require([typename(int(t.text)) for t in m.find('param_types')]==signature[0] and typename(int(m.get('ret_type')))==signature[1],'Helper signature changed '+name)
 options=list(m.find('optional'))
 require(len(options)==int(signature[2]),'Helper optional arity changed '+name)
 if options:require(int(options[0].get('value_kind'))==12,'Helper default must be null')
 reference=TARGETS[0] if cls=='fe.serv.Interact' else TARGETS[1]
 require(b.bodies[idx].get('init_scope_depth')==a.bodies[a.named[reference]].get('init_scope_depth'),'Helper lexical scope differs from original class')

def retain(base_xml,donor_xml,out_xml):
 out_xml=Path(out_xml);require(not out_xml.exists(),'Keep prior retained evidence')
 tree,donor=ET.parse(base_xml),ET.parse(donor_xml);aa,bb=tree.findall('.//abc'),donor.findall('.//abc')
 require(len(aa)==len(bb)==2,'Expected two ABCs');a,b=core.ABC(aa[0]),core.ABC(bb[0]);pool=support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other donor ABC changed')
 require(set(a.class_by_name)==set(b.class_by_name),'Donor class set changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and set(a.named)<=set(b.named),'Unexpected new/missing donor method')
 mapping,evidence=legacy.namespace_map(a,b);normal,n=legacy.normalized_donor(a,bb[0],b,mapping)
 constants=aa[0].find('constants');at=list(aa[0]).index(constants);aa[0].remove(constants);aa[0].insert(at,copy.deepcopy(normal.find('constants')))
 bodies=aa[0].find('bodies');infos=aa[0].find('method_info');proof=[];indices={}
 for name in TARGETS:
  old=a.bodies[a.named[name]];body,detail=prefixed_body(a,n,name);at=list(bodies).index(old);bodies.remove(old);bodies.insert(at,body)
  proof.append(dict(name=name,prefix=detail))
 for cls,name in NEW:
  qualified=cls+'::0:1:'+name;idx=n.named[qualified];helper_signature(a,n,cls,name);public_binding(n,cls,name)
  local=prove(n,idx,core);legacy.body_names(n,idx)
  added=len(infos);indices[qualified]=added;infos.append(copy.deepcopy(n.methods[idx]))
  body=copy.deepcopy(n.bodies[idx]);body.set('method_info',str(added));bodies.append(body)
  t=copy.deepcopy(table(n,cls,'0')[('TraitMethodGetterSetter','1',name)])
  t.set('method_info',str(added));t.set('disp_id','0');traits(a,cls,'0').append(t)
  proof.append(dict(name=qualified,new_index=added,helper_proof=local))
 for name,kind,typ in [('RCONNECT_SECURITY_B','6','String'),('rconnectSecurityB','0','Function')]:
  public_binding(n,'fe.unit.Unit',name,kind,'1')
  t=copy.deepcopy(table(n,'fe.unit.Unit','1')[('TraitSlotConst',kind,name)])
  require(n.qualified(int(t.get('type_index')))==typ,'Static trait type changed')
  t.set('slot_id','0')
  if kind=='6':t.set('value_index',str(string_index(n,'b-security-v1')));t.set('value_kind','1')
  else:t.set('value_index','0');t.set('value_kind','0')
  # Defaults are established by traits. The original cinit stays byte exact.
  traits(a,'fe.unit.Unit','1').append(t)
 tree.write(out_xml,encoding='utf-8',xml_declaration=True)
 result=dict(passed=True,base_sha256=BASE_SHA,base_xml_sha256=sha(base_xml),donor_xml_sha256=sha(donor_xml),retained_xml_sha256=sha(out_xml),
  changed_original_methods=list(TARGETS),new_methods=list(NEW_NAMES),new_static_traits=list(FIELDS),static_initializers_changed=False,
  namespace_mappings=evidence,appended_constants=pool,method_proof=proof,runtime_validated=False)
 result['preservation']=audit(base_xml,out_xml,out_xml);return result

def audit(base_xml,final_xml,retained_xml):
 aa=ET.parse(base_xml).findall('.//abc');bb=ET.parse(final_xml).findall('.//abc');cc=ET.parse(retained_xml).findall('.//abc')
 require(len(aa)==len(bb)==len(cc)==2,'Wrong ABC count')
 require(all(canonical(x)==canonical(y) for x,y in zip(bb,cc)),'Serialized roundtrip differs from retained XML')
 a,b=core.ABC(aa[0]),core.ABC(bb[0]);support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other original ABC changed')
 require(a.class_by_name==b.class_by_name and all(b.named[n]==i for n,i in a.named.items()),'Original method/class indices changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and len(b.methods)==len(a.methods)+len(NEW),'Unexpected methods')
 for i,old in enumerate(a.methods):require(canonical(old)==canonical(b.methods[i]),'Original method metadata changed '+str(i))
 changed={a.named[n] for n in TARGETS};count=0
 for i,old in a.bodies.items():
  if i not in changed:require(canonical(old)==canonical(b.bodies[i]),'Non-target body changed '+str(i));count+=1
 for name in TARGETS:
  expected,detail=prefixed_body(a,b,name)
  require(canonical(expected)==canonical(b.bodies[b.named[name]]),'Target differs from exact prefix '+name)
 require(set(b.bodies)==set(a.bodies)|{b.named[n] for n in NEW_NAMES},'Unexpected body table')
 for cls,index in a.class_by_name.items():
  for scope,old,new,container in [('0',a.instances[index],b.instances[index],'instance_traits/traits'),('1',a.statics[index],b.statics[index],'static_traits/traits')]:
   original=list(old.find(container));actual=list(new.find(container))
   added=[n for c,n in NEW if c==cls] if scope=='0' else list(FIELDS) if cls=='fe.unit.Unit' else []
   require(len(actual)==len(original)+len(added),'Trait count changed '+cls)
   require(all(canonical(x)==canonical(y) for x,y in zip(original,actual)),'Original trait changed '+cls)
   require([b.simple(int(t.get('name_index'))) for t in actual[len(original):]]==added,'Wrong appended trait order '+cls)
   stripped=copy.deepcopy(new);ts=stripped.find(container)
   for t in list(ts)[len(original):]:ts.remove(t)
   require(canonical(old)==canonical(stripped),'Original class header/constructor/interface changed '+cls)
 marker=table(b,'fe.unit.Unit','1')[('TraitSlotConst','6',FIELDS[0])]
 callback=table(b,'fe.unit.Unit','1')[('TraitSlotConst','0',FIELDS[1])]
 require(marker.get('value_kind')=='1' and b.string(int(marker.get('value_index')))=='b-security-v1','Marker default changed')
 require(callback.get('value_index')=='0','Callback has a non-default initializer')
 for node in aa[0]:
  if node.tag not in {'constants','method_info','bodies','instance_info','class_info'}:
   require(canonical(node)==canonical(bb[0].find(node.tag)),'Other ABC data changed '+node.tag)
 return dict(passed=True,exact_retained_roundtrip=True,non_target_bodies_byte_exact=count,old_method_indices_preserved=True,
  original_method_metadata_exact=True,original_class_script_traits_preserved=True,original_constructors_byte_exact=True,
  original_static_initializers_byte_exact=True,old_constant_prefix_preserved=True,allowed_changed_bodies=list(TARGETS),
  prefixed_native_bodies=3,imported_native_bodies=0,added_helpers=5,added_static_traits=2,runtime_validated=False)

def splice(base,serialized,out):
 require(sha(base)==BASE_SHA,'Wrong native019 splice input')
 out=Path(out).resolve();require(out.is_relative_to(ROOT/'build/ab') and not out.exists(),'New isolated B output required')
 sig,header,old=support.raw_swf(base);dsig,dheader,donor=support.raw_swf(serialized)
 require(sig[3:]==dsig[3:] and header==dheader,'Version/frame header changed')
 require(len(old)==len(donor) and [x[0] for x in old]==[x[0] for x in donor],'SWF tag count/order changed')
 abcs=[i for i,t in enumerate(old) if t[0] in (72,82)];require(len(abcs)==2,'Expected two ABC tags')
 for i in abcs:require(support.abc_prefix(old[i])==support.abc_prefix(donor[i]),'DoABC flags/name changed')
 target=abcs[0];require(old[target][1]!=donor[target][1],'No target ABC change')
 body=header+b''.join(donor[i][2] if i==target else t[2] for i,t in enumerate(old))
 with out.open('xb') as f:f.write(sig+(len(body)+8).to_bytes(4,'little')+(zlib.compress(body,9) if sig[:3]==b'CWS' else body))
 fsig,fheader,result=support.raw_swf(out)
 require(fsig==sig and fheader==header and len(result)==len(old),'Spliced header changed')
 require(all(result[i][2]==(donor[i][2] if i==target else old[i][2]) for i in range(len(old))),'Spliced raw tag mismatch')
 return dict(passed=True,base_sha256=BASE_SHA,candidate_sha256=sha(out),serialized_sha256=sha(serialized),
  target_tag=target,other_raw_tags_preserved=len(old)-1,other_abc_preserved=True,raw_resources_preserved=True,runtime_validated=False)
