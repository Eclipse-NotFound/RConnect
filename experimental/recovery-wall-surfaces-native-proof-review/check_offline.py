"""Bounded representation positives/negatives and unchanged gameplay oracle."""
import copy
import json
from pathlib import Path
import verify_evidence as v

HERE=Path(__file__).resolve().parent


def words(pixel):
    result=[0xff505050]*(128*128);result[17]=pixel;return result


def main():
    checks=[]
    def test(label,fn):
        try:fn();checks.append(dict(label=label,passed=True))
        except Exception as e:checks.append(dict(label=label,passed=False,error=repr(e)))
    def accepted(a,b):assert v.compatible_words(words(a),words(b))['representation_compatible']
    def rejected(a,b):
        try:v.compatible_words(words(a),words(b))
        except AssertionError:return
        raise AssertionError('Incompatible pixel accepted')
    test('exact opaque pixels',lambda:accepted(0xff123456,0xff123456))
    test('exact transparent pixels',lambda:accepted(0,0))
    for a,b in [(0x387f7f76,0x38808076),(0x6c86847b,0x6c87847b),(0xda1a1b19,0xda191b18),(0x1b26261c,0x1b25251c)]:
        test('observed floor/ceil '+hex(a),lambda a=a,b=b:accepted(a,b))
    test('opaque one-bit RGB error rejected',lambda:rejected(0xff123456,0xff133456))
    test('transparent hidden RGB corruption rejected',lambda:rejected(0,1))
    test('alpha one-bit error rejected',lambda:rejected(0x387f7f76,0x39808076))
    test('translucent two-bit error rejected',lambda:rejected(0x387f7f76,0x38818076))
    test('adjacent but incompatible translucent channel rejected',lambda:rejected(0x38333333,0x38343333))
    def shifted():
        a=words(0x387f7f76);b=words(0x38808076);b[17],b[18]=b[18],b[17]
        try:v.compatible_words(a,b)
        except AssertionError:return
        raise AssertionError('Misplaced pixel accepted')
    test('wrong pixel location rejected',shifted)
    def exact_gameplay():
        frozen=v.load_frozen();base=[0xff505050]*(128*128);end=base.copy()
        for i in range(50,56):end[i]=0xff123456+i
        sparse=[n for i in range(50,56) for n in (i,end[i])]
        frames=[dict(at=10,wall=10010,cost=1,native=[],display=[]),dict(at=510,wall=10510,cost=1,native=sparse,display=sparse),dict(at=10010,wall=20010,cost=1,native=sparse,display=sparse)]
        surface=dict(width=400,height=400,side=320,gutter=40,scratchDifferent=True,staged=True)
        a=dict(source=True,role='host',round=0,weapon='lmg',area=dict(x=1936,y=1036,w=128,h=128),target=dict(x=2000,y=1100),
            baseline=base,baselineDisplay=base,finalNative=end,finalDisplay=end,shots=1,hits=[dict(x=2000,y=1100)],
            attackAttempts=1,attackAccepted=1,firstAttack=dict(accepted=True),nativeOracle=sparse,sourceFirst=10500,
            start=10,startWall=10010,end=10011,frames=frames,surfaces=[surface],finalSurfaces=[surface],maxCaptureMs=1)
        b=copy.deepcopy(a);b.update(source=False,role='join')
        assert frozen.compare(a,b)['functional_pass']
        b['finalNative'][50]+=1
        assert not frozen.compare(a,b)['functional_pass'],'Gameplay uint comparison was relaxed'
    test('original gameplay uint comparator still rejects one-bit remote damage pixel',exact_gameplay)
    def actual_control():
        r=v.reanalyze(v.ROOT/'build/m52/recovery14-wall-surfaces-native-03')
        assert not r['passed'] and r['source_unchanged'] and r['framework_passed']
        assert r['png_representation_compatible'] and not r['png_exact_argb']
        assert len(r['rows'])==4 and len(r['errors'])==4
        assert [x['native_expected'] for x in r['rows']]==[119,101,1466,1262]
        assert all(not x['functional_pass'] and x['native_wrong']==x['native_expected'] and x['native_extra']==0 for x in r['rows'])
        assert sum(x['rounding_pixels'] for x in r['png_audit'].values())==936
        assert sum(x['rounding_channels'] for x in r['png_audit'].values())==1338
    test('all 32 actual control PNGs compatible; four genuine missing-sync cases remain failed',actual_control)
    def actual_candidate():
        r=v.reanalyze(v.ROOT/'build/m52/recovery16-wall-surfaces-native-01')
        assert not r['passed'] and r['source_unchanged'] and r['framework_passed']
        assert r['png_representation_compatible'] and not r['png_exact_argb']
        assert len(r['rows'])==4 and len(r['errors'])==4
        assert [x['native_expected'] for x in r['rows']]==[104,53,1327,731]
        assert [x['native_wrong'] for x in r['rows']]==[1,1,3,1]
        assert all(not x['functional_pass'] and x['native_extra']==0 for x in r['rows'])
        assert sum(x['rounding_pixels'] for x in r['png_audit'].values())==960
        assert sum(x['rounding_channels'] for x in r['png_audit'].values())==1408
    test('candidate PNG representation is compatible but all four exact gameplay mismatches remain failed',actual_candidate)
    result=dict(passed=all(x['passed'] for x in checks),checks=checks,count=len(checks),failed=sum(not x['passed'] for x in checks),
                jvm_started=False,air_started=False,gameplay_qualified=False,performance_qualified=False)
    (HERE/'offline-result-v2.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False));return 0 if result['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
