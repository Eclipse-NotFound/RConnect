"""Read existing host04 XML only; write independent static review evidence here."""
from pathlib import Path
import hashlib
import importlib.util
import json
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
INPUT = ROOT / 'mods/RConnect/build/m52/recovery-ordinary-wall-sv-host-04'
CORE = ROOT / 'mods/ContinuousScene/build/native-crop-audit.py'
spec = importlib.util.spec_from_file_location('host04_review_core', CORE)
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)
IGNORE = {'bytes', 'fileOffset'}
GRAFON = 'fe.graph.Grafon'
LOCATION = 'fe.loc.Location'

def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def value(node):
    return core.xml_value(node, IGNORE)

def digest(node):
    return hashlib.sha256(repr(value(node)).encode()).hexdigest()

def abc_nodes(path):
    # Discard decoded art as it streams past; retain only the two ABC nodes.
    result, depth, active = [], 0, None
    for event, node in ET.iterparse(path, events=('start', 'end')):
        if event == 'start':
            depth += 1
            if node.tag == 'abc':
                if active is not None:
                    raise RuntimeError('Nested ABC')
                active = depth
        else:
            if node.tag == 'abc':
                result.append(node)
                active = None
            elif active is None:
                node.clear()
            depth -= 1
    return result

def body_hash(body):
    return hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest()

def member_ids(abc, name):
    return {i for n, i in abc.named.items() if n.startswith(name + '::')}

def closure_ids(abc, roots):
    ids, edges, todo = set(roots), [], list(roots)
    while todo:
        i = todo.pop()
        if i not in abc.bodies:
            continue
        rows, _ = core.decode(bytes.fromhex(abc.bodies[i].get('codeBytes')))
        for row in rows:
            if row[2] == 0x40:
                j = row[3][0][1]
                if j in abc.names_by_method:
                    raise RuntimeError('newfunction refers to a named class method')
                edges.append({'from': i, 'to': j, 'offset': row[0]})
                if j not in ids:
                    ids.add(j)
                    todo.append(j)
    return ids, edges

def incoming_method_refs(abc, targets, owners):
    # Read operand widths without validating legacy branch destinations. No
    # old bytecode is rewritten; this only checks ownership of retained closures.
    incoming, foreign = [], []
    for method, body in abc.bodies.items():
        data=bytes.fromhex(body.get('codeBytes')); cursor=0
        def integer():
            nonlocal cursor
            val=0
            for shift in range(0,35,7):
                if cursor>=len(data):raise RuntimeError('Truncated operand')
                byte=data[cursor];cursor+=1;val|=(byte&127)<<shift
                if byte<128:return val
            raise RuntimeError('Overlong operand')
        while cursor<len(data):
            start=cursor; op=data[cursor];cursor+=1
            if op==0x1b:
                cursor+=3;count=integer();cursor+=3*(count+1)
            else:
                if op not in core.OPS:raise RuntimeError('Unknown reference-scan opcode')
                for kind in core.OPS[op]:
                    if kind=='b':cursor+=1
                    elif kind=='j':cursor+=3
                    else:
                        v=integer()
                        if kind=='m' and v in targets:
                            edge={'from':method,'to':v,'offset':start,'opcode':op}
                            incoming.append(edge)
                            if method not in owners:foreign.append(edge)
            if cursor>len(data):raise RuntimeError('Operand exceeds body')
    return {'incoming':incoming,'foreign':foreign}

class ResolvedABC(core.ABC):
    """Resolve pool slots only; keep private namespace identity, kind and URI."""
    def namespace(self, index):
        n = self.cp['constant_namespace'][index]
        kind = int(n.get('kind'))
        return (kind, index if kind == 5 else None,
                self.string(int(n.get('name_index', '0'))))

    def multiname(self, index):
        if index == 0:
            return ('wildcard',)
        n = self.cp['constant_multiname'][index]
        kind = int(n.get('kind'))
        if kind in (7, 13):
            return (kind, self.namespace(int(n.get('namespace_index'))), self.string(int(n.get('name_index'))))
        if kind in (9, 14, 27, 28):
            ns = self.cp['constant_namespace_set'][int(n.get('namespace_set_index'))]
            return (kind, self.string(int(n.get('name_index', '0'))),
                    tuple(self.namespace(int(v.text)) for v in ns.findall('namespaces/item')))
        if kind in (15, 16):
            return (kind, self.string(int(n.get('name_index'))))
        if kind in (17, 18):
            return (kind,)
        if kind == 29:
            return (kind, self.multiname(int(n.get('qname_index'))), tuple(self.multiname(int(x.text)) for x in n.find('params')))
        raise RuntimeError('Unreviewed multiname kind: '+str(kind))

