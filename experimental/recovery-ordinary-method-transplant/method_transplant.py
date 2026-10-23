"""Exact, offline Location hitTile/dieTile transplant onto host04.

No JVM/AIR/deployment. This is deliberately not a general ABC rewriter.
Only the reviewed donor body bytes and one NEED_ACTIVATION flag may change.
The caller binds XML exports to SWFs and separately checks native semantics.
"""
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
    raise RuntimeError('Optimized Python is forbidden for this validation tool')
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SUPPORT = ROOT.parent / 'ContinuousScene/build/native-crop-audit.py'
SUPPORT_SHA = 'ac4383a6fa899ee62caa54282ae6f31e5ddb83cebabfc65a920ea5954f0f46de'
BASE_XML_SHA = '51a6730dd22edddbf83fb87d69b071e0e4931ff85c892b0ad704b7de47f61011'
BASE_SWF_SHA = '9b3622541784fdab1104a2fd01b9858e94297388b5df102d50f62e8dba2f913f'
DONOR_XML_SHA = '01b1d3341c4066ab6f52f6b288dc374b428a026f8bedde0eee4beb6947597a59'
DONOR_CONSTANTS = 'a0d97af16896a48409a88b50bf118c149c77401aa38d500f4354ee40ce9d2cbb'
CLASS = 'fe.loc.Location'
TARGETS = tuple(CLASS + '::0:1:' + name for name in ('hitTile', 'dieTile'))
ANNOTATIONS = {'bytes', 'fileOffset'}
BODY_PINS = {
    TARGETS[0]: dict(index=234, flags='10', originalFlags='8',
        original='d7c2494765563f729d9b2bcbf407d7ad62c729df8ab48156e18fc1cf36589a4e',
        final='be9d52af6b714d9e70c01527538fa4ec47c2707f8ca68c4efc79a60b2fcc1a4e',
        code='53ded9fdf6aa60f48f282b3065cdb00defd522048939fb8ca538962822e944f5',
        frame=('5', '10', '8', '8'), activation=6),
    TARGETS[1]: dict(index=235, flags='0', originalFlags='0',
        original='75e4731d4626dbd1961d81de8c3fbfd77cb2ae1f2ae052dae4581f9e3c4131b6',
        final='52bef36e343355100f05956399c83b11d8c11de72d2bb48d53423fefba73f588',
        code='84fcf21b57217692c24ca7f0cfbabfb0cf3b50123ba45970738068ace7713054',
        frame=('4', '5', '3', '4'), activation=0),
}


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


require(sha(SUPPORT) == SUPPORT_SHA, 'Read-only CS decoder changed')
spec = importlib.util.spec_from_file_location('ordinary_method_decoder', SUPPORT)
core = importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)


def dependencies():
    """The sole non-stdlib import is the pinned, read-only CS decoder."""
    require(sha(SUPPORT) == SUPPORT_SHA, 'Read-only CS decoder changed')
    return {str(Path(__file__).resolve()): sha(__file__), str(SUPPORT): SUPPORT_SHA}


def canonical(node, ignored=ANNOTATIONS):
    return core.xml_value(node, ignored)


def digest(node, ignored=ANNOTATIONS):
    return hashlib.sha256(json.dumps(canonical(node, ignored), ensure_ascii=True,
                                   separators=(',', ':')).encode('utf-8')).hexdigest()


def body_digest(node):
    return digest(node, ANNOTATIONS | {'method_info'})


def output_path(path, suffix, inputs):
    path = Path(path).resolve()
    require(path.suffix.lower() == suffix and path.is_relative_to((ROOT / 'build/m52').resolve()),
            'Output must be a new isolated build/m52 file')
    require(path not in {Path(p).resolve() for p in inputs} and not path.exists(),
            'Never overwrite either input or a previous result')
    require(path.parent.is_dir(), 'Caller must prepare the isolated output directory')
    return path


def prefix(a, b):
    require(set(a.cp) == set(b.cp), 'Constant pool kinds changed')
    counts = {}
    for pool, old in a.cp.items():
        new = b.cp[pool]
        require(len(new) >= len(old), 'Constant pool shortened: ' + pool)
        for i, value in enumerate(old):
            require(canonical(value, set()) == canonical(new[i], set()),
                    'Constant prefix changed: ' + pool + '/' + str(i))
        counts[pool] = len(new) - len(old)
    return counts


