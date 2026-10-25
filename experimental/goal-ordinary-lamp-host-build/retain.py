"""Narrow parameterization of the reviewed three-class ABC retainer.

Only Grafon.drawLoc and two new private methods are taken from the donor.
No decoder, constant-pool mapper, slot analysis or raw SWF splicer is replaced.
"""
from pathlib import Path
from types import SimpleNamespace, ModuleType
import difflib, hashlib, importlib.util, sys

if sys.flags.optimize:
    raise RuntimeError('Ordinary Python required')
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = HERE.with_name('recovery-room-first-raster-host-current')
UI = HERE.with_name('goal-native-loading-host-build-v2')
BASE = ROOT / 'build/m52/goal-native-loading-host-03'
BASE_XML = BASE / 'final.xml'
HOST_SHA = '2db0b4eb542661c45e5fa0056e7de44e730fee3cf1eac642f6f147f3ce1c2b82'
XML_SHA = 'c20f35696ffc284f3c293ec76d4e21f083857303a7cd2fc17916da3868c75fe5'
SOURCE_SHA = '1811657e117327c018536667fbca59a13be9e54448578361adc44ac4e795be55'
SLOT_SHA = 'c8fc48cc206f70f238ac770cd098594debbf9964b160bf84bb32a10224cc280f'
FFDEC_LIB = ROOT.parent/'Sandevistan/build/tools/ffdec/lib/ffdec_lib.jar'
FFDEC_LIB_SHA = '2a9dfd3d47cec97b1ac13ae2e0aac1f118a901c7e696cb3ad650548af864b4f2'
TARGETS = ('fe.graph.Grafon::0:1:drawLoc',)
NEW = tuple(('fe.graph.Grafon', '0', '1', name) for name in
            ('beginOrdinaryLampRaster', 'completeOrdinaryLampRaster'))
NEW_NAMES = tuple(c+'::'+s+':'+k+':'+n for c,s,k,n in NEW)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Counts only become the exact configured target/member counts. The original
# unknown-opcode, local-slot, prefix, namespace, exception and roundtrip guards
# remain present. No class/static field or initializer is added in this port.
EDITS = (
    ("static_fields={c:[] for c in ('fe.loc.Game','fe.graph.Grafon')}",
     "static_fields={}\n"
     " original_private={(cls,scope):{namespace(a,int(x.get('name_index'))) for x in traits(a,cls,scope) if a.cp['constant_namespace'][namespace(a,int(x.get('name_index')))].get('kind')=='5'} for cls,scope in {(c,s) for c,s,k,n in NEW}}"),
    ("len(b.methods)==len(a.methods)+5", "len(b.methods)==len(a.methods)+len(NEW_NAMES)"),
    ("added_methods=5,added_fields=4", "added_methods=len(NEW_NAMES),added_fields=len(FIELDS)"),
    ("  t=copy.deepcopy(table(n,cls,scope)[('TraitMethodGetterSetter',kind,name)])",
     "  t=copy.deepcopy(table(n,cls,scope)[('TraitMethodGetterSetter',kind,name)])\n"
     "  ni=namespace(n,int(t.get('name_index')))\n"
     "  old_private=original_private[(cls,scope)]\n"
     "  require(ni in old_private and n.cp['constant_namespace'][ni].get('kind')=='5','New helper must bind the original Grafon private namespace')"),
)


def expansion():
    assert sha(OLD/'retain_v2.py') == SOURCE_SHA
    before = (OLD/'retain_v2.py').read_text('utf-8')
    after = before
    for old, new in EDITS:
        assert after.count(old) == 1, old
        after = after.replace(old, new, 1)
    return before, after


before, after = expansion()
legacy = ModuleType('ordinary_lamp_private_retainer')
legacy.__file__ = str(OLD/'retain_v2.py')
exec(compile(after, legacy.__file__, 'exec'), legacy.__dict__)
assert sha(UI/'activation_slots.py') == SLOT_SHA
assert sha(FFDEC_LIB) == FFDEC_LIB_SHA
slot_before = (UI/'activation_slots.py').read_text('utf-8')
SLOT_EDIT = ('0xaf,0xb0,0xb3):replace(2)', '0xaf,0xb0,0xb3,0xb4):replace(2)')
assert slot_before.count(SLOT_EDIT[0]) == 1
slot_after = slot_before.replace(*SLOT_EDIT, 1)
SWITCH_EDITS = (
    ('  branch=None;terminal=False', '  branch=None;terminal=False;switch_targets=None'),
    ('  elif 0x0c<=op<=0x1a:',
     "  elif op==0x1b:\n"
     "   assert len(args)>=2 and all(k=='target' for k,v in args),'Malformed decoded switch targets'\n"
     "   pop();switch_targets=[v for k,v in args];terminal=True\n"
     '  elif 0x0c<=op<=0x1a:'),
    ('  if branch is not None:offer(branch,state)',
     '  if branch is not None:offer(branch,state)\n'
     '  if switch_targets is not None:\n'
     '   for destination in switch_targets:offer(destination,state)'),
)
for old, new in SWITCH_EDITS:
    assert slot_after.count(old) == 1, old
    slot_after = slot_after.replace(old, new, 1)
