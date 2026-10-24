"""Read-only Python syntax, AS delimiter, and exact runner-difference checks."""
from pathlib import Path
import ast
import json
import re
import run

HERE = Path(__file__).resolve().parent


def main():
    checks = []
    def yes(value, label):
        assert value, label
        checks.append(label)
    for path in (HERE / 'run.py', HERE / 'check.py'):
        ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
        checks.append('Python AST ' + path.name)
    adapted = run.source()
    ast.parse(adapted)
    yes(adapted.replace(run.NEW, run.OLD, 1) == run.ORIGINAL.read_text('utf-8-sig'),
        'original component runner has exactly one compiler-mode replacement')
    yes("'-debug=false', '-optimize=true'" in adapted and "'-debug=true'" not in adapted,
        'same debug/optimization mode as successful original positive control')
    yes("wait_owned(process, 60" in adapted and "1024**3" in adapted and 'with Registration(' in adapted,
        'original timeout, commit threshold and registration remain')
    yes("GAME/'adl64.exe'" in adapted and "GAME/'runtimes/air/win64'" in adapted,
        'actual game AIR runtime paths remain')
    text = (HERE / 'component/SamplerRetentionDoc.as').read_text('utf-8')
    # This only checks lexical structure. It is not an AS compiler invocation.
    lexical = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'', '', text)
    stack = []
    for char in lexical:
        if char in '([{':
            stack.append(char)
        elif char in ')]}':
            assert stack and stack.pop() == {')': '(', ']': '[', '}': '{'}[char], 'AS delimiter mismatch'
    yes(not stack, 'AS delimiters closed')
    yes('PHASE_LIMIT_MS:int=3000,WORK_LIMIT_MS:int=2000' in text, 'bounded per-phase/work clock')
    yes('MAX_CHUNKS:int=4096,CHUNK_SIZE:int=256' in text and 'RING_SIZE:int=64' in text,
        'bounded equal pressure algorithm and 64 live-object ring')
    yes('SAMPLE_LIMIT:int=32768,SEGMENT_LIMIT:int=8192,CALLBACK_LIMIT:int=8' in text,
        'bounded enumeration and callback records')
    yes('insideCallback?SAMPLE_LIMIT-SEGMENT_LIMIT:SAMPLE_LIMIT' in text,
        'one final segment reserved from callback enumeration')
    yes('row.finalSamples!=null && row.finalSamples.cpu>0' in text,
        'arithmetic control requires actual CPU samples')
    yes('if(state=="work")work();else if(state=="collect")collectPhase()' in text and
        'if(state=="arm")startPhase();else if(state=="pause")pausePhase()' in text,
        'RENDER start/pause and separate next-ENTER collection')
    yes('row.pauseCount=count();' in text and 'row.nextEnterCount=count();' in text,
        'separate immediate and deferred pause counts')
    yes('row.callbackCalls>0 && row.callbackClears>0 && row.postCallbackCpu>0' in text,
        'actual callback and fresh CPU required for support evidence')
    yes('row.callbackUnset=true' in text and 'row.stopped=true' in text and 'row.cleared=count()==0' in text,
        'each phase records unset/stop/clear')
    yes('gameLoaded:false' in text, 'component explicitly declares no game loaded')
    proof = run.verify()
    print(json.dumps(dict(static_checks=len(checks), source_sha256=proof['source_sha256'],
                         expected_runtime_assertions=9, python_syntax=True, as_lexical_only=True,
                         compiled=False, air_started=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
