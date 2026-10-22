"""Only Python/source counterexamples. Never call adapted main or FFDec."""
import inspect
import json
from pathlib import Path
import tempfile
import prepare_host as p


def main():
    rows=[]
    def check(label,call,accept=True):
        try:call();actual=True
        except (AssertionError,ValueError):actual=False
        rows.append(dict(label=label,passed=actual==accept));assert actual==accept,label
    source=(p.PROPOSAL/'native'/p.REL).read_text(encoding='utf-8-sig')
    original=(p.HOST/'after/scripts'/p.REL).read_text(encoding='utf-8-sig')
    check('frozen entire proposal and exact native input pinned',p.source_meta)
    check('FD92 original first-raster behavior accepted',lambda:p.raster.verify_grafon(original))
    check('FD92 does not pretend to contain new wall bridge',lambda:p.wall.verify(original),False)
    check('new source passes old and new behavior anchors',lambda:p.verify_grafon(source))
    for label,before,after in (
        ('old raster completion regression','this.rconnectRasterTicket.unpainted = false;','this.rconnectRasterTicket.unpainted = true;'),
        ('missing wall callback','rconnectWallNotify("after",wallMark,affected,wallToken)','missingNotify("after",wallMark,affected,wallToken)'),
        ('missing revision advance','++entry.revision','entry.revision'),
        ('lost original random draws','Math.random(),Math.random()','Math.random(),0'),
        ('lost source callback error isolation','this.rconnectWallErrors++ < 4','this.rconnectWallErrors++ < 9')):
        if before not in source:
            # Whitespace alone is irrelevant to semantic anchor verification.
            compact=p.wall.compact(source);before=p.wall.compact(before);after=p.wall.compact(after)
            assert before in compact,label
            # Method extraction expects the native declaration spaces; only
            # use compact matching to locate an exact authored spelling.
            import re
            expression=r'\s*'.join(re.escape(char) for char in before)
            matched=re.search(expression,source);assert matched,label
            variant=source[:matched.start()]+after+source[matched.end():]
        else:variant=source.replace(before,after,1)
        check('reject '+label,lambda s=variant:p.verify_grafon(s),False)
    def adaptation():
        _,adapted,edits=p.adapted_main();restored=adapted
        for before,after in reversed(edits):
            assert restored.count(after)==1
            restored=restored.replace(after,before)
        assert restored==inspect.getsource(p.base.main), 'Unexpected shared execution change'
        for literal in ("resource='game'","record.before_launch(","record.child(process.pid)","process.wait(timeout=240)",
                        "process.kill();process.wait()","record.child_stopped()","for name in REPRESENTATIVES:",
                        "assert normalized((out/'before-classes.txt')","movie_header(HOST)==movie_header(out/'pfe.swf')",
                        "if x!=y:assert x[0] in (72,82)","len(installed)==22"):
            assert literal in adapted,literal
        assert len(p.base.REPRESENTATIVES)==7
        assert "source_meta" not in adapted.split("subprocess.Popen",1)[1].split("record.child_stopped",1)[0]
    check('ten exact adaptations preserve registry/launch/cleanup/whole class list/header/tags/seven representatives/22 inputs',adaptation)
    def source_receipt_rejected():
        with tempfile.TemporaryDirectory(prefix='source-only-',dir=p.HERE) as name:
            temporary=Path(name).resolve();assert temporary.parent==p.HERE.resolve()
            old=p.M52;p.M52=temporary
            try:
                out=temporary/'candidate';(out/'import/fe/graph').mkdir(parents=True)
                (out/'import'/p.REL).write_text(source,encoding='utf-8')
                for compiled,validated in ((False,False),(True,False)):
                    d=dict(kind='isolated-wall-surfaces-host',patched_classes=['fe.graph.Grafon'],import_sources={p.REL:p.sha(out/'import'/p.REL)},compiled=compiled,validated=validated)
                    (out/'prepared.json').write_text(json.dumps(d),encoding='utf-8')
                    try:p.verify_prepared(out)
                    except AssertionError:continue
                    raise AssertionError('Source-only or failed readback receipt accepted')
            finally:p.M52=old
    check('source-only and compiled-but-failed receipts never unlock native runs',source_receipt_rejected)
    result=dict(passed=True,checks=len(rows),assertions=rows,jvm_started=False,air_started=False,compiled=False,native_qualified=False)
    (p.HERE/'offline-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,checks=len(rows)),ensure_ascii=False))


if __name__=='__main__':main()