# Exact local FFDec InIns.class: opcode b4; getStackPopCount bytecode 05 ac
# (iconst_2, ireturn), getStackPushCount 04 ac (iconst_1, ireturn).
# Result is a Boolean, so it cannot carry activation/catch receiver provenance.
slotproof = ModuleType('ordinary_lamp_b4_slot_proof')
slotproof.__file__ = str(UI/'activation_slots.py')
exec(compile(slot_after, slotproof.__file__, 'exec'), slotproof.__dict__)
legacy.slotproof = slotproof
legacy.prep = SimpleNamespace(CLASSES=('fe.graph.Grafon',), HOST_SHA=HOST_SHA,
                            BASE_XML=BASE_XML, PINS={BASE_XML: XML_SHA})
legacy.TARGETS, legacy.NEW, legacy.NEW_NAMES = TARGETS, NEW, NEW_NAMES
legacy.FIELDS, legacy.CINITS = (), ()
# The former Game-only special case can never match this exact target set.
assert legacy.GAME_TAIL not in TARGETS
support = legacy.support
core = legacy.core
_audit = legacy.audit


def audit(base_xml, final_xml, retained_xml):
    result = _audit(base_xml, final_xml, retained_xml)
    assert result['allowed_changed_bodies'] == list(TARGETS)
    assert result['added_methods'] == 2 and result['added_fields'] == 0
    # These are consequences of the original exhaustive non-target body audit,
    # not alternatives to it: World is entirely outside TARGETS, as are cinits.
    result.update(world_ui_bodies_byte_exact=True,
                  original_static_initializers_byte_exact=True,
                  private_helper_traits_bound=True)
    return result


legacy.audit = audit
retain = legacy.retain
splice = legacy.splice


def switch_checks():
    """Small bytecode fixtures use the real decoder and unchanged provenance guards."""
    def fixture(case0=b'\x47', case1=b'\x47', default=b'\x47'):
        # The instruction immediately after switch is an unreachable pop: a
        # mistaken implicit fallthrough would underflow after consuming selector.
        positions = (14, 14+len(case0), 14+len(case0)+len(case1))
        offset = lambda p: (p-2).to_bytes(3, 'little', signed=True)
        return b'\x24\x00\x1b'+offset(positions[2])+b'\x01'+offset(positions[0])+offset(positions[1])+b'\x29'+case0+case1+default

    def prove(code):
        body = legacy.ET.fromstring('<item codeBytes="'+code.hex()+'" init_scope_depth="4" max_scope_depth="4" max_regs="1" max_stack="3"><exceptions/><traits><traits/></traits></item>')
        abc = SimpleNamespace(bodies={0: body}, methods=[legacy.ET.fromstring('<item flags="0"/>')], cp={})
        return slotproof.prove(abc, 0, core)

    result = prove(fixture())
    assert result['passed'] and result['visited_instructions'] == 5
    checks = 1

    def rejected(code, reason):
        try:
            prove(code)
        except AssertionError as error:
            assert reason in str(error), str(error)
        else:
            raise AssertionError('Invalid switch fixture was accepted: '+reason)

    unknown_slot = b'\xd0\x6c\x01\x29\x47'
    for name in ('case0','case1','default'):
        rejected(fixture(**{name: unknown_slot}), 'Non-local/unknown slot receiver')
        checks += 1
    # Both cases join pc24: case0 carries one value while case1 carries none.
    rejected(fixture(b'\x20\x10\x05\x00\x00', b'\x10\x01\x00\x00', b'\x47\x47'), 'Frame merge mismatch')
    checks += 1
    bad = bytearray(fixture());bad[3:6] = (1-2).to_bytes(3, 'little', signed=True)
    rejected(bytes(bad), 'Branch into instruction operand')
    checks += 1
    rejected(fixture()[2:], 'Operand underflow')
    checks += 1
    rejected(b'\x1c\x47', 'Unsupported provenance opcode')
    checks += 1
    assert prove(b'\x20\x20\xb4\x48')['passed']
    checks += 1
    return dict(passed=True, checks=checks, real_decoder=True, no_implicit_fallthrough=True,
                all_cases_and_default_checked=True, unknown_slots_and_merges_rejected=True)


def diff():
    main = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                   fromfile='frozen/retain_v2.py', tofile='private/ordinary-lamp-retain.py'))
    return main + ''.join(difflib.unified_diff(slot_before.splitlines(True), slot_after.splitlines(True),
                          fromfile='frozen/activation_slots.py', tofile='private/ordinary-lamp-slots.py'))
