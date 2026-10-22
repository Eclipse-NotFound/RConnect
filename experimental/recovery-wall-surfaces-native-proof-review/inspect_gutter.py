"""Read existing core-only evidence; do not manufacture absent gutter pixels."""
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
EVIDENCE=ROOT/'build/m52/recovery16-wall-surfaces-native-01/wall-proof'


def contains(x,y,left,top,width,height):
    return left<=x<left+width and top<=y<top+height


def inspect():
    result=dict(round=2,index=6737,source_role='host',source_neighbor_pixel_values_recorded=False,
        wire_pixel_values_recorded=False,impact_enumeration_order_observed=False,
        production_root_cause_confirmed=False,air_started=False,jvm_started=False,roles={})
    for role in ('host','join'):
        path=EVIDENCE/role/'round-2-proof.json';data=path.read_bytes();d=json.loads(data)
        index=result['index'];x=d['area']['x']+index%128;y=d['area']['y']+index//128
        result['world']={'x':x,'y':y};surfaces=[]
        for order,s in enumerate(d['surfaces']):
            if not contains(x,y,s['x'],s['y'],s['width'],s['height']):continue
            core=contains(x,y,s['x']+s['gutter'],s['y']+s['gutter'],s['side'],s['side'])
            surfaces.append(dict(order=order,x=s['x'],y=s['y'],local_x=x-s['x'],local_y=y-s['y'],
                core=core,gutter=not core,revision_before=s['revision']))
        timeline=[];previous=(d['baseline'][index],d['baselineDisplay'][index])
        for f in d['frames']:
            native=dict(zip(f['native'][::2],f['native'][1::2])).get(index,d['baseline'][index])
            display=dict(zip(f['display'][::2],f['display'][1::2])).get(index,d['baselineDisplay'][index])
            if (native,display)!=previous:
                timeline.append(dict(at=f['at'],wall=f['wall'],native=f'{native:08x}',display=f'{display:08x}'))
                previous=(native,display)
        result['roles'][role]=dict(path=str(path),sha256=hashlib.sha256(data).hexdigest(),
            source=d['source'],surfaces_in_recorded_order=surfaces,
            baseline=f"{d['baseline'][index]:08x}",final_native=f"{d['finalNative'][index]:08x}",
            final_display=f"{d['finalDisplay'][index]:08x}",timeline=timeline,
            wire_fields=sorted({key for row in d['wire'] for cell in row['cells'] for key in cell}))
    assert result['world']==dict(x=657,y=4448)
    host=result['roles']['host'];assert len(host['surfaces_in_recorded_order'])==4
    assert host['surfaces_in_recorded_order'][0]['gutter']
    assert [s['order'] for s in host['surfaces_in_recorded_order'] if s['core']]==[1]
    assert host['final_native']=='ff43433c' and result['roles']['join']['final_native']=='ff42423c'
    return result


if __name__=='__main__':
    target=HERE/'gutter-review.json';assert not target.exists(),'Preserve prior analysis'
    result=inspect();target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({key:result[key] for key in ('world','production_root_cause_confirmed')}))