def target_proof(abc, name):
    """Exact body/frame/activation/catch plus actual operand binding checks."""
    pin = BODY_PINS[name]
    index = abc.named[name]
    body = abc.bodies[index]
    require(body_digest(body) == pin['final'], name + ': not the reviewed complete donor body')
    require(abc.methods[index].get('flags') == pin['flags'], name + ': method flags changed')
    require(tuple(body.get(k) for k in ('init_scope_depth', 'max_scope_depth', 'max_regs', 'max_stack'))
            == pin['frame'], name + ': execution frame changed')
    code = bytes.fromhex(body.get('codeBytes'))
    require(hashlib.sha256(code).hexdigest() == pin['code'], name + ': instruction bytes changed')
    rows, labels = core.decode(code)
    forbidden = {0x40, 0x43, 0x44, 0x58, 0x67, 0x6e, 0x6f}
    require(not any(r[2] in forbidden or any(k in ('m', 'c') for k, _ in r[3]) for r in rows),
            name + ': unsupported method/class/outer-scope/global-slot operand')
    names = set()
    for row in rows:
        for kind, value in row[3]:
            if kind in core.POOLS:
                abc.value(core.POOLS[kind], value)
            elif kind == 'n':
                names.add(value)
    traits = list(body.find('traits/traits'))
    require(len(traits) == pin['activation'], name + ': activation layout changed')
    for trait in traits:
        names.update(int(trait.get(k)) for k in ('name_index', 'type_index') if int(trait.get(k)))
    for exc in body.find('exceptions'):
        start, end, target = (int(exc.get(k)) for k in ('start', 'end', 'target'))
        require(start in labels and end in labels and target in labels and start < end <= len(code)
                and target < len(code), name + ': invalid exception boundaries')
        names.update(int(exc.get(k)) for k in ('name_index', 'type_index') if int(exc.get(k)))
    # Actual target bodies have no private or namespace-set references. Refuse
    # new shapes rather than guessing which blank private URI is equivalent.
    for value in names:
        require(0 < value < len(abc.cp['constant_multiname']), 'Invalid target multiname')
        mn = abc.cp['constant_multiname'][value]
        ns = int(mn.get('namespace_index', '0'))
        require(mn.get('kind') == '7' and mn.get('namespace_set_index') == '0'
                and ns in (1, 6, 16, 43, 421), name + ': unreviewed lexical/private identity')
    calls = []
    for row in rows:
        if row[2] not in (0x46, 0x4f):
            continue
        ni, argc = row[3][0][1], row[3][1][1]
        simple = abc.simple(ni)
        if simple in ('rconnectOrdinaryPrepare', 'rconnectOrdinaryPending', 'tileDie'):
            mn = abc.cp['constant_multiname'][ni]
            require(mn.get('namespace_index') == '1', 'Bridge call is not public')
            key = 'fe.graph.Grafon::' + ('0' if simple == 'tileDie' else '1') + ':1:' + simple
            require(key in abc.named, 'Missing actual Grafon bridge declaration: ' + key)
            mi = abc.named[key]
            arity = 2 if simple == 'rconnectOrdinaryPrepare' else 3
            require(len(list(abc.methods[mi].find('param_types'))) == arity, 'Grafon declaration arity changed')
            require(argc == arity, 'Bridge invocation arity changed')
            calls.append(dict(offset=row[0], name=simple, arguments=argc, declaration=mi))
    require({x['name'] for x in calls} == {'rconnectOrdinaryPrepare', 'rconnectOrdinaryPending', 'tileDie'},
            name + ': missing reviewed bridge calls')
    return dict(method=name, index=index, codeSHA256=pin['code'], completeBodySHA256=pin['final'],
                flags=pin['flags'], frame=pin['frame'], activationSlots=len(traits),
                exceptions=[dict(e.attrib) for e in body.find('exceptions')],
                bridgeCalls=calls, namespaceRemappingRequired=False, byteOffsetsUnchanged=True)


