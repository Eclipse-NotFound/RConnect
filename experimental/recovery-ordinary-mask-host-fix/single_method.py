"""One reviewed Grafon whitelist method; no JVM, AIR, or installation writes."""
from __future__ import annotations
import copy
import gc
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import zlib

if sys.flags.optimize:
    raise RuntimeError('Optimized Python is forbidden')
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SUPPORT = ROOT / 'experimental/recovery-ordinary-method-transplant/method_transplant.py'
SUPPORT_SHA = 'c422c540490d553e6a21415b9cdb4232f287069b4b1f18a075e51d224a59268e'
# Exact host05 final export, not a new export.
BASE_XML_SHA = '42c4a1a5c005e9a6ccf5e71871ad466348727378afb2488bd4a6d532ea5a6ef4'
BASE_SWF_SHA = '00c7c511ffa51745cb4932e820365091d2540978eedd6dfe726a5cfd7818aa48'
TARGET = 'fe.graph.Grafon::0:1:ordinaryMaskBounds'
BASE_BODY_SHA = '7d58c782645daa558bb31c60cca8211ebe5edbb25762d6526460cc416ca6574c'
ORIGINAL = ('TileMask', 'TileMaskDamaged', 'TileMaskBare', 'BorderMask', 'FloorMask', 'SkolMask')
ADDED = ('maskSimple', 'maskBare', 'maskBorderBare', 'maskDamaged', 'maskSkol', 'maskStone',
         'maskStoneBorder', 'maskDirt', 'maskDirtBorder', 'maskFloor', 'maskMetalBorder')

def require(ok, message):
    if not ok:
        raise AssertionError(message)

def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

require(sha(SUPPORT) == SUPPORT_SHA, 'Frozen transplant support changed')
spec = importlib.util.spec_from_file_location('mask_frozen_support', SUPPORT)
support = importlib.util.module_from_spec(spec)
spec.loader.exec_module(support)
core, canonical, digest = support.core, support.canonical, support.digest

def dependencies():
    require(sha(SUPPORT) == SUPPORT_SHA, 'Frozen support changed')
    return {**support.dependencies(), str(Path(__file__).resolve()): sha(__file__)}

def trait_name(abc, label):
    ci = abc.class_by_name['fe.graph.Grafon']
    scope = 'static_traits/traits' if label == 'ordinaryUnion' else 'instance_traits/traits'
    node = abc.statics[ci] if label == 'ordinaryUnion' else abc.instances[ci]
    matches = [int(t.get('name_index')) for t in node.find(scope)
               if t.get('type') == 'TraitMethodGetterSetter' and abc.simple(int(t.get('name_index'))) == label]
    require(len(matches) == 1, 'Ambiguous real Grafon trait: ' + label)
    mn = abc.cp['constant_multiname'][matches[0]]
    require(mn.get('kind') == '7', 'Private method is not a QName')
    ns = int(mn.get('namespace_index'))
    require(abc.cp['constant_namespace'][ns].get('kind') == '5', 'Expected class private namespace')
    return matches[0], ns

def mappings(a, b, body):
    """Map only three actual private declarations and the two reviewed ns-set forms."""
    result, proof = {}, []
    old_ns = new_ns = None
    for label in ('ordinaryUnion', 'ordinaryArtBounds', 'sceneDecalTransformBounds'):
        oi, ons = trait_name(a, label); ni, nns = trait_name(b, label)
        require(old_ns in (None, ons) and new_ns in (None, nns), 'Inconsistent class-private identity')
        old_ns, new_ns = ons, nns
        result[ni] = oi
        proof.append(dict(kind='actual-class-trait', name=label, donor=ni, retained=oi))
    rows, _ = core.decode(bytes.fromhex(body.get('codeBytes')))
    used = {v for row in rows for k, v in row[3] if k == 'n'}
    for ni in used:
        mn = b.cp['constant_multiname'][ni]
        ns = int(mn.get('namespace_index', '0'))
        if ns and b.cp['constant_namespace'][ns].get('kind') == '5':
            require(ni in result, 'Unreviewed private QName')
        nsi = int(mn.get('namespace_set_index', '0'))
        if not nsi:
            continue
        require((mn.get('kind'), b.simple(ni)) in (('27', ''), ('9', 'c1')), 'Unreviewed namespace-set operand')
        oi = 8883 if mn.get('kind') == '27' else 8959
        om = a.cp['constant_multiname'][oi]
        require(mn.get('kind') == om.get('kind') and b.simple(ni) == a.simple(oi), 'Multiname shape changed')
        oldset = [int(x.text) for x in a.cp['constant_namespace_set'][int(om.get('namespace_set_index'))].find('namespaces')]
        newset = [int(x.text) for x in b.cp['constant_namespace_set'][nsi].find('namespaces')]
        require(len(oldset) == len(newset) == 11 and oldset.count(old_ns) == newset.count(new_ns) == 1,
                'Lexical namespace-set layout changed')
        for ons, nns in zip(oldset, newset):
            if ons == old_ns:
                require(nns == new_ns, 'Class-private namespace position changed')
            elif a.cp['constant_namespace'][ons].get('kind') == '5':
                # Exact file-private lexical source, never a URI-only mapping of arbitrary private names.
                require(ons == 844 and b.cp['constant_namespace'][nns].get('kind') == '5', 'Unexpected file-private slot')
                require(a.string(int(a.cp['constant_namespace'][ons].get('name_index'))) == 'Grafon.as$34', 'Wrong old file')
                require(b.string(int(b.cp['constant_namespace'][nns].get('name_index'))) == 'Grafon.as$34', 'Different donor lexical file')
                require(nns == ons or nns >= len(a.cp['constant_namespace']), 'Existing unrelated private namespace rebound')
            else:
                require(ons == nns, 'Non-private namespace changed')
        result[ni] = oi
        proof.append(dict(kind='exact-lexical-set', name=b.simple(ni), donor=ni, retained=oi,
                          donorNamespaces=newset, retainedNamespaces=oldset))
    return result, proof

