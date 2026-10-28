"""Freeze the verified A source into an isolated public-release worktree."""
from pathlib import Path
import hashlib, json, re, shutil
RC=Path(__file__).resolve().parents[2]
BASE=RC/'experimental/a-visual-round2'
OUT=RC/'build/github-a-release'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
assert (OUT/'.git').is_file()
manifest=json.loads((BASE/'validated-manifest.json').read_text('utf8'))
for rel,digest in manifest['source'].items():
    assert sha(BASE/'validated-src'/rel)==digest,rel
for source,destination in [(BASE/'validated-src',OUT/'src'),(BASE/'stubs',OUT/'tools/stubs')]:
    assert destination.resolve().is_relative_to(OUT.resolve())
    wanted={p.relative_to(source) for p in source.rglob('*.as')}
    for p in destination.rglob('*.as'):
        if p.relative_to(destination) not in wanted: p.unlink()
    for rel in wanted:
        target=destination/rel;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/rel,target)
p=OUT/'src/modlocales/connect/RCLocaleMessages.as';s=p.read_text('utf8')
data=json.loads(s[s.index('{',s.index('DATA:Object')):s.rindex('};')+1])
for k,row in data.items():row['zh']=k
literal=r'"(?:[^"\\]|\\.)*"'
pattern=r'\btr\(('+literal+r')\s*,\s*('+literal+r')\s*,\s*('+literal+r')\s*\)'
p=OUT/'src/rconnect/ui/NetHud.as';s=p.read_text('utf8')
def replace(m):
    zh,en,ru=map(json.loads,m.groups());data[zh]=dict(zh=zh,en=en,ru=ru)
    return 'RCLocale.text('+m[1]+')'
s=re.sub(pattern,replace,s)
s=re.sub(r'      private function tr\(zh:String,en:String,ru:String\):String \{.*?\n      \}\n','',s,flags=re.S)
p.write_text(s,encoding='utf8')
p=OUT/'src/rconnect/ui/NetKeybinds.as';s=p.read_text('utf8')
start=s.index('         var rows:Object=');end=s.index('\n      }',start)
rows=s[start:end]
for m in re.finditer('('+literal+r')\s*:\s*\[\s*('+literal+r')\s*,\s*('+literal+r')\s*\]',rows):
    zh,en,ru=map(json.loads,m.groups());data[zh]=dict(zh=zh,en=en,ru=ru)
s=s[:start]+'         return RCLocale.text(text);'+s[end:]
p.write_text(s,encoding='utf8')
# Native key names are symbols. Only the fallback word needs translation.
s=s.replace('"Key "+b.code','RCLocale.text("按键")+" "+b.code')
p.write_text(s,encoding='utf8');data['按键']=dict(zh='按键',en='Key',ru='Клавиша')
for k,zh in {'Host':'创建房间','Join':'加入','Leave':'离开','Send':'发送','offline':'离线','hosting':'主持中','joining':'连接中','connected':'已连接','mode: ':'模式：',' (port ':'（端口 ', ', peers ':'，玩家 ',' (id ':'（ID ',' of ':'，宿主 ', ', remotes ':'，队友 ','error: ':'错误：','host failed (port busy?)':'无法创建房间，请检查端口是否被占用。','connect failed (check ip/port)':'连接失败，请检查地址和端口。','F10 hide/show / chat: Enter':'F10 显隐浮窗 / Enter 聊天'}.items():data[k]['zh']=zh
(OUT/'locales').mkdir(exist_ok=True)
(OUT/'locales/messages.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
(RC/'experimental/a-locales-release/keys.json').write_text(json.dumps(list(data),ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(dict(messages=len(data),source=len(manifest['source']),worktree=str(OUT))))