def retain(base_xml, donor_xml, out_xml):
    base_xml, donor_xml = Path(base_xml), Path(donor_xml)
    require(sha(base_xml) == BASE_XML_SHA and sha(donor_xml) == DONOR_XML_SHA, 'Wrong exact XML inputs')
    out_xml = output_path(out_xml, '.xml', (base_xml, donor_xml))
    base, donor = ET.parse(base_xml), ET.parse(donor_xml)
    old, new = base.findall('.//abc'), donor.findall('.//abc')
    require(len(old) == len(new) == 2, 'Expected two top-level ABC exports')
    a, b = core.ABC(old[0]), core.ABC(new[0])
    additions = prefix(a, b)
    require(digest(new[0].find('constants'), set()) == DONOR_CONSTANTS, 'Donor constants changed')
    require(canonical(old[1]) == canonical(new[1]), 'Other ABC changed in donor')
    proofs = []
    for name in TARGETS:
        pin = BODY_PINS[name]
        oi, ni = a.named[name], b.named[name]
        require(oi == pin['index'] and body_digest(a.bodies[oi]) == pin['original'], 'Wrong baseline target')
        require(a.methods[oi].get('flags') == pin['originalFlags'], 'Wrong baseline flags')
        check = copy.deepcopy(b.methods[ni])
        check.set('flags', a.methods[oi].get('flags'))
        check.set('name_index', a.methods[oi].get('name_index'))
        require(canonical(check) == canonical(a.methods[oi]), 'Invocation signature/optional values changed')
        proofs.append(target_proof(b, name))
        bodies = old[0].find('bodies')
        at = list(bodies).index(a.bodies[oi])
        replacement = copy.deepcopy(b.bodies[ni])
        replacement.set('method_info', str(oi))
        bodies.remove(a.bodies[oi]); bodies.insert(at, replacement)
        # Retain baseline debug-name and all signature metadata. Only bit2 is new.
        a.methods[oi].set('flags', pin['flags'])
    constants = old[0].find('constants')
    at = list(old[0]).index(constants)
    old[0].remove(constants); old[0].insert(at, copy.deepcopy(new[0].find('constants')))
    with out_xml.open('xb') as stream:
        base.write(stream, encoding='utf-8', xml_declaration=True)
    return dict(passed=True, retainedXML=str(out_xml), retainedXMLSHA256=sha(out_xml),
                baseXMLSHA256=BASE_XML_SHA, donorXMLSHA256=DONOR_XML_SHA, copiedMethods=proofs,
                appendedConstants=additions, oldTablesPreserved=True, namespaceMappings={},
                bytecodeRelocation=False, runtimeValidated=False, dependencies=dependencies())


def audit(base_xml, final_xml, retained_xml=None):
    """Check all ABC contents, optionally also the exact serializer round trip."""
    require(sha(base_xml) == BASE_XML_SHA, 'Audit base is not host04')
    before, final = ET.parse(base_xml), ET.parse(final_xml)
    aa, bb = before.findall('.//abc'), final.findall('.//abc')
    require(len(aa) == len(bb) == 2, 'ABC count changed')
    proofs, counts, final_digests, additions = [], dict(methods=0, bodies=0, classes=0, scripts=0), [], []
    for number, (old, new) in enumerate(zip(aa, bb)):
        a, b = core.ABC(old), core.ABC(new)
        require(old.attrib == new.attrib and a.named == b.named and a.class_by_name == b.class_by_name,
                'ABC/named method/class identity changed')
        additions.append(prefix(a, b))
        if number == 0:
            require(digest(new.find('constants'), set()) == DONOR_CONSTANTS, 'Appended constants/bindings changed')
        else:
            require(canonical(old) == canonical(new), 'Other ABC changed')
        require(len(a.methods) == len(b.methods) and set(a.bodies) == set(b.bodies), 'Method/body table changed')
        for index, (left, right) in enumerate(zip(a.methods, b.methods)):
            expected = copy.deepcopy(left)
            name = a.names_by_method.get(index)
            if number == 0 and name in TARGETS:
                expected.set('flags', BODY_PINS[name]['flags'])
            require(canonical(expected) == canonical(right), 'Unexpected method metadata change: ' + str(index))
            counts['methods'] += 1
        for index, body in a.bodies.items():
            name = a.names_by_method.get(index)
            if number == 0 and name in TARGETS:
                require(index == BODY_PINS[name]['index'], 'Target identity moved')
                proofs.append(target_proof(b, name))
            else:
                # Do not decode/rewrite untouched legacy unreachable instructions.
                require(canonical(body) == canonical(b.bodies[index]), 'Unchanged body/frame/activation/catch differs: ' + str(name or index))
                counts['bodies'] += 1
        for table in ('instance_info', 'class_info', 'script_info'):
            require(canonical(old.find(table)) == canonical(new.find(table)), 'Original ' + table + ' changed')
        covered = {'constants', 'method_info', 'bodies', 'instance_info', 'class_info', 'script_info'}
        require([canonical(n) for n in old if n.tag not in covered] ==
                [canonical(n) for n in new if n.tag not in covered], 'Other ABC metadata changed')
        counts['classes'] += len(a.instances)
        counts['scripts'] += len(list(old.find('script_info')))
        final_digests.append(digest(new))
    require({x['method'] for x in proofs} == set(TARGETS) and len(proofs) == 2, 'Wrong changed methods')
    # Release the two large SWF XML trees before reading the expected export.
    del a, b, old, new, aa, bb, before, final
    gc.collect()
    roundtrip = False
    if retained_xml is not None:
        expected = ET.parse(retained_xml).findall('.//abc')
        require([digest(n) for n in expected] == final_digests, 'Serializer changed retained ABC content')
        roundtrip = True
    return dict(passed=True, baseXMLSHA256=BASE_XML_SHA, finalXMLSHA256=sha(final_xml),
                retainedXMLSHA256=sha(retained_xml) if retained_xml is not None else None,
                exactRetainedRoundTrip=roundtrip, oldConstantPrefixPreserved=True,
                appendedConstants=additions, unchanged=counts, changedMethods=proofs,
                changedMethodMetadata=[dict(index=234, field='flags', before='8', after='10')],
                classTraitsScriptsPreserved=True, nonTargetBodiesByteExact=True,
                runtimeValidated=False, dependencies=dependencies())