def u30(value):
    require(0 <= value < 1 << 30, 'Invalid U30')
    data = bytearray()
    while value >= 128:
        data.append((value & 127) | 128); value >>= 7
    data.append(value)
    return bytes(data)

def remap_body(body, mapping):
    result = copy.deepcopy(body)
    code = bytearray.fromhex(body.get('codeBytes'))
    rows, _ = core.decode(code)
    for start, end, op, operands in rows:
        require(op not in (0x40, 0x43, 0x44, 0x58, 0x67, 0x6e, 0x6f) and
                not any(k in ('m', 'c') for k, _ in operands), 'Unsupported method/class/scope operand')
        if operands and operands[0][0] == 'n':
            ni = operands[0][1]
            if ni in mapping:
                old, new = u30(ni), u30(mapping[ni])
                require(len(old) == len(new) and code[start+1:start+1+len(old)] == old,
                        'Private relocation changes instruction length')
                code[start+1:start+1+len(old)] = new
    result.set('codeBytes', code.hex())
    return result

def executable(abc, body):
    rows, labels = core.decode(bytes.fromhex(body.get('codeBytes')))
    rows = [r for r in rows if r[2] not in core.DEBUG]
    require(not any(r[2] in (0x40, 0x43, 0x44, 0x58, 0x67, 0x6e, 0x6f) for r in rows), 'Unsupported instruction')
    return rows, labels

def guard_and_tail(abc, body, allowed):
    rows, labels = executable(abc, body)
    constructs = [i for i, r in enumerate(rows) if r[2] == 0x42]
    require(len(constructs) == 1 and rows[constructs[0]][3] == [('u', 0)], 'Factory construction changed')
    split = constructs[0] - 1
    require(rows[split][2] == 0xd1, 'Factory input changed')
    prefix = rows[:split]
    names = [abc.qualified(r[3][0][1]) for r in prefix if r[2] == 0x60]
    require(names == list(allowed), 'Whitelist class order differs')
    # Sprite classes other than TileMask are declared in the second ABC.
    # retain/audit check the real union of both declaration tables separately.
    permitted = {0xd0, 0x30, 0xd1, 0x60, 0xac, 0x96, 0x2a, 0x12, 0x29, 0x5d, 0x2c, 0x4a, 0x03}
    require(all(r[2] in permitted for r in prefix), 'Whitelist has other behavior')
    outcomes = {}
    for candidate in (*allowed, '<unreviewed-class>'):
        stack, pc, outcome = [], 0, None
        for step in range(1000):
            if pc == split:
                require(not stack, 'Guard leaves stack values'); outcome = 'accept'; break
            require(0 <= pc < split, 'Guard branch escaped')
            _, _, op, operands = rows[pc]; pc += 1
            if op == 0xd0: stack.append('<this>')
            elif op == 0x30: require(stack.pop() == '<this>', 'Scope changed')
            elif op == 0xd1: stack.append(candidate)
            elif op == 0x60: stack.append(abc.qualified(operands[0][1]))
            elif op == 0xac: right = stack.pop(); stack.append(stack.pop() == right)
            elif op == 0x96: stack.append(not stack.pop())
            elif op == 0x2a: stack.append(stack[-1])
            elif op == 0x12:
                if not stack.pop(): pc = labels[operands[0][1]]
            elif op == 0x29: stack.pop()
            elif op == 0x5d:
                require(abc.qualified(operands[0][1]) == 'Error', 'Unexpected guard target'); stack.append('<ErrorClass>')
            elif op == 0x2c:
                require(abc.string(operands[0][1]) == 'Unreviewed ordinary material mask class', 'Guard message changed')
                stack.append('<message>')
            elif op == 0x4a:
                require(abc.qualified(operands[0][1]) == 'Error' and operands[1] == ('u', 1), 'Guard constructor changed')
                require(stack.pop() == '<message>' and stack.pop() == '<ErrorClass>', 'Guard stack changed')
                stack.append('<error>')
            elif op == 0x03:
                require(stack.pop() == '<error>' and not stack, 'Guard throw changed'); outcome = 'reject'; break
        require(outcome == ('reject' if candidate == '<unreviewed-class>' else 'accept'), 'Whitelist behavior differs')
        outcomes[candidate] = outcome
    tail = []
    for row in rows[split:]:
        operands = []
        for kind, value in row[3]:
            if kind == 'n': value = abc.multiname(value)
            elif kind in core.POOLS: value = abc.value(core.POOLS[kind], value)
            elif kind == 'target':
                value = labels[value] - split
                require(0 <= value <= len(rows)-split, 'Geometry branch exits tail')
            elif kind in ('m', 'c'): raise AssertionError('Unmapped index')
            operands.append((kind, value))
        tail.append((row[2], operands))
    return tail, outcomes