class ResolvedCompare(core.Compare):
    @staticmethod
    def exceptions(body, abc, addresses):
        result = []
        for item in body.find('exceptions'):
            entry = []
            for key, val in sorted(item.attrib.items()):
                if key in ('start', 'end', 'from', 'to', 'target'):
                    if int(val) not in addresses:
                        raise RuntimeError('Exception endpoint is not an instruction boundary')
                    entry.append((key, addresses[int(val)]))
                elif key in ('type_index', 'name_index'):
                    entry.append((key, abc.multiname(int(val))))
                else:
                    entry.append((key, val))
            result.append(entry)
        return result

def stage_compare(a_node, b_node, index):
    a, b = core.ABC(a_node), core.ABC(b_node)
    gi, old_edges = closure_ids(a, member_ids(a, GRAFON))
    new_gi, new_edges = closure_ids(b, member_ids(b, GRAFON))
    incoming=incoming_method_refs(a,gi-member_ids(a,GRAFON),gi)
    new_incoming=incoming_method_refs(b,new_gi-member_ids(b,GRAFON),new_gi)
    changed_info, changed_bodies, new_methods, layout_changes = [], [], [], []
    for i, m in enumerate(a.methods):
        if i >= len(b.methods) or value(m) != value(b.methods[i]):
            changed_info.append({'index': i, 'name': a.names_by_method.get(i)})
    for i, m in a.bodies.items():
        if i not in b.bodies or value(m) != value(b.bodies[i]):
            changed_bodies.append({'index': i, 'name': a.names_by_method.get(i)})
    for i in range(len(a.methods), len(b.methods)):
        new_methods.append({'index': i, 'name': b.names_by_method.get(i)})
    for name, i in a.class_by_name.items():
        j = b.class_by_name.get(name)
        for table, aa, bb in [('instance', a.instances, b.instances), ('static', a.statics, b.statics)]:
            if j is None or value(aa[i]) != value(bb[j]):
                layout_changes.append({'class': name, 'part': table})
    prefix = {}
    for kind, old in a.cp.items():
        new = b.cp.get(kind, [])
        mismatch = [i for i, n in enumerate(old) if i >= len(new) or core.xml_value(n) != core.xml_value(new[i])]
        prefix[kind] = {'old': len(old), 'new': len(new), 'mismatchedIndices': mismatch}
    non_grafon_info = [x for x in changed_info if x['index'] not in gi]
    non_grafon_body = [x for x in changed_bodies if x['index'] not in gi]
    classes_equal = a.class_by_name == b.class_by_name
    non_grafon_named_equal = {n:i for n,i in a.named.items() if not n.startswith(GRAFON+'::')} == {n:i for n,i in b.named.items() if not n.startswith(GRAFON+'::')}
    li = a.class_by_name.get(LOCATION)
    location = None
    if li is not None:
        ids = member_ids(a, LOCATION)
        location = {
            'classIndex': li, 'methodCountIncludingConstructors': len(ids),
            'methodInfoExact': all(i < len(b.methods) and value(a.methods[i]) == value(b.methods[i]) for i in ids),
            'completeBodiesExact': all((i not in a.bodies and i not in b.bodies) or (i in a.bodies and i in b.bodies and value(a.bodies[i]) == value(b.bodies[i])) for i in ids),
            'instanceTraitsHeaderExact': value(a.instances[li]) == value(b.instances[li]),
            'staticTraitsHeaderExact': value(a.statics[li]) == value(b.statics[li]),
            'constructorMethods': {n: {'index': a.named[n], 'codeSha256': body_hash(a.bodies[a.named[n]])} for n in [LOCATION+'::<init>', LOCATION+'::<static>']},
            'unchangedMethodCodeHashes': {n: body_hash(a.bodies[i]) for n,i in a.named.items() if i in ids and i in a.bodies},
        }
    covered = {'constants','method_info','bodies','instance_info','class_info','script_info'}
    other_exact = [value(n) for n in a_node if n.tag not in covered] == [value(n) for n in b_node if n.tag not in covered]
    out = {
        'abcIndex': index, 'headerExact': a_node.attrib == b_node.attrib,
        'classIndicesExact': classes_equal, 'nonGrafonNamedIndicesExact': non_grafon_named_equal,
        'methodInfoCounts': [len(a.methods), len(b.methods)], 'bodyCounts': [len(a.bodies),len(b.bodies)],
        'changedOldMethodInfo': changed_info, 'changedOldBodies': changed_bodies, 'newMethods': new_methods,
        'nonGrafonMethodInfoChanges': non_grafon_info, 'nonGrafonBodyChanges': non_grafon_body,
        'classLayoutChanges': layout_changes, 'constantPrefix': prefix,
        'grafonOwnedMethodIds': sorted(gi), 'grafonOwnedClosureEdges': old_edges,
        'newGrafonOwnedMethodIds': sorted(new_gi), 'newGrafonOwnedClosureEdges': new_edges,
        'grafonClosureIncomingReferences': incoming, 'newGrafonClosureIncomingReferences': new_incoming,
        'scriptInfoExact': value(a_node.find('script_info')) == value(b_node.find('script_info')),
        'otherMetadataExact': other_exact, 'location': location,
        'unchangedNonGrafonBodyCount': sum(i not in gi and i in b.bodies and value(n) == value(b.bodies[i]) for i,n in a.bodies.items()),
    }
    out['nonGrafonPreserved'] = all((out['headerExact'],classes_equal,non_grafon_named_equal,
        not non_grafon_info, not non_grafon_body,
        all(x['class']==GRAFON for x in layout_changes), out['scriptInfoExact'],other_exact,
        all(not x['mismatchedIndices'] for x in prefix.values()),
        set(a.cp)==set(b.cp),set(a.bodies)<=set(b.bodies),
        all(x['index'] in new_gi for x in new_methods),not incoming['foreign'],not new_incoming['foreign']))
    return out

