import sys, os
from pathlib import Path
RC = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RC / 'tools' / 'host_authority' / 'field2_driver'))
from run import HiddenProcess
out = open(RC / 'build/ab/b-perfdiag-airprobe-01' / 'cmd.out.log', 'w', encoding='utf-8')
try:
    p = HiddenProcess(['C:/Windows/System32/cmd.exe', '/c', 'echo hello-private-desktop'], cwd='C:/Windows/System32', stdout=out, stderr=out)
    print('pid', p.pid, 'desktop', p.desktop)
    for i in range(10):
        code = p.poll()
        if code is not None:
            print('exit', code, hex(code & 0xffffffff)); break
        import time; time.sleep(1)
    else:
        print('still alive, killing'); p.kill(); p.wait(timeout=10)
    p.close()
finally:
    out.close()
