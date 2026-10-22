"""Reuse the frozen native runner, adding one queued gate and one private config edit."""
from pathlib import Path
from native_inputs import sha,once,verify_tools,queued_gate,configure_sand
SOURCE=Path(__file__).resolve().parent.parent/'recovery-early-revisit-frozen-rv/native_runner.py'
def source_text():
    assert sha(SOURCE)=='d311e5f5104095492949057184725a789a80c811bc9d9780383951281ac005f2'
    text=once(SOURCE.read_text(encoding='utf-8-sig'),
        "    check_cancel_requested(output,'registration acquired')",
        "    check_cancel_requested(output,'registration acquired')\n    queued_gate(args,output)")
    return once(text,'    configuration_files={};descriptors={};launches=[]',
        '    configure_sand(frozen,output)\n    configuration_files={};descriptors={};launches=[]')
def main():
    verify_tools()
    scope=dict(__file__=__file__,__name__='cooldown_frozen_owned_runner',queued_gate=queued_gate,configure_sand=configure_sand)
    exec(compile(source_text(),str(SOURCE),'exec'),scope)
    scope['main']()
if __name__=='__main__':main()
