"""Static closure/provenance checks for the two-fixture repair; no VM."""
import ast
import json
import re
from prepare_components import HERE,CONTROL,PASSED,BASE,REPAIRS,sha,read,text,files,verify_sources


def main():
    verify_sources();rows=[]
    def check(ok,label):
        rows.append(dict(passed=bool(ok),label=label));assert ok,label
    info=read(HERE/'integration.json')
    for mode in ('on','off'):
        folder=HERE/'components'/mode;original=CONTROL/'components'/mode
        now=files(folder);previous=files(original)
        check(now.keys()==previous.keys(),'same 18 source files: '+mode)
        check(sorted(p for p in now if now[p]!=previous[p])==sorted(REPAIRS),'exactly two fixture repairs: '+mode)
        for rel in REPAIRS:
            check(sha(folder/rel)==sha(PASSED/'src'/rel),'exact old passed fixture: '+mode+'/'+rel)
        check(sha(folder/'NativeTravelRoomChecks.as')==sha(original/'NativeTravelRoomChecks.as'),
              'all 109 intended cases unchanged: '+mode)
        for name in ('FirstRasterGate','SeedRasterEntry','NativeTravelPlan'):
            rel='rconnect/core/'+name+'.as'
            check(sha(folder/rel)==sha(BASE/'src'/rel),'exact13 production '+name+': '+mode)
        check('wrong native Land' in text(folder/'rconnect/core/TravelGuard.as')
              and 'return g.roomKey()==String(info.roomKey)' in text(folder/'rconnect/core/TravelGuard.as'),
              'follow substitute still checks native land identity and room: '+mode)
        check('gg.X=x;gg.Y=y;' in text(folder/'rconnect/core/TravelPlacement.as'),
              'placement substitute preserves explicit coordinate observation: '+mode)
        known=set()
        for path in folder.rglob('*.as'):
            body=text(path);package=re.search(r'package\s*([\w.]*)\s*\{',body)[1]
            known.add((package+'.' if package else '')+path.stem)
        for path in folder.rglob('*.as'):
            for imp in re.findall(r'\bimport\s+([\w.*]+)\s*;',text(path)):
                if imp.startswith('flash.') or imp.startswith('fl.'):continue
                exists=any(k.rsplit('.',1)[0]==imp[:-2] for k in known if '.' in k) if imp.endswith('.*') else imp in known
                check(exists,'explicit import/package present: '+mode+'/'+path.name+' -> '+imp)
    a=files(HERE/'components/on');b=files(HERE/'components/off')
    check(sorted(k for k in a if a[k]!=b[k])==['SeedGateCaseMode.as','rconnect/core/RoomSync.as'],
          'on/off only expected constant and one real RoomSync return differ')
    on=text(HERE/'components/on/rconnect/core/RoomSync.as');off=text(HERE/'components/off/rconnect/core/RoomSync.as')
    check(on==text(BASE/'src/rconnect/core/RoomSync.as'),'on uses complete accurate13 RoomSync')
    check(off.replace('            return null; // Isolated control: seed identity/anchor/restore remain; native raster runs normally.',
                      '            return firstRaster.open(w,l,g,seedRaster.id);',1)==on,
          'off only disables seed first-raster ticket; all restore/ACK/anchor logic remains')
    check([r['path'] for r in info['dependency_audit'] if not r['identical_to_passed']]==
          ['NativeTravelRoomChecks.as','rconnect/core/TravelGuard.as','rconnect/core/TravelPlacement.as'],
          'all original17 files audited; no other unintended fixture replacement')
    for path in sorted(HERE.glob('*.py')):
        ast.parse(text(path),filename=str(path));check(True,'Python syntax: '+path.name)
    report=dict(passed=True,checks=len(rows),assertions=rows,expected_runtime_checks_each=109,
                JVM_started=False,AIR_started=False,component_compiled=False)
    (HERE/'static-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    inventory={p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
               if p.is_file() and p.name!='manifest.json' and '__pycache__' not in p.parts}
    (HERE/'manifest.json').write_text(json.dumps(dict(kind='seed-control-component-fixture-repair',files=inventory),
        ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(checks=len(rows),passed=True,JVM_started=False,AIR_started=False)))


if __name__=='__main__':main()
