"""Bounded A796 three-class transplant; reuse the existing ABC decoder/splicer.

V2: activation/catch slot provenance is checked; no class slots are admitted.
Only eight named native bodies, five new helpers, four appended traits and two
literal static-initializer tails may differ. Never import an entire class.
"""
from pathlib import Path
import copy, hashlib, importlib.util, json, sys, xml.etree.ElementTree as ET
if sys.flags.optimize:raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def load(name,p):
 s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
SUPPORT=ROOT/'experimental/recovery-ordinary-method-transplant/method_transplant.py'
assert sha(SUPPORT)=='c422c540490d553e6a21415b9cdb4232f287069b4b1f18a075e51d224a59268e'
support=load('first_raster_original_ABC_support',SUPPORT)
core,canonical=support.core,support.canonical
prep=load('first_raster_text_inputs',HERE/'prepare.py')
slotproof=load('first_raster_local_slot_provenance',HERE/'activation_slots.py')
TARGETS=tuple(c+'::0:1:'+n for c in prep.CLASSES for n in prep.CHANGED[c])
NEW=(('fe.World','0','1','rconnectLoadingHold'),('fe.World','0','1','rconnectCancelLoading'),
 ('fe.graph.Grafon','0','2','rconnectRasterPending'),('fe.graph.Grafon','0','1','rconnectRasterWaiting'),
 ('fe.graph.Grafon','0','1','rconnectRasterPainted'))
NEW_NAMES=tuple(c+'::'+s+':'+k+':'+n for c,s,k,n in NEW)
FIELDS=(('fe.loc.Game','1','rconnectTravelBridge','Function','0'),
 ('fe.loc.Game','1','rconnectEarlyTravelVersion','int','6'),
 ('fe.graph.Grafon','1','rconnectRasterBridge','Function','0'),
 ('fe.graph.Grafon','0','rconnectRasterTicket','Object','0'))
CINITS=('fe.loc.Game::<static>','fe.graph.Grafon::<static>')
GAME_TAIL='fe.loc.Game::0:1:enterToCurLand'
IGNORED={'bytes','fileOffset'}
def require(ok,message):
 if not ok:raise AssertionError(message)
def traits(abc,cls,scope):
 i=abc.class_by_name[cls];node=abc.statics[i] if scope=='1' else abc.instances[i]
 return node.find('static_traits/traits' if scope=='1' else 'instance_traits/traits')
def key(abc,t):return (t.get('type'),t.get('kindType'),abc.simple(int(t.get('name_index'))))
def table(abc,cls,scope):
 ts=list(traits(abc,cls,scope));out={key(abc,t):t for t in ts};require(len(out)==len(ts),'Ambiguous original trait');return out
def namespace(abc,mn):
 x=abc.cp['constant_multiname'][mn];require(x.get('kind')=='7','Expected QName trait')
 return int(x.get('namespace_index'))
def nsname(abc,i):return abc.string(int(abc.cp['constant_namespace'][i].get('name_index')))
def members(abc,i):return [int(x.text) for x in abc.cp['constant_namespace_set'][i].findall('namespaces/item')]
def body_names(abc,index):
 b=abc.bodies[index];rows,addresses=core.decode(bytes.fromhex(b.get('codeBytes')))
 # No implicit method/slot relocation; unknown donor shapes must stop.
 slotproof.prove(abc,index,core)
 names={v for r in rows for k,v in r[3] if k=='n'}
 for e in b.find('exceptions'):
  names.update(int(e.get(k,'0')) for k in ('type_index','name_index'))
 for t in b.findall('traits/traits/item'):
  require(t.get('type')=='TraitSlotConst','Unreviewed activation function trait')
  names.update(int(t.get(k,'0')) for k in ('name_index','type_index'))
 names.discard(0);core.Compare.exceptions(b,abc,addresses)
 return names
