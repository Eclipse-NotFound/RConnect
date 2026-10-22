"""Three exact observer adaptations; retain the frozen execution and error audit body."""
from native_inputs import EXIT,sha

SOURCE=EXIT/'run_native.py'
SOURCE_SHA='d8de0e59510b406cce932f80a0a7729c653e3ed47cb8b2febd5b63246e35a75a'
OLD_SOLO="    assert not (a.solo and meta.get('diagnostic_only')), 'First resumed mirror frame profiling requires a peer'"
NEW_SOLO="    assert a.scenario=='scene' and meta.get('diagnostic_kind')=='ensure-work', 'Only the exact three-scene paint diagnostic is admitted'"
OLD_PROFILE="            if meta.get('diagnostic_kind')=='early-revisit':"
NEW_PROFILE="""            if meta.get('diagnostic_kind')=='ensure-work':
                result['profile_valid']=True
                result['paint_profiles']={}
                for paint_role in (('host',) if a.solo else ('host','join')):
                    try:
                        result['paint_profiles'][paint_role]=paint_audit_log(run/(paint_role+'.log'))
                    except (AssertionError,KeyError,TypeError,ValueError,OSError) as paint_error:
                        result['profile_valid']=False
                        result['paint_profiles'][paint_role]=dict(valid=False,error=str(paint_error),
                            diagnostic_only=True,performance_qualified=False)
            elif meta.get('diagnostic_kind')=='early-revisit':"""
OLD_QUAL="    result['early_performance_qualified']=False"
NEW_QUAL=OLD_QUAL+"\n    result['performance_qualified']=False"
EDITS=((OLD_SOLO,NEW_SOLO),(OLD_PROFILE,NEW_PROFILE),(OLD_QUAL,NEW_QUAL))

def source():
    assert sha(SOURCE)==SOURCE_SHA
    text=SOURCE.read_text(encoding='utf-8-sig')
    for old,new in EDITS:
        assert text.count(old)==1,old
        text=text.replace(old,new,1)
    return text