def proof(a, b, body, private_proof):
    oi, ni = a.named[TARGET], b.named[TARGET]
    old = a.bodies[oi]
    require(oi == 3219 and support.body_digest(old) == BASE_BODY_SHA, 'Wrong original target')
    require(a.methods[oi].get('flags') == b.methods[ni].get('flags') == '0', 'Method flags changed')
    frame = ('init_scope_depth', 'max_scope_depth', 'max_regs', 'max_stack')
    require(all(old.get(k) == body.get(k) for k in frame), 'Frame changed')
    require(canonical(old.find('traits')) == canonical(body.find('traits')) and
            canonical(old.find('exceptions')) == canonical(body.find('exceptions')), 'Activation/catch changed')
    oldtail, _ = guard_and_tail(a, old, ORIGINAL)
    newtail, outcomes = guard_and_tail(b, body, ORIGINAL + ADDED)
    require(oldtail == newtail, 'Geometry/frame selection tail changed')
    return dict(flags='0', frame={k: body.get(k) for k in frame}, privateMappings=private_proof,
                oldAndAddedMasks=dict(original=list(ORIGINAL), added=list(ADDED)),
                geometryTailUnchanged=True, guardOutcomes=outcomes, byteOffsetsUnchangedByRemapping=True,
                completeBodySHA256=support.body_digest(body), codeSHA256=hashlib.sha256(bytes.fromhex(body.get('codeBytes'))).hexdigest())

def retain(base_xml, donor_xml, out_xml):
    require(sha(base_xml) == BASE_XML_SHA, 'Wrong host05 XML')
    out_xml = support.output_path(out_xml, '.xml', (base_xml, donor_xml))
    base, donor = ET.parse(base_xml), ET.parse(donor_xml)
    aa, bb = base.findall('.//abc'), donor.findall('.//abc')
    require(len(aa) == len(bb) == 2, 'ABC count changed')
    a, b = core.ABC(aa[0]), core.ABC(bb[0])
    declarations = set(b.class_by_name) | set(core.ABC(bb[1]).class_by_name)
    require(set(ORIGINAL + ADDED) <= declarations, 'Whitelist classes absent from real ABC declarations')
    additions = support.prefix(a, b)
    require(canonical(aa[1]) == canonical(bb[1]), 'Donor changed other ABC')
    oi, ni = a.named[TARGET], b.named[TARGET]
    info = copy.deepcopy(b.methods[ni]); info.set('name_index', a.methods[oi].get('name_index'))
    require(canonical(info) == canonical(a.methods[oi]), 'Target signature changed')
    mapping, private_proof = mappings(a, b, b.bodies[ni])
    body = remap_body(b.bodies[ni], mapping)
    target_proof = proof(a, b, body, private_proof)
    body.set('method_info', str(oi))
    bodies = aa[0].find('bodies'); at = list(bodies).index(a.bodies[oi])
    bodies.remove(a.bodies[oi]); bodies.insert(at, body)
    constants = aa[0].find('constants'); at = list(aa[0]).index(constants)
    aa[0].remove(constants); aa[0].insert(at, copy.deepcopy(bb[0].find('constants')))
    with out_xml.open('xb') as stream: base.write(stream, encoding='utf-8', xml_declaration=True)
    return dict(passed=True, target=TARGET, targetProof=target_proof, appendedConstants=additions,
                baseXMLSHA256=BASE_XML_SHA, donorXMLSHA256=sha(donor_xml), retainedXMLSHA256=sha(out_xml),
                dependencies=dependencies(), runtimeValidated=False)

