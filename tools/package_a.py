"""Package an already validated A artifact; no game files or personal config."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[1]
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args();build=args.build.resolve();out=args.output.resolve()
    assert not out.exists(),'Existing package is preserved'
    manifest=json.loads((build/'manifest.json').read_text('utf8'));swf=(build/'RConnectMod.swf').read_bytes()
    assert sha(swf)==manifest['swf_sha256'],'Artifact changed'
    for group,path in [('source',ROOT/'src'),('stubs',ROOT/'tools/stubs')]:
        actual={p.relative_to(path).as_posix():sha(p.read_bytes()) for p in sorted(path.rglob('*.as'))}
        assert actual==manifest[group],group+' changed after build'
    version=re.search(r'VERSION\s*:\s*String\s*=\s*"([^"]+)"',(ROOT/'src/RConnectMod.as').read_text('utf8'))[1]
    install=(ROOT/'INSTALL.txt').read_bytes()
    files={'INSTALL.txt':install,'先读我-安装说明.txt':install,'mods/RConnect/release/RConnectMod.swf':swf}
    names=['README.md','README.zh-CN.md','Start-Coop.bat','docs/release-0.2.24.md',
           'docs/release-0.2.24-tcp1.md','docs/tcp-tunnel.zh-CN.md','docs/tcp-tunnel.md',
           'docs/local-coop.md','docs/BUILD-A.md',
           'tools/start_coop.ps1','tools/RConnect.Process.ps1','tools/RConnect.Profile.ps1',
           'tools/second_player_descriptor.xml','tools/keep_test_responsive.ps1']
    for name in names:files['mods/RConnect/'+name]=(ROOT/name).read_bytes()
    files['mods/RConnect/BUILD.json']=json.dumps(dict(version=version,**manifest),ensure_ascii=False,indent=2).encode('utf8')
    checks={name:sha(data) for name,data in files.items()}
    out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,'x',zipfile.ZIP_DEFLATED) as z:
        for name,data in files.items():z.writestr(name,data)
        z.writestr('SHA256.json',json.dumps(checks,indent=2)+'\n')
    with zipfile.ZipFile(out) as z:
        assert z.testzip() is None
        assert set(z.namelist())==set(files)|{'SHA256.json'}
        for name,digest in checks.items():assert sha(z.read(name))==digest,name
    result=dict(version=version,zip_sha256=sha(out.read_bytes()),swf_sha256=sha(swf),bytes=out.stat().st_size,files=checks)
    out.with_suffix('.verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps({k:result[k] for k in ('version','zip_sha256','swf_sha256','bytes')}))
if __name__=='__main__':main()