def namespace_map(a,b):
 mapping={};evidence=[];oldcount=len(a.cp['constant_namespace'])
 def pair(ni,oi,label):
  if ni==oi:return
  require(ni>=oldcount and a.cp['constant_namespace'][oi].get('kind')==b.cp['constant_namespace'][ni].get('kind')=='5','Only fresh private namespace may map')
  require(nsname(a,oi)==nsname(b,ni),'Private lexical URI changed')
  require(mapping.get(ni,oi)==oi,'Private namespace ambiguity');mapping[ni]=oi
  evidence.append(dict(source=label,donor=ni,retained=oi,uri=nsname(a,oi)))
 # Existing declaration identities are primary anchors, not pool-name guesses.
 for cls in prep.CLASSES:
  for scope in ('0','1'):
   old,new=table(a,cls,scope),table(b,cls,scope)
   for k,t in old.items():
    require(k in new,'Original trait missing '+str(k))
    pair(namespace(b,int(new[k].get('name_index'))),namespace(a,int(t.get('name_index'))),cls+'/'+str(k))
 # Match fresh lexical sets only against real scopes already used in this class.
 for cls in prep.CLASSES:
  oldsets=set();newsets=set();direct=set()
  for name,index in a.named.items():
   if not name.startswith(cls+'::') or index not in a.bodies:continue
   rows,_=core.decode(bytes.fromhex(a.bodies[index].get('codeBytes')))
   for r in rows:
    for k,v in r[3]:
     if k=='n':
      ns=int(a.cp['constant_multiname'][v].get('namespace_set_index','0'))
      if ns:oldsets.add(ns)
  for name in (*TARGETS,*NEW_NAMES):
   if not name.startswith(cls+'::'):continue
   if name==GAME_TAIL:continue # Native body retained; appended tail is public QName only.
   for v in body_names(b,b.named[name]):
    mn=b.cp['constant_multiname'][v];ns=int(mn.get('namespace_set_index','0'));di=int(mn.get('namespace_index','0'))
    if ns:newsets.add(ns)
    if di:direct.add(di)
  for ns in newsets:
   current=members(b,ns)
   if all(i<oldcount for i in current):continue
   possible=[]
   for oldset in oldsets:
    original=members(a,oldset)
    if len(original)!=len(current):continue
    okay=True
    for ni,oi in zip(current,original):
     if ni==oi:continue
     if ni<oldcount or b.cp['constant_namespace'][ni].get('kind')!='5' or a.cp['constant_namespace'][oi].get('kind')!='5' or nsname(b,ni)!=nsname(a,oi) or mapping.get(ni,oi)!=oi:okay=False;break
    if okay:possible.append((oldset,original))
   require(len(possible)==1,cls+' fresh lexical scope has no unique original anchor')
   oldset,original=possible[0]
   for ni,oi in zip(current,original):pair(ni,oi,cls+'/lexical '+str(ns)+'->'+str(oldset))
   evidence.append(dict(source=cls,donorSet=ns,retainedSet=oldset,donorMembers=current,retainedMembers=original))
  for ni in direct:
   require(ni<oldcount or b.cp['constant_namespace'][ni].get('kind')!='5' or ni in mapping,'Unbound direct private name')
 return mapping,evidence
def normalized_donor(a,node,b,mapping):
 out=copy.deepcopy(node);constants=out.find('constants')
 for n in list(constants.find('constant_multiname'))[len(a.cp['constant_multiname']):]:
  i=int(n.get('namespace_index','0'))
  if i in mapping:n.set('namespace_index',str(mapping[i]))
 for n in list(constants.find('constant_namespace_set'))[len(a.cp['constant_namespace_set']):]:
  for item in n.findall('namespaces/item'):
   i=int(item.text)
   if i in mapping:item.text=str(mapping[i])
 return out,core.ABC(out)
def u30(v):
 out=bytearray()
 while v>=128:out.append((v&127)|128);v>>=7
 out.append(v);return bytes(out)