def audit(base_xml, final_xml, retained_xml):
    require(sha(base_xml) == BASE_XML_SHA, 'Wrong audit base')
    before, final = ET.parse(base_xml), ET.parse(final_xml)
    aa, bb = before.findall('.//abc'), final.findall('.//abc')
    require(len(aa) == len(bb) == 2, 'ABC count changed')
    declarations = {name for node in bb for name in core.ABC(node).class_by_name}
    require(set(ORIGINAL + ADDED) <= declarations, 'Final whitelist classes absent')
    final_digests, count, target_proof = [], 0, None
    for number, (old, new) in enumerate(zip(aa, bb)):
        a, b = core.ABC(old), core.ABC(new)
        require(old.attrib == new.attrib and a.named == b.named and a.class_by_name == b.class_by_name, 'Identity tables changed')
        support.prefix(a, b)
        require(canonical(old.find('method_info')) == canonical(new.find('method_info')), 'Method metadata changed')
        require(set(a.bodies) == set(b.bodies), 'Body table changed')
        for index, body in a.bodies.items():
            if number == 0 and index == a.named[TARGET]:
                mapping, private_proof = mappings(a, b, b.bodies[index])
                require(all(k == v for k, v in mapping.items()), 'Final private operands not original identities')
                target_proof = proof(a, b, b.bodies[index], private_proof)
            else:
                require(canonical(body) == canonical(b.bodies[index]), 'Unchanged body differs: ' + str(index)); count += 1
        for table in ('instance_info', 'class_info', 'script_info'):
            require(canonical(old.find(table)) == canonical(new.find(table)), 'Class/traits/scripts changed')
        covered = {'constants', 'method_info', 'bodies', 'instance_info', 'class_info', 'script_info'}
        require([canonical(n) for n in old if n.tag not in covered] == [canonical(n) for n in new if n.tag not in covered], 'Other ABC metadata changed')
        if number: require(canonical(old) == canonical(new), 'Other ABC changed')
        final_digests.append(digest(new))
    del a, b, old, new, aa, bb, before, final
    gc.collect()
    expected = ET.parse(retained_xml).findall('.//abc')
    require(final_digests == [digest(n) for n in expected], 'Serializer changed retained ABC')
    require(target_proof is not None, 'Target missing')
    return dict(passed=True, target=TARGET, targetProof=target_proof, exactRetainedRoundTrip=True,
                nonTargetBodiesByteExact=True, classTraitsScriptsPreserved=True, oldConstantPrefixPreserved=True,
                unchangedBodies=count, baseXMLSHA256=BASE_XML_SHA, finalXMLSHA256=sha(final_xml),
                retainedXMLSHA256=sha(retained_xml), runtimeValidated=False, dependencies=dependencies())

def splice(base_swf, serialized_swf, out_swf):
    require(sha(base_swf) == BASE_SWF_SHA, 'Wrong raw host05')
    out_swf = support.output_path(out_swf, '.swf', (base_swf, serialized_swf))
    sig, header, old = support.raw_swf(base_swf)
    dsig, dheader, donor = support.raw_swf(serialized_swf)
    require(sig[3:] == dsig[3:] and header == dheader, 'Version/frame header changed')
    require(len(old) == len(donor) and [x[0] for x in old] == [x[0] for x in donor], 'Tag layout changed')
    abcs = [i for i, t in enumerate(old) if t[0] in (72, 82)]
    require(len(abcs) == 2 and abcs[0] == 332, 'Unexpected ABC arrangement')
    for i in abcs: require(support.abc_prefix(old[i]) == support.abc_prefix(donor[i]), 'ABC flags/name changed')
    target = abcs[0]
    require(old[target][1] != donor[target][1], 'Target ABC unchanged')
    body = header + b''.join(donor[i][2] if i == target else t[2] for i, t in enumerate(old))
    with out_swf.open('xb') as stream:
        stream.write(sig + (len(body)+8).to_bytes(4, 'little') + (zlib.compress(body, 9) if sig[:3] == b'CWS' else body))
    fsig, fheader, result = support.raw_swf(out_swf)
    require(fsig == sig and fheader == header and len(result) == len(old), 'Spliced header changed')
    require(all(result[i][2] == (donor[i][2] if i == target else old[i][2]) for i in range(len(old))), 'Raw resource changed')
    return dict(passed=True, baseSWFSHA256=BASE_SWF_SHA, candidateSHA256=sha(out_swf),
                rawResourcesPreserved=True, preservedRawTags=len(old)-1, preservedOtherABC=1,
                finalXMLAuditRequired=True, runtimeValidated=False)
