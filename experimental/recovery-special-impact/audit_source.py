"""Static bookkeeping only; explicitly not an AS3 compiler or gameplay test."""
from pathlib import Path
import ast
import hashlib
import json
import re

HERE=Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def delimiters(path):
    # Sanity check useful before a registered compiler run, not AS3 validation.
    text=path.read_text(encoding='utf-8-sig')
    text=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', text)
    stack=[]
    for c in text:
        if c in '([{':stack.append(c)
        elif c in ')]}':
            assert stack and stack.pop() == {')':'(',']':'[','}':'{'}[c], path
    assert not stack, path


def main():
    for script in HERE.glob('*.py'):ast.parse(script.read_text(encoding='utf-8'),filename=str(script))
    for source in HERE.rglob('*.as'):delimiters(source)
    manifest=json.loads((HERE/'inputs.json').read_text(encoding='utf-8'))
    for name,item in manifest['files'].items():
        assert sha(Path(item['base'])) == item['base_sha256']
        assert sha(HERE/'src'/name) == item['overlay_sha256']
    a=HERE/'components/control';b=HERE/'components/proposal'
    differences=[]
    for path in a.rglob('*.as'):
        relative=path.relative_to(a).as_posix()
        if sha(path)!=sha(b/relative):differences.append(relative)
    assert sorted(differences) == sorted(manifest['files'])
    for fixture in (HERE/'tests').rglob('*.as'):
        relative=fixture.relative_to(HERE/'tests')
        assert sha(fixture)==sha(a/relative)==sha(b/relative), relative
    native=(HERE/'native/MSWNoVisualExplosionTestDoc.as').read_text(encoding='utf-8')
    # No direct native execution, production receive, or settings save calls.
    assert not re.search(r'\.(?:shoot|explosion|explRun|step|save)\s*\(',native)
    for package in [a,b]:
        inputs=json.loads((package/'inputs.json').read_text(encoding='utf-8'))
        for relative,origin in inputs['production'].items():
            assert sha(package/relative)==origin['sha256']
    receipt=dict(python_syntax=True,delimiter_sanity=True,base_and_overlay_hashes_match=True,
        changed_component_production_files=sorted(differences),shared_fixtures_identical=True,
        native_driver_sha256=sha(HERE/'native/MSWNoVisualExplosionTestDoc.as'),
        component_fixture_sha256=sha(HERE/'tests/SpecialImpactChecks.as'),
        compiled=False,air_started=False,native_game_tested=False,performance_qualified=False)
    (HERE/'static-review.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(receipt,ensure_ascii=False))


if __name__=='__main__':
    main()