def static_body(a,cls,fields):
 old=a.bodies[a.named[cls+'::<static>']];code=bytes.fromhex(old.get('codeBytes'));rows,_=core.decode(code)
 require(code[-1:]==b'\x47' and rows[-1][2]==0x47,'Static initializer must end returnvoid')
 require(not any(k=='target' for r in rows for k,v in r[3]) and sum(r[2] in (0x47,0x48) for r in rows)==1,'Static initializer must be single-path')
 require(not list(old.find('exceptions')) and not list(old.find('traits/traits')),'Unexpected static catch/activation')
 extra=b''
 for name,mn in fields:
  # This class object is local0 in the original cinit. Literal-only new writes.
  extra+=b'\xd0'+(b'\x24\x01\x68' if name=='rconnectEarlyTravelVersion' else b'\x20\x61')+u30(mn)
 body=copy.deepcopy(old);body.set('codeBytes',(code[:-1]+extra+b'\x47').hex());body.set('max_stack',str(max(2,int(old.get('max_stack')))))
 return body,dict(originalCodeSHA256=hashlib.sha256(code).hexdigest(),insertBeforeFinalReturn=extra.hex(),originalInstructionsByteExact=True,
  maxStackBefore=old.get('max_stack'),maxStackAfter=body.get('max_stack'),onlyNewStaticWrites=[n for n,_ in fields])

def game_body(a,b):
 old=a.bodies[a.named[GAME_TAIL]];donor=b.bodies[b.named[GAME_TAIL]]
 code=bytes.fromhex(old.get('codeBytes'));fresh=bytes.fromhex(donor.get('codeBytes'))
 rows,_=core.decode(code);newrows,_=core.decode(fresh);tail=newrows[-9:]
 require([r[2] for r in tail]==[0x60,0x20,0x13,0x5d,0x2c,0xd0,0x20,0x4f,0x47],'Unexpected constructed tail')
 bridge=tail[0][3][0][1];mn=b.cp['constant_multiname'][bridge]
 require(mn.get('kind')=='7' and b.simple(bridge)=='rconnectTravelBridge','Tail bridge must be direct QName')
 ns=int(mn.get('namespace_index'));require(b.cp['constant_namespace'][ns].get('kind')=='22' and nsname(b,ns)=='','Tail bridge must be public')
 require(tail[3][3]==[('n',bridge)] and tail[7][3]==[('n',bridge),('u',3)],'Tail callback binding/arity changed')
 require(b.string(tail[4][3][0][1])=='constructed' and tail[2][3]==[('target',tail[-1][0])],'Tail event or branch changed')
 require(code[-1:]==b'\x47' and sum(r[2] in (0x47,0x48) for r in rows)==1,'Native Game must have one terminal return')
 require(not list(old.find('exceptions')) and not list(old.find('traits/traits')),'Native Game has unexpected protected/activation region')
 require(all(v<=rows[-1][0] for r in rows for k,v in r[3] if k=='target'),'Native Game branch beyond insertion point')
 # Old jump targets, instruction offsets and frame are unchanged. A jump to
 # the old terminal return now enters the appended conditional callback.
 insert=fresh[tail[0][0]:];result=copy.deepcopy(old);result.set('codeBytes',(code[:-1]+insert).hex())
 require(int(old.get('max_stack'))>=4,'Tail operand capacity insufficient')
 return result,dict(original_instructions_byte_exact=True,original_prefix_sha256=hashlib.sha256(code[:-1]).hexdigest(),
  insertion_offset=len(code)-1,inserted_tail_hex=insert.hex(),public_bridge_multiname=bridge,
  original_branches_and_frame_preserved=True,no_native_exception_region=True)
