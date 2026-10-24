"""Nine raw prefixes plus one donor body; use the existing ABC decoder.

No native constructor, static initializer or complex native body is imported.
All original relative branch bytes remain unchanged in the nine prefixed bodies.
"""
from pathlib import Path
import copy, hashlib, sys, types, xml.etree.ElementTree as ET
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.path.insert(0,str(Path(__file__).resolve().parent))
import inputs as source
ROOT=source.ROOT;sha=source.sha
legacy=source.load('ui_original_retainer',source.OLD/'retain_v2.py')
support=legacy.support;core=legacy.core;canonical=legacy.canonical
slotproof=source.load('ui_activation_provenance',Path(__file__).with_name('activation_slots.py'))
require=legacy.require;traits=legacy.traits;table=legacy.table;namespace=legacy.namespace;nsname=legacy.nsname;u30=legacy.u30
PREFIXES=tuple('fe.World::0:1:'+n for n in source.PREFIX_METHODS)
EXIT='fe.World::0:1:exitStep'
TARGETS=PREFIXES+(EXIT,)
NEW=tuple(('fe.World','0','1',n) for n in source.HELPERS)
NEW_NAMES=tuple('fe.World::0:1:'+n for n in source.HELPERS)
CINITS=()
# A private imported module instance supplies only namespace/provenance routines.
# Prefix donor bodies are deliberately excluded: they will never be imported.
legacy.prep=types.SimpleNamespace(CLASSES=source.CLASSES)
legacy.TARGETS=(EXIT,);legacy.NEW_NAMES=NEW_NAMES;legacy.slotproof=slotproof
body_names=legacy.body_names
def namespace_map(a,b):return legacy.namespace_map(a,b)
def normalized_donor(a,node,b,mapping):return legacy.normalized_donor(a,node,b,mapping)
def binding(abc,name,public=False):
 t=table(abc,'fe.World','0')[('TraitMethodGetterSetter','1',name)]
 mn=int(t.get('name_index'));ns=namespace(abc,mn);space=abc.cp['constant_namespace'][ns]
 require(space.get('kind')==('22' if public else '5'),'Wrong helper namespace '+name)
 if public:require(nsname(abc,ns)=='','Public helper namespace changed')
 return mn
def native_display_signature(abc):
 info=abc.methods[abc.named['fe.World::0:1:rconnectUiNativeDisplay']]
 # Copy the complete donor method_info below, including the false default.
 # The exact optional-value representation is inspected through ABC metadata.
 params=list(info.find('param_types'))
 require(len(params)==1 and abc.qualified(int(params[0].text))=='Boolean','Native display helper must take one Boolean')
 options=list(info.find('optional'))
 require(len(options)==1,'Native display helper must retain its optional false default')
 option=options[0]
 require(option.get('type')=='ValueKind' and int(option.get('value_kind'))==10 and int(option.get('value_index'))==10,
         'Native display helper optional value is not exact false')
 require(int(info.get('flags'))&8,'Optional-parameter flag missing')
 return dict(optional_boolean_false=True,method_info_sha256=support.digest(info))
def exception_bounds(body,addresses,length):
 for item in body.find('exceptions'):
  require(all(k in item.attrib for k in ('start','end','target')),'Unexpected exception XML fields')
  start,end,target=(int(item.get(k)) for k in ('start','end','target'))
  require(0<=start<end<=length and 0<=target<length,'Exception range outside code')
  require(all(v in addresses for v in (start,end,target)),'Exception offset is not an instruction boundary')
