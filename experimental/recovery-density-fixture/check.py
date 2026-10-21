"""Pure Python/source checks only. Does not freeze, compile, or run a game."""
import ast
import json
from pathlib import Path
import re
import zlib
from prepare import HERE, BASE, M52, check_source, read, sha
from audit import adler_utf16, canonical, differences


def main():
    check_source()
    for source in HERE.glob('*.py'):
        ast.parse(source.read_text(encoding='utf-8'))
    # Delimiter sanity catches editing mistakes but is explicitly not an AS
    # compiler. Strip strings/comments before comparing the delimiter stack.
    for source in (HERE / 'tests').glob('*.as'):
        text = source.read_text(encoding='utf-8')
        text = re.sub(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', text, flags=re.S)
        stack = []
        for char in text:
            if char in '({[':
                stack.append(char)
            elif char in ')}]':
                assert stack and stack.pop() == {')': '(', '}': '{', ']': '['}[char], source
        assert not stack, source
    meta = read(BASE / 'prepared.json')
    assert sha(M52 / 'coop-bundle-drivers-04/ProductionDeclarations.swc') == meta['external_declarations_sha256']
    assert sha(M52 / 'motion-fast-01/build/GameCombatStubs.swc') == meta['stubs_sha256']
    value = {'a': 1.0, 'b': [False, None, 'ascii']}
    assert adler_utf16(value) == format(zlib.adler32(canonical(value).encode('ascii')), 'x')
    assert differences({'objects': [1, 2]}, {'objects': [1, 3]})
    assert not differences({'objects': [1, 2]}, {'objects': [1, 2]})
    # Existing historical runs have no fixed preparation marker and must not
    # be quietly admitted as controls for this different external fixture.
    for name in ['recovery-density-control-01', 'recovery11-density-01']:
        result = read(M52 / name / 'result.json')
        for role in ['host', 'join']:
            log = M52.parent / 'cooperation' / result['run'] / (role + '.log')
            assert 'DENSITY FIXTURE ' not in log.read_text(encoding='utf-8-sig')
    print(json.dumps(dict(static_checks=True, original_assertions_unchanged=True,
        original_frame_method_unchanged=True, original_render_detector_unchanged=True,
        original_seven_8000ms_windows_unchanged=True, same_external_declarations_and_stub=True,
        internal_variant_safe_probe=True, message_failure_notifies_peer_and_finishes=True,
        actual_remote_ids_including_host_zero=True, remote_identity_deduplicated=True,
        exactly_one_remote_required=True, preparation_timeout_45000ms_unchanged=True,
        as_compiled=False, air_started=False, fixture_runtime_verified=False,
        files={p.relative_to(HERE).as_posix(): sha(p) for p in sorted(HERE.rglob('*'))
               if p.is_file() and p.suffix in ('.as', '.py')}), indent=2))


if __name__ == '__main__':
    main()
