from pathlib import Path
import json
HERE=Path(__file__).resolve().parent
RC=HERE.parents[1];OUT=RC/'build/github-a-release'
path=OUT/'locales/messages.json';data=json.loads(path.read_text('utf8'))
keys=json.loads((HERE/'keys.json').read_text('utf8'));seen=set()
for line in (HERE/'translations.tsv').read_text('utf8').splitlines():
    if line.startswith('#') or not line:continue
    fields=line.split('|');assert len(fields)==7,(len(fields),line)
    index=int(fields[0]);assert index not in seen;seen.add(index)
    for code,text in zip(('tw','ua','pl','de','es','jp'),fields[1:]):
        text=text.replace('\\n','\n')
        if code=='tw':text=text.replace('抛','拋')
        if code=='ua':text=text.replace('Урон','Шкода').replace('урон','шкода')
        data[keys[index]][code]=text
assert len(seen)==len(keys)
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print('Completed',len(data),'messages in nine languages')