def prefix_body(a,b,name):
 old=a.bodies[a.named[name]];code=bytes.fromhex(old.get('codeBytes'))
 mn=binding(b,'rconnectUiNativeDisplay');special=name.endswith(':newGame')
 prefix=b'\xd0'+(b'\x26' if special else b'')+b'\x4f'+u30(mn)+u30(1 if special else 0)
 rows,addresses=core.decode(code);delta=len(prefix)
 require(rows and rows[0][0]==0,'Native body has no entry')
 core.Compare.exceptions(old,a,addresses)
 exception_bounds(old,addresses,len(code))
 result=copy.deepcopy(old);result.set('codeBytes',(prefix+code).hex())
 result.set('max_stack',str(max(int(old.get('max_stack')),2 if special else 1)))
 for item in result.find('exceptions'):
  for field in ('start','end','target'):item.set(field,str(int(item.get(field))+delta))
 # Check actual instruction boundaries and all relative branch targets shift.
 after,bounds=core.decode(prefix+code);core.Compare.exceptions(result,b,bounds)
 exception_bounds(result,bounds,len(prefix+code))
 expected_prefix=[0xd0,0x26,0x4f] if special else [0xd0,0x4f]
 require([r[2] for r in after[:len(expected_prefix)]]==expected_prefix,'Wrong prefix instructions')
 require(after[len(expected_prefix)-1][3]==[('n',mn),('u',1 if special else 0)],'Wrong prefix QName/argc')
 for before,now in zip(rows,after[len(expected_prefix):]):
  require(now[0:2]==(before[0]+delta,before[1]+delta) and now[2]==before[2],'Instruction offset/opcode drift')
  require(now[3]==[(k,v+delta if k=='target' else v) for k,v in before[3]],'Original relative branch/operand drift')
 require(len(after)==len(rows)+len(expected_prefix),'Instruction count drift')
 return result,dict(prefix_hex=prefix.hex(),prefix_length=delta,helper_multiname=mn,argc=1 if special else 0,
  original_code_sha256=hashlib.sha256(code).hexdigest(),original_body_suffix_byte_exact=True,
  method_metadata_and_locals_unchanged=True,exceptions_uniform_shift=delta,
  original_max_stack=int(old.get('max_stack')),max_stack=int(result.get('max_stack')))
