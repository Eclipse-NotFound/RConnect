"""Offline acceptance and rejection checks; no subprocess/JVM/AIR."""
from pathlib import Path
import json
from readback import body,verify_grafon,verify_guard

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def main():
    rows=[]
    def check(label,call,accept):
        try:call();actual=True
        except (AssertionError,ValueError):actual=False
        rows.append(dict(label=label,passed=actual==accept))
        assert actual==accept,label
    before=(ROOT/'experimental/recovery-first-raster/native/fe/graph/Grafon.as').read_text(encoding='utf-8-sig')
    after=(ROOT/'build/m52/recovery-first-raster-host-03/after/scripts/fe/graph/Grafon.as').read_text(encoding='utf-8-sig')
    check('authored source accepted',lambda:verify_grafon(before),True)
    check('actual host03 optional braces accepted',lambda:verify_grafon(after),True)
    for name,expected in (('sceneEnsure','return;'),('sceneTick','return;'),('sceneViewReady','returnfalse;')):
        text=body(after,name)
        check(name+' correct direct branch',lambda e=expected:verify_guard('if(this.rconnectRasterWaiting())'+e,'this.rconnectRasterWaiting()',e),True)
        variants={
            'wrong return':text.replace(expected,'returntrue;',1),
            'missing return':text.replace(expected,'',1),
            'reversed condition':text.replace('if(this.rconnectRasterWaiting())','if(!this.rconnectRasterWaiting())',1),
            'guard moved': 'this.sceneCullSurfaces();'+text,
            'extra branch work':text.replace(expected,expected+'this.sceneCullSurfaces();',1)}
        for label,variant in variants.items():
            check(name+' rejects '+label,lambda v=variant,e=expected:verify_guard(v,'this.rconnectRasterWaiting()',e),False)
    for label,old,new in (
        ('draw reset reversed','if(!this.sceneRasterizing)\n         {\n            this.rconnectRasterTicket = null;','if(this.sceneRasterizing)\n         {\n            this.rconnectRasterTicket = null;'),
        ('draw reset missing','this.rconnectRasterTicket = null;',''),
        ('draw reset wrong value','this.rconnectRasterTicket = null;','this.rconnectRasterTicket = {};'),
        ('draw reset moved','if(!this.sceneRasterizing)\n         {\n            this.rconnectRasterTicket = null;','this.sceneCullSurfaces();\n         if(!this.sceneRasterizing)\n         {\n            this.rconnectRasterTicket = null;'),
        ('completed ticket scans again','if(this.rconnectRasterTicket != null && this.rconnectRasterTicket.unpainted === true','if(this.rconnectRasterTicket != null')):
        assert after.count(old)==1,(label,after.count(old))
        check(label,lambda s=after.replace(old,new,1):verify_grafon(s),False)
    result=dict(passed=True,checks=len(rows),assertions=rows,subprocess_started=False,air_started=False)
    (HERE/'readback-offline-checks.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(passed=True,checks=len(rows))))
if __name__=='__main__':main()