def donor_compare(b_node, d_node, index):
    b, d = ResolvedABC(b_node), ResolvedABC(d_node)
    names = sorted(n for n in b.named if n.startswith(GRAFON+'::'))
    out = {'abcIndex':index,'methodCount':len(names),'sameNamedMethods':names==sorted(n for n in d.named if n.startswith(GRAFON+'::')),
           'exactMethodInfo':[],'differentMethodInfo':[],'exactBodies':[],'semanticEquivalentBodies':[],'differentBodies':[],'classLayoutExact':None}
    if not names:return out
    compare=ResolvedCompare(b,d)
    for n in names:
        if n not in d.named:
            out['differentBodies'].append({'name':n,'error':'missing'});continue
        i,j=b.named[n],d.named[n]
        if value(b.methods[i])==value(d.methods[j]):out['exactMethodInfo'].append(n)
        else:
            try:
                core.require(b.signature(i)==d.signature(j),'signature differs')
                out['differentMethodInfo'].append({'name':n,'semanticallyEqual':True,'indices':[i,j]})
            except Exception as e:out['differentMethodInfo'].append({'name':n,'semanticallyEqual':False,'error':str(e)})
        if value(b.bodies[i])==value(d.bodies[j]):out['exactBodies'].append(n)
        else:
            try:
                compare.body(i,j,n)
                out['semanticEquivalentBodies'].append(n)
            except Exception as e:out['differentBodies'].append({'name':n,'error':str(e)})
    bi,di=b.class_by_name[GRAFON],d.class_by_name[GRAFON]
    out['classLayoutRawExact']={'instance':value(b.instances[bi])==value(d.instances[di]),'static':value(b.statics[bi])==value(d.statics[di])}
    layouts = {}
    for part,x,y,path in [('instance',b.instances[bi],d.instances[di],'instance_traits/traits'),('static',b.statics[bi],d.statics[di],'static_traits/traits')]:
        if x.attrib != y.attrib:
            layouts[part] = False
        else:
            xt,yt=x.find(path),y.find(path)
            layouts[part]=len(xt)==len(yt) and all(compare.trait(u,b)==compare.trait(v,d) and u.get('method_info')==v.get('method_info') for u,v in zip(xt,yt))
    out['classLayoutExact']=layouts
    old_ids, old_edges=closure_ids(b,member_ids(b,GRAFON))
    new_ids, new_edges=closure_ids(d,member_ids(d,GRAFON))
    out['closureEdgesExact']=old_edges==new_edges
    out['anonymousBodiesExact']=sorted(old_ids-member_ids(b,GRAFON)) if old_ids==new_ids and all(value(b.bodies[i])==value(d.bodies[i]) for i in old_ids-member_ids(b,GRAFON)) else None
    return out