def retain(base_xml,donor_xml,out_xml):
 require(sha(base_xml)==source.BASE_XML_SHA,'Wrong A796 XML');out_xml=Path(out_xml)
 require(not out_xml.exists() and out_xml.parent.is_relative_to(ROOT/'build/m52'),'New isolated XML required')
 tree,donor=ET.parse(base_xml),ET.parse(donor_xml);aa,bb=tree.findall('.//abc'),donor.findall('.//abc')
 require(len(aa)==len(bb)==2,'Expected two ABCs');a,b=core.ABC(aa[0]),core.ABC(bb[0]);prefix=support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other donor ABC changed')
 require(set(a.class_by_name)==set(b.class_by_name),'Class set changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and set(a.named)<=set(b.named),'Unexpected named method changes')
 mapping,evidence=namespace_map(a,b);normal,n=normalized_donor(a,bb[0],b,mapping)
 optional=native_display_signature(n)
 constants=aa[0].find('constants');pos=list(aa[0]).index(constants);aa[0].remove(constants);aa[0].insert(pos,copy.deepcopy(normal.find('constants')))
 bodies=aa[0].find('bodies');infos=aa[0].find('method_info');proof=[];new_indices={}
 for name in TARGETS:
  oi=a.named[name]
  if name in PREFIXES:body,detail=prefix_body(a,n,name);local=None
  else:
   ni=n.named[name];info=copy.deepcopy(n.methods[ni]);info.set('name_index',a.methods[oi].get('name_index'))
   require(canonical(info)==canonical(a.methods[oi]),'exitStep metadata/flags changed')
   body_names(n,ni);local=slotproof.prove(n,ni,core)
   body=copy.deepcopy(n.bodies[ni]);body.set('method_info',str(oi));detail=None
  at=list(bodies).index(a.bodies[oi]);bodies.remove(a.bodies[oi]);bodies.insert(at,body)
  proof.append(dict(name=name,prefix=detail,local_slot_proof=local,code_sha256=hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest()))
 for name in NEW_NAMES:
  ni=n.named[name];idx=len(infos);new_indices[name]=idx;infos.append(copy.deepcopy(n.methods[ni]));body_names(n,ni)
  local=slotproof.prove(n,ni,core);body=copy.deepcopy(n.bodies[ni]);body.set('method_info',str(idx));bodies.append(body)
  proof.append(dict(name=name,newIndex=idx,donorIndex=ni,local_slot_proof=local,code_sha256=hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest()))
 added=[]
 for name in source.HELPERS:
  binding(n,name,name=='rconnectLoadingView')
  t=copy.deepcopy(table(n,'fe.World','0')[('TraitMethodGetterSetter','1',name)])
  t.set('method_info',str(new_indices['fe.World::0:1:'+name]));t.set('disp_id','0');traits(a,'fe.World','0').append(t);added.append(name)
 for name,typ in source.FIELDS:
  t=copy.deepcopy(table(n,'fe.World','0')[('TraitSlotConst','0',name)])
  require(n.qualified(int(t.get('type_index')))==typ,'Wrong field type '+name)
  require(int(t.get('value_index','0'))==0,'Field must have no explicit initializer '+name)
  ns=namespace(n,int(t.get('name_index')));kind=n.cp['constant_namespace'][ns].get('kind')
  require(kind==('22' if name=='rconnectLoadingUiFaults' else '5'),'Wrong field visibility '+name)
  if name=='rconnectLoadingUiFaults':require(nsname(n,ns)=='','Wrong public field namespace')
  t.set('slot_id','0');traits(a,'fe.World','0').append(t);added.append(name)
 tree.write(out_xml,encoding='utf-8',xml_declaration=True)
 result=dict(passed=True,base_sha256=source.HOST_SHA,base_xml_sha256=sha(base_xml),donor_xml_sha256=sha(donor_xml),retained_xml_sha256=sha(out_xml),
  changed_original_methods=list(TARGETS),new_methods=list(NEW_NAMES),new_traits=added,static_initializers={},namespace_mappings=evidence,
  appended_constants=prefix,method_proof=proof,native_display_signature=optional,runtime_validated=False)
 result['preservation']=audit(base_xml,out_xml,out_xml)
 return result
def audit(base_xml,final_xml,retained_xml):
 require(sha(base_xml)==source.BASE_XML_SHA,'Wrong audit base')
 aa=ET.parse(base_xml).findall('.//abc');bb=ET.parse(final_xml).findall('.//abc');cc=ET.parse(retained_xml).findall('.//abc')
 require(len(aa)==len(bb)==len(cc)==2,'Wrong ABC count')
 require(all(canonical(x)==canonical(y) for x,y in zip(bb,cc)),'Actual roundtrip differs from retained XML')
 a,b=core.ABC(aa[0]),core.ABC(bb[0]);support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other original ABC changed')
 require(a.class_by_name==b.class_by_name and all(b.named[name]==i for name,i in a.named.items()),'Original named indices changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and len(b.methods)==len(a.methods)+7,'Unexpected method additions')
 for i,old in enumerate(a.methods):require(canonical(old)==canonical(b.methods[i]),'Old method metadata changed '+str(i))
 changed={a.named[n] for n in TARGETS};count=0
 for i,old in a.bodies.items():
  if i not in changed:require(canonical(old)==canonical(b.bodies[i]),'Non-target body changed '+str(i));count+=1
 for name in PREFIXES:
  expected,detail=prefix_body(a,b,name)
  require(canonical(expected)==canonical(b.bodies[b.named[name]]),'Prefix body changed beyond precise insertion '+name)
 require(set(b.bodies)==set(a.bodies)|{b.named[n] for n in NEW_NAMES},'Unexpected body table')
 for cls,index in a.class_by_name.items():
  for scope,old,new,container in [('0',a.instances[index],b.instances[index],'instance_traits/traits'),('1',a.statics[index],b.statics[index],'static_traits/traits')]:
   original=list(old.find(container));actual=list(new.find(container))
   added=list(source.HELPERS)+[n for n,t in source.FIELDS] if cls=='fe.World' and scope=='0' else []
   require(len(actual)==len(original)+len(added),'Trait count changed '+cls)
   require(all(canonical(x)==canonical(y) for x,y in zip(original,actual)),'Old trait changed '+cls)
   require([b.simple(int(t.get('name_index'))) for t in actual[len(original):]]==added,'Wrong appended trait order '+cls)
   stripped=copy.deepcopy(new);ts=stripped.find(container)
   for t in list(ts)[len(original):]:ts.remove(t)
   require(canonical(old)==canonical(stripped),'Original class header/constructor/interface changed '+cls)
 require(canonical(aa[0].find('script_info'))==canonical(bb[0].find('script_info')),'Script layout changed')
 for node in aa[0]:
  if node.tag not in {'constants','method_info','bodies','instance_info','class_info'}:require(canonical(node)==canonical(bb[0].find(node.tag)),'Other ABC data changed '+node.tag)
 return dict(passed=True,exact_retained_roundtrip=True,non_target_bodies_byte_exact=count,old_method_indices_preserved=True,
  original_method_metadata_exact=True,original_class_script_traits_preserved=True,original_constructors_byte_exact=True,
  original_static_initializers_byte_exact=True,old_constant_prefix_preserved=True,allowed_changed_bodies=list(TARGETS),
  prefixed_native_bodies=9,donor_native_bodies=1,added_methods=7,added_fields=6,runtime_validated=False)
def splice(base,serialized,out):
 require(sha(base)==source.HOST_SHA,'Wrong splice A796')
 old=support.BASE_SWF_SHA
 try:support.BASE_SWF_SHA=source.HOST_SHA;return support.splice(base,serialized,out)
 finally:support.BASE_SWF_SHA=old
