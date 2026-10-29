"""Verified local deployment plus a configuration-preserving peer update ZIP."""
from pathlib import Path
import hashlib,json,shutil,zipfile
RC=Path(__file__).resolve().parents[2];ROOT=RC/'build/github-a-release';OUT=RC/'build/a-tcp-01'
OLD='239252df5ea24ec6da5005bd80bfeb31a91e393d6b2bfe7b1fd7b371cd4e618c'
NEW='690604878bd8707007a99e3ad14f8f5f3f55cdd4948c8debe6cc87363afd38c9'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'manifest.json').read_text('utf8'))
for name in ['fe52e36c9c','25e9211372']:
    directory=RC/'build/cooperation'/name
    assert json.loads((directory/'tunnel-result.json').read_text('utf8'))['passed']
    assert json.loads((directory/'input.json').read_text('utf8'))['candidate_sha256']==NEW
    assert json.loads((directory/'result.json').read_text('utf8'))['installation_unchanged']
for rel,digest in manifest['source'].items():assert sha(ROOT/'src'/rel)==digest
candidate=OUT/'RConnectMod.swf';target=RC/'release/RConnectMod.swf'
assert sha(candidate)==NEW and sha(target)==OLD
backup=RC/'build/a-tcp-deploy-20261029';backup.mkdir()
shutil.copy2(target,backup/'RConnectMod.before.swf');assert sha(backup/'RConnectMod.before.swf')==OLD
shutil.copy2(candidate,target);assert sha(target)==NEW
receipt=dict(status='verified',before=OLD,after=NEW,backup=str(backup/'RConnectMod.before.swf'),tests=['fe52e36c9c','25e9211372'])
(backup/'deployment.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
install='''RConnect A 0.2.24-tcp1 / TCP tunnel update

双方保存退出；先安装 ModLoader。将本包 mods 合并到游戏根目录，保留原配置和存档，运行模组扫描器后重启。
这是本模组更新包，不包含游戏本体、ModLoader或其他模组。双侧须使用同版。
TCP 穿透详见 mods/RConnect/docs/tcp-tunnel.zh-CN.md。
宿主游戏端口与隧道本地端口一致；加入侧填写隧道域名:外部端口。
示例：宿主23456，隧道127.0.0.1:23456，队友node.example.net:45678。
无需把宿主的本地端口改成45678；不要使用HTTP/HTTPS/UDP转发或Proxy Protocol头。
这只是本机中转与模拟延迟验证的候选，真实公网节点尚未实测。
回退：保存退出，恢复原模组备份，扫描并重启。

Save and close both games. Install ModLoader first, merge mods into the game folder,
run the scanner and restart. Keep existing settings and saves. Both players use this version.
For plain TCP forwarding, map the host's game port (default 23456) to an external port.
The guest can paste tunnel-hostname:external-port, or enter the hostname and port separately.
Only TCP byte forwarding is supported, without HTTP/HTTPS wrapping or Proxy Protocol.
Tested with an owned local relay and simulated latency, not your actual public tunnel.
Restore the prior mod, scan and restart to roll back.
'''
files={'INSTALL-TCP.txt':install.encode('utf8'),'mods/RConnect/release/RConnectMod.swf':candidate.read_bytes(),
       'mods/RConnect/docs/tcp-tunnel.zh-CN.md':(ROOT/'docs/tcp-tunnel.zh-CN.md').read_bytes()}
for name in ['Start-Coop.bat','tools/start_coop.ps1','tools/RConnect.Process.ps1','tools/RConnect.Profile.ps1','tools/second_player_descriptor.xml','tools/keep_test_responsive.ps1']:
    files['mods/RConnect/'+name]=(ROOT/name).read_bytes()
checks={name:hashlib.sha256(data).hexdigest() for name,data in files.items()}
package=RC/'build/a-tcp-01/RConnect_A_0.2.24-tcp1.zip'
with zipfile.ZipFile(package,'x',zipfile.ZIP_DEFLATED) as z:
    for name,data in files.items():z.writestr(name,data)
    z.writestr('SHA256.json',json.dumps(checks,indent=2))
with zipfile.ZipFile(package) as z:
    assert z.testzip() is None
    for name,digest in checks.items():assert hashlib.sha256(z.read(name)).hexdigest()==digest
receipt['package']=str(package);receipt['package_sha256']=sha(package)
(backup/'deployment.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(json.dumps(receipt))