def raw_swf(path):
    data = Path(path).read_bytes()
    require(len(data) >= 12 and data[:3] in (b'FWS', b'CWS'), 'Unsupported SWF signature')
    body = zlib.decompress(data[8:]) if data[:3] == b'CWS' else data[8:]
    require(len(body) + 8 == int.from_bytes(data[4:8], 'little'), 'Invalid SWF expanded length')
    cursor = (5 + 4 * (body[0] >> 3) + 7) // 8 + 4
    require(cursor <= len(body), 'Truncated frame header')
    header, tags, ended = body[:cursor], [], False
    while cursor < len(body):
        start = cursor
        require(cursor + 2 <= len(body), 'Truncated tag header')
        rec = int.from_bytes(body[cursor:cursor+2], 'little'); cursor += 2
        kind, size = rec >> 6, rec & 63
        if size == 63:
            require(cursor + 4 <= len(body), 'Truncated long tag header')
            size = int.from_bytes(body[cursor:cursor+4], 'little'); cursor += 4
        require(cursor + size <= len(body), 'Truncated tag payload')
        payload = body[cursor:cursor+size]; cursor += size
        tags.append((kind, payload, body[start:cursor]))
        if kind == 0:
            require(cursor == len(body), 'Bytes after End tag')
            ended = True; break
    require(ended, 'Missing End tag')
    return data[:4], header, tags


def abc_prefix(tag):
    kind, payload, _ = tag
    require(kind in (72, 82), 'Not an ABC tag')
    if kind == 72:
        return b''
    require(len(payload) >= 5 and b'\0' in payload[4:], 'Invalid DoABC flags/name')
    return payload[:payload.index(b'\0', 4)+1]


def splice(base_swf, serialized_swf, out_swf):
    """Copy only ABC0; all raw art, metadata, second ABC and tag headers survive."""
    require(sha(base_swf) == BASE_SWF_SHA, 'Splice base is not exact host04')
    out_swf = output_path(out_swf, '.swf', (base_swf, serialized_swf))
    sig, header, old = raw_swf(base_swf)
    donor_sig, donor_header, donor = raw_swf(serialized_swf)
    require(sig[3:] == donor_sig[3:] and header == donor_header, 'Version/frame header changed')
    require(len(old) == len(donor) and [t[0] for t in old] == [t[0] for t in donor], 'Tag count/order changed')
    abcs = [i for i, t in enumerate(old) if t[0] in (72, 82)]
    require(len(abcs) == 2 and abcs[0] == 332, 'Unexpected ABC arrangement')
    for i in abcs:
        require(abc_prefix(old[i]) == abc_prefix(donor[i]), 'DoABC flags/name changed')
    target = abcs[0]
    require(old[target][1] != donor[target][1], 'No target ABC change')
    body = header + b''.join(donor[i][2] if i == target else tag[2] for i, tag in enumerate(old))
    with out_swf.open('xb') as stream:
        stream.write(sig + (len(body)+8).to_bytes(4, 'little') +
                     (zlib.compress(body, 9) if sig[:3] == b'CWS' else body))
    fsig, fheader, result = raw_swf(out_swf)
    require(fsig == sig and fheader == header and len(result) == len(old), 'Spliced header mismatch')
    require(all(result[i][2] == (donor[i][2] if i == target else old[i][2]) for i in range(len(old))),
            'Spliced raw tag source mismatch')
    return dict(passed=True, outputSWF=str(out_swf), outputSHA256=sha(out_swf),
                baseSWFSHA256=BASE_SWF_SHA, serializedSWFSHA256=sha(serialized_swf),
                targetABCIndex=0, targetTagIndex=target, preservedRawTags=len(old)-1,
                preservedOtherABC=1, rawResourcesPreserved=True, finalXMLAuditRequired=True,
                runtimeValidated=False, dependencies=dependencies())
