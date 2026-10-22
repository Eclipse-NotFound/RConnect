"""Unchanged owned AIR runner; the outer diagnostic kind is the only edit."""
from pathlib import Path
import baseline as _tail_base
_tail_source=Path(__file__).resolve().parent.parent/'recovery-early-paint-aggregate/runtime_adapter.py'
assert _tail_base.sha(_tail_source)=='17aa8ae180c58e1385b35c7597a4bbebc41c704448e8388347fda15dede45341'
_text=_tail_base.replace_once(_tail_source.read_text(encoding='utf-8-sig'),
    "KIND='ensure-work-aggregate-v1'","KIND='ensure-work-tail-cpu-v1'")
_text=_tail_base.replace_once(_text,"if __name__=='__main__':main()",'')
exec(compile(_text,str(_tail_source),'exec'),globals())
_unchanged_runner_source=runner_source
def runner_source():
    text=_unchanged_runner_source()
    return _tail_base.replace_once(text,
        "    check_cancel_requested(output,'registration acquired')",
        "    check_cancel_requested(output,'registration acquired')\n"
        "    from queued_gate import assert_installation\n"
        "    assert_installation(args,output)")
if __name__=='__main__':main()
