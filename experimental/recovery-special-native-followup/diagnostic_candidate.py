"""Freeze/build one diagnostic queue delta; no process unless --build is explicit."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

import prepare

HERE = Path(__file__).resolve().parent
ROOT = prepare.ROOT
QUEUE = 'rconnect/game/ImpactEventQueue.as'


def verify_base(source):
    assert source.name == 'src' and source.parent.parent == ROOT / 'build/m52'
    meta = prepare.read(source.parent / 'prepared.json')
    assert meta.get('kind') in ('isolated-recovery', 'recovery-special-diagnostic-candidate'), 'Unexpected candidate manifest'
    assert meta.get('compiled') is True, 'Use a compiled frozen candidate'
    assert prepare.inventory(source) == meta['source'], 'Frozen candidate sources changed'
    assert prepare.sha(source.parent / 'RConnectMod.swf') == meta['candidate_sha256']
    assert (source.parent / 'build/GameCombatStubs.swc').is_file()
    return meta


def verify(out, meta):
    assert prepare.inventory(out / 'src') == meta['source']
    prepare.verify_files(out, meta['inputs'])
    for name, digest in meta['originals'].items():
        assert Path(name).is_file() and prepare.sha(name) == digest, 'Changed input: ' + name
    if meta.get('compiled'):
        assert prepare.sha(out / 'RConnectMod.swf') == meta['candidate_sha256']


def main(args):
    source, out = (ROOT / args.source).resolve(), (ROOT / args.output).resolve()
    assert out.parent == ROOT / 'build/m52' and not out.exists(), 'Use a new build/m52 child'
    base = verify_base(source)
    binding = prepare.read(HERE / 'manifest.json')
    overlay = HERE / 'diagnostic-src' / QUEUE
    assert prepare.sha(source / QUEUE) == binding['baseline_queue_sha256'], \
        'Candidate queue changed: review/rebase diagnostics instead of replacing newer behavior'
    assert prepare.sha(overlay) == binding['source_hashes']['diagnostic-src/' + QUEUE]
    from run import installation, EXPECTED_INSTALLATION_FILES
    installed = installation()
    assert len(installed) == EXPECTED_INSTALLATION_FILES == 22
    originals = {str(p): prepare.sha(p) for p in source.rglob('*') if p.is_file()}
    for p in (source.parent / 'prepared.json', source.parent / 'RConnectMod.swf',
              source.parent / 'build/GameCombatStubs.swc', overlay, HERE / 'manifest.json',
              HERE / 'native_tool.py', Path(__file__), Path(prepare.__file__),
              ROOT / 'tools/host_authority/common.py', ROOT.parent / 'ModLoader/tools/test_registry.py',
              prepare.JAVA, prepare.SDK / 'lib/mxmlc.jar',
              prepare.SDK / 'frameworks/air-config.xml', prepare.SDK / 'frameworks/libs/air/airglobal.swc'):
        originals[str(p.resolve())] = prepare.sha(p)
    out.mkdir()
    shutil.copytree(source, out / 'src')
    shutil.copyfile(overlay, out / 'src' / QUEUE)
    (out / 'build').mkdir()
    shutil.copyfile(source.parent / 'build/GameCombatStubs.swc', out / 'build/GameCombatStubs.swc')
    (out / 'inputs').mkdir()
    for p in (Path(__file__), HERE / 'native_tool.py', HERE / 'manifest.json'):
        shutil.copyfile(p, out / 'inputs' / p.name)
    meta = dict(kind='recovery-special-diagnostic-candidate', diagnostic_only=True,
                diagnostic_default='disabled', version=base.get('version'),
                base_candidate_sha256=base['candidate_sha256'], source=prepare.inventory(out / 'src'),
                inputs={**{'build/' + k: v for k, v in prepare.inventory(out / 'build').items()},
                        **{'inputs/' + k: v for k, v in prepare.inventory(out / 'inputs').items()}},
                originals=originals, installation_before=installed, installation_count=22,
                compiled=False, installed=False, gameplay_qualified=False, performance_qualified=False)
    prepare.save(out / 'prepared.json', meta)
    try:
        verify(out, meta)
        if args.build:
            sys.path.insert(0, str(ROOT.parent / 'ModLoader/tools'))
            from test_registry import Registration
            command = [str(prepare.JAVA), '-Xmx384m', '-jar', str(prepare.SDK / 'lib/mxmlc.jar'),
                       '+configname=air', '+flexlib=' + str(prepare.SDK / 'frameworks'),
                       '-swf-version=38', '-debug=false', '-optimize=true', '-warnings=true',
                       '-source-path=' + str(out / 'src'),
                       '-external-library-path+=' + str(out / 'build/GameCombatStubs.swc'),
                       '-output=' + str(out / 'RConnectMod.swf'), str(out / 'src/RConnectDoc.as')]
            prepare.save(out / 'command.json', command)
            with Registration(owner='RConnect / MSW queue diagnostic compile', resource='game',
                              purpose='独立默认关闭的队列观测副本；非生产资格', run_dir=out,
                              evidence=out / 'prepared.json', wait=args.registry_wait) as record:
                verify(out, meta)
                assert installation() == installed, 'Installation changed while waiting'
                with (out / 'compile.log').open('w', encoding='utf-8') as log:
                    record.before_launch('MSW diagnostic candidate compiler')
                    verify(out, meta)
                    process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                        env=dict(os.environ, AIR_HOME=str(prepare.SDK)), creationflags=subprocess.CREATE_NO_WINDOW)
                    record.child(process.pid)
                    try:
                        code = process.wait(timeout=240)
                    finally:
                        if process.poll() is None:
                            process.kill()
                            process.wait()
                        record.child_stopped()
                meta['compile_exit'] = code
                verify(out, meta)
                assert installation() == installed, 'Installation changed during compilation'
                if code:
                    record.outcome = 'failed'
                    raise RuntimeError('Diagnostic compile failed; keep original log and use a new output')
                meta.update(compiled=True, candidate_sha256=prepare.sha(out / 'RConnectMod.swf'),
                            sha256=prepare.sha(out / 'RConnectMod.swf'))
                record.outcome = 'passed'
                record.note = '仅诊断副本编译完成；无 AIR、玩法或性能合格结论'
    except Exception as error:
        meta['prepare_error'] = type(error).__name__ + ': ' + str(error)
        raise
    finally:
        meta['installation_after'] = installation()
        meta['installation_unchanged'] = meta['installation_after'] == installed
        prepare.save(out / 'prepared.json', meta)
        verify(out, meta)
        assert meta['installation_unchanged'], 'Installation changed'
    print(out)
    return 0
