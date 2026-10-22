"""Three exact metadata/file-name adaptations to the immutable original build recipe."""
from binding import HERE,verify_tools,sha
SOURCE=HERE.parent/'recovery-early-paint-driver/prepare.py'
SOURCE_SHA='61feb85e3f35cea151337cb5a62521e797b5a83ef22cbc4b9b22e2d473759040'
EDITS=(("diagnostic_kind='ensure-work'","diagnostic_kind='ensure-work-aggregate-v1'"),
       ("out/'paint-inputs.json'","out/'aggregate-inputs.json'"),
       ("out/'paint-prepare.py'","out/'aggregate-prepare.py'"))
def source():
    assert sha(SOURCE)==SOURCE_SHA
    text=SOURCE.read_text(encoding='utf-8-sig')
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text
def main():
    verify_tools()
    scope=dict(__file__=__file__,__name__='frozen_paint_build_aggregate_adapter')
    exec(compile(source(),__file__,'exec'),scope)
    scope['main']()
if __name__=='__main__':main()
