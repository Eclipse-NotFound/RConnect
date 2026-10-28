"""The validated mixed-newline sources must survive Git staging byte-for-byte."""
import hashlib,json,subprocess
from build import RC,HERE,sha,save
manifest=json.loads((HERE/'validated-manifest.json').read_text('utf8'))
checked=0
for group,directory in [('source','validated-src'),('stubs','stubs')]:
 for relative,expected in manifest[group].items():
  path=HERE/directory/relative
  staged=subprocess.check_output(['git','show',':'+path.relative_to(RC).as_posix()],cwd=RC)
  assert hashlib.sha256(staged).hexdigest()==sha(path)==expected,path
  checked+=1
save(HERE/'evidence/git-byte-audit.json',{'passed':True,'files':checked,'version':'0.2.24-animfix3',
 'source_manifest_sha256':sha(HERE/'validated-manifest.json'),
 'scope':'Exact staged source and external declaration bytes; retained native baseline whitespace is intentional.'})
print(json.dumps({'passed':True,'exact_staged_files':checked}))