def location_scope_evidence(node):
    abc=ResolvedABC(node)
    ci=abc.class_by_name[LOCATION]
    script=next(x for x in node.find('script_info') if any(t.get('type')=='TraitClass' and t.get('class_info')==str(ci) for t in x.findall('traits/traits/*')))
    si=int(script.get('init_index'))
    sb=abc.bodies[si]
    hi=abc.named[LOCATION+'::0:1:hitTile']
    hb=abc.bodies[hi]
    rows,_=core.decode(bytes.fromhex(hb.get('codeBytes')))
    return {'classIndex':ci,'scriptIndex':si,'scriptCodeSha256':body_hash(sb),
        'scriptFrame':{k:v for k,v in sb.attrib.items() if k not in ('method_info','codeBytes')},
        'hitTileMethodIndex':hi,'hitTileFlags':abc.methods[hi].get('flags'),
        'hitTileFrame':{k:v for k,v in hb.attrib.items() if k not in ('method_info','codeBytes')},
        'getScopeObjectOperands':sorted({r[3][0][1] for r in rows if r[2]==0x65}),
        'getOuterScopeCount':sum(r[2]==0x67 for r in rows),
        'newActivationCount':sum(r[2]==0x57 for r in rows),
        'newCatchCount':sum(r[2]==0x5a for r in rows),
        'activationTraits':[{'slot':int(t.get('slot_id')),'name':abc.simple(int(t.get('name_index'))),'type':abc.multiname(int(t.get('type_index')))} for t in hb.findall('traits/traits/*')],
        'exceptions':[dict(x.attrib) for x in hb.find('exceptions')]}

def main():
    paths={k:INPUT/v for k,v in [('acc','acc.xml'),('grafonOnly','grafon-only.xml'),('donor03','donor03.xml')]}
    nodes={}
    for k,p in paths.items():
        nodes[k]=abc_nodes(p)
        print(k,'ABC nodes',len(nodes[k]),flush=True)
    if len({len(x) for x in nodes.values()})!=1:raise RuntimeError('ABC counts differ')
    result={'kind':'independent-static-intermediate-review','inputs':{k:{'path':str(p),'sha256':sha(p)} for k,p in paths.items()},
            'reviewScriptSha256':sha(Path(__file__)),'comparatorSha256':sha(CORE),'stage':[], 'grafonVsDonor03':[],
            'finalHostQualified':False,'gameplayQualified':False,'airStarted':False,'jvmStarted':False,'installed':False}
    result['locationScopeEvidence']={k:location_scope_evidence(n[0]) for k,n in nodes.items()}
    for i,(a,b,d) in enumerate(zip(nodes['acc'],nodes['grafonOnly'],nodes['donor03'])):
        result['stage'].append(stage_compare(a,b,i))
        result['grafonVsDonor03'].append(donor_compare(b,d,i))
    result['intermediateNonGrafonPreserved']=all(x['nonGrafonPreserved'] for x in result['stage'])
    result['grafonMatchesReviewedDonor']=all(x['sameNamedMethods'] and not x['differentBodies'] and all(z['semanticallyEqual'] for z in x['differentMethodInfo']) and (x['classLayoutExact'] is None or (all(x['classLayoutExact'].values()) and x['closureEdgesExact'] and x['anonymousBodiesExact'] is not None)) for x in result['grafonVsDonor03'])
    (HERE/'evidence-final-static.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:result[k] for k in ('intermediateNonGrafonPreserved','grafonMatchesReviewedDonor','finalHostQualified')},ensure_ascii=False),flush=True)
    for x in result['stage']:
        print('stage',x['abcIndex'],'nonGrafon',x['nonGrafonMethodInfoChanges'],x['nonGrafonBodyChanges'],'layouts',x['classLayoutChanges'],'scripts',x['scriptInfoExact'],flush=True)
    for x in result['grafonVsDonor03']:
        print('donor',x['abcIndex'],'exactBodies',len(x['exactBodies']),'equivalent',len(x['semanticEquivalentBodies']),'different',x['differentBodies'],flush=True)

if __name__=='__main__':main()
