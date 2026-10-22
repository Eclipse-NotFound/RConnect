"""Same original build recipe and flags; only diagnostic input names change."""
from binding import HERE,verify_tools,sha
import baseline
SOURCE=HERE.parent/'recovery-early-paint-driver/prepare.py'
EDITS=(("diagnostic_kind='ensure-work'","diagnostic_kind='ensure-work-tail-cpu-v1'"),
       ("out/'paint-inputs.json'","out/'tail-inputs.json'"),
       ("out/'paint-prepare.py'","out/'tail-prepare.py'"),
       ("('FirstRasterSceneProbe.as','PaintTimingBuffer.as')",
        "('FirstRasterSceneProbe.as','PaintTimingBuffer.as','PaintTailSampler.as','FlashPaintTailSampler.as')"))
def source():
    assert sha(SOURCE)=='61feb85e3f35cea151337cb5a62521e797b5a83ef22cbc4b9b22e2d473759040'
    text=SOURCE.read_text(encoding='utf-8-sig')
    for old,new in EDITS:text=baseline.replace_once(text,old,new)
    return text
def main():
    verify_tools()
    scope=dict(__file__=__file__,__name__='tail_exact_build_adapter')
    exec(compile(source(),str(SOURCE),'exec'),scope);scope['main']()
if __name__=='__main__':main()