def retain(base_xml,donor_xml,out_xml):
 require(sha(base_xml)==prep.PINS[prep.BASE_XML],'Wrong A796 XML');out_xml=Path(out_xml)
 require(not out_xml.exists() and out_xml.parent.is_relative_to(ROOT/'build/m52'),'New isolated XML required')
 tree,donor=ET.parse(base_xml),ET.parse(donor_xml);aa,bb=tree.findall('.//abc'),donor.findall('.//abc')
 require(len(aa)==len(bb)==2,'Expected two ABCs');a,b=core.ABC(aa[0]),core.ABC(bb[0]);prefix=support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other ABC changed in donor')
 require(set(a.class_by_name)==set(b.class_by_name),'Class set changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and set(a.named)<=set(b.named),'Unexpected new/missing method')
 mapping,evidence=namespace_map(a,b);normal,n=normalized_donor(a,bb[0],b,mapping)
 # Keep the entire original XML skeleton. Only append constants and members.
 constants=aa[0].find('constants');pos=list(aa[0]).index(constants);aa[0].remove(constants);aa[0].insert(pos,copy.deepcopy(normal.find('constants')))
 bodies=aa[0].find('bodies');infos=aa[0].find('method_info');proof=[];new_indices={}
 for name in TARGETS:
  oi,ni=a.named[name],n.named[name];old_info=a.methods[oi];info=copy.deepcopy(n.methods[ni]);info.set('name_index',old_info.get('name_index'))
  oldflags=int(old_info.get('flags'));newflags=int(info.get('flags'));require((newflags^oldflags)&~2==0,name+' flags changed beyond activation')
  info.set('flags',old_info.get('flags'))
  # Exact old signature metadata is retained; only NEED_ACTIVATION can follow body.
  require(canonical(info)==canonical(old_info),name+' signature differs')
  local_proof=slotproof.prove(n,ni,core)
  old_info.set('flags',str(newflags))
  tail_proof=None
  if name==GAME_TAIL:
   require(newflags==oldflags,'Game native flags must not change');body,tail_proof=game_body(a,n)
  else:body_names(n,ni);body=copy.deepcopy(n.bodies[ni]);body.set('method_info',str(oi))
  at=list(bodies).index(a.bodies[oi]);bodies.remove(a.bodies[oi]);bodies.insert(at,body)
  proof.append(dict(name=name,oldIndex=oi,donorIndex=ni,flagsBefore=oldflags,flagsAfter=newflags,local_slot_proof=local_proof,native_tail_proof=tail_proof,codeSHA256=hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest()))
 for name in NEW_NAMES:
  ni=n.named[name];idx=len(infos);new_indices[name]=idx
  info=copy.deepcopy(n.methods[ni]);infos.append(info);body_names(n,ni)
  local_proof=slotproof.prove(n,ni,core)
  body=copy.deepcopy(n.bodies[ni]);body.set('method_info',str(idx));bodies.append(body)
  proof.append(dict(name=name,newIndex=idx,donorIndex=ni,local_slot_proof=local_proof,codeSHA256=hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest()))
 added_traits=[];static_fields={c:[] for c in ('fe.loc.Game','fe.graph.Grafon')}
 for cls,scope,kind,name in NEW:
  t=copy.deepcopy(table(n,cls,scope)[('TraitMethodGetterSetter',kind,name)])
  t.set('method_info',str(new_indices[cls+'::'+scope+':'+kind+':'+name]));t.set('disp_id','0')
  traits(a,cls,scope).append(t);added_traits.append(dict(cls=cls,scope=scope,name=name,kind=kind))
 for cls,scope,name,typ,kind in FIELDS:
  t=copy.deepcopy(table(n,cls,scope)[('TraitSlotConst',kind,name)])
  require(n.qualified(int(t.get('type_index')))==typ,'Wrong new field type')
  mn=int(t.get('name_index'));ns=namespace(n,mn);space=n.cp['constant_namespace'][ns]
  require((space.get('kind')=='5') if name=='rconnectRasterTicket' else (space.get('kind')=='22' and nsname(n,ns)==''),'Wrong field namespace')
  if name!='rconnectEarlyTravelVersion':require(int(t.get('value_index','0'))==0 or n.constant(int(t.get('value_kind')),int(t.get('value_index')))[0:2]==('literal',12),'New reference field has non-null default')
  t.set('slot_id','0');traits(a,cls,scope).append(t)
  added_traits.append(dict(cls=cls,scope=scope,name=name,kind=kind,type=typ,slot='auto-assigned-after-original-traits',defaultValueIndex=t.get('value_index')))
  if scope=='1':static_fields[cls].append((name,mn))
 static_proof={}
 for cls,fs in static_fields.items():
  body,detail=static_body(a,cls,fs);oi=a.named[cls+'::<static>'];at=list(bodies).index(a.bodies[oi]);bodies.remove(a.bodies[oi]);bodies.insert(at,body);static_proof[cls]=detail
 tree.write(out_xml,encoding='utf-8',xml_declaration=True)
 result=dict(passed=True,base_sha256=prep.HOST_SHA,base_xml_sha256=sha(base_xml),donor_xml_sha256=sha(donor_xml),retained_xml_sha256=sha(out_xml),
  changed_original_methods=list(TARGETS),new_methods=list(NEW_NAMES),new_traits=added_traits,static_initializers=static_proof,
  namespace_mappings=evidence,appended_constants=prefix,method_proof=proof,runtime_validated=False)
 # Audit the retained tree against original before allowing serialization.
 result['preservation']=audit(base_xml,out_xml,out_xml)
 return result
def audit(base_xml,final_xml,retained_xml):
 require(sha(base_xml)==prep.PINS[prep.BASE_XML],'Wrong audit base')
 aa=ET.parse(base_xml).findall('.//abc');bb=ET.parse(final_xml).findall('.//abc');cc=ET.parse(retained_xml).findall('.//abc')
 require(len(aa)==len(bb)==len(cc)==2,'Wrong audit ABC count')
 require(all(canonical(x)==canonical(y) for x,y in zip(bb,cc)),'Actual round trip differs from retained XML')
 a,b=core.ABC(aa[0]),core.ABC(bb[0]);support.prefix(a,b)
 require(canonical(aa[1])==canonical(bb[1]),'Other original ABC changed')
 require(a.class_by_name==b.class_by_name and all(b.named[n]==i for n,i in a.named.items()),'Old named indices changed')
 require(set(b.named)-set(a.named)==set(NEW_NAMES) and len(b.methods)==len(a.methods)+5,'Unexpected method additions')
 modified={a.named[n] for n in (*TARGETS,*CINITS)};count=0
 for i,old in enumerate(a.methods):
  new=copy.deepcopy(b.methods[i])
  if i in {a.named[n] for n in TARGETS}:
   require((int(new.get('flags'))^int(old.get('flags')))&~2==0,'Unexpected old flags change');new.set('flags',old.get('flags'))
  require(canonical(old)==canonical(new),'Old method metadata changed '+str(i))
 for i,old in a.bodies.items():
  if i not in modified:require(canonical(old)==canonical(b.bodies[i]),'Non-target body changed '+str(i));count+=1
 require(set(b.bodies)==set(a.bodies)|{b.named[n] for n in NEW_NAMES},'Body table shape changed')
 for cls,index in a.class_by_name.items():
  for scope,old,new,container in [('0',a.instances[index],b.instances[index],'instance_traits/traits'),('1',a.statics[index],b.statics[index],'static_traits/traits')]:
   original=list(old.find(container));actual=list(new.find(container));expected_added=[n for c,s,k,n in NEW if c==cls and s==scope]+[n for c,s,n,t,k in FIELDS if c==cls and s==scope]
   require(len(actual)==len(original)+len(expected_added),'Trait count changed '+cls)
   require(all(canonical(x)==canonical(y) for x,y in zip(original,actual)),'Old trait changed '+cls)
   require([b.simple(int(t.get('name_index'))) for t in actual[len(original):]]==expected_added,'Wrong appended trait order '+cls)
   stripped=copy.deepcopy(new);ts=stripped.find(container)
   for t in list(ts)[len(original):]:ts.remove(t)
   require(canonical(old)==canonical(stripped),'Original class header/constructor/interface changed '+cls)
 require(canonical(aa[0].find('script_info'))==canonical(bb[0].find('script_info')),'Script layout changed')
 for n in aa[0]:
  if n.tag not in {'constants','method_info','bodies','instance_info','class_info'}:require(canonical(n)==canonical(bb[0].find(n.tag)),'Other ABC data changed '+n.tag)
 return dict(passed=True,exact_retained_roundtrip=True,non_target_bodies_byte_exact=count,old_method_indices_preserved=True,
  original_class_script_traits_preserved=True,original_constructors_byte_exact=True,old_constant_prefix_preserved=True,
  allowed_changed_bodies=list(TARGETS)+list(CINITS),added_methods=5,added_fields=4,runtime_validated=False)
def splice(base,serialized,out):
 require(sha(base)==prep.HOST_SHA,'Wrong splice A796')
 old=support.BASE_SWF_SHA
 try:support.BASE_SWF_SHA=prep.HOST_SHA;return support.splice(base,serialized,out)
 finally:support.BASE_SWF_SHA=old
