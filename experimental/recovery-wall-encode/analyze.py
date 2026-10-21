"""Read-only profile/corpus analysis; writes only this independent directory."""
from pathlib import Path
import base64,collections,hashlib,json,re,struct,zlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    log=ROOT/'build/cooperation/3b8269a9a7/host.log'
    lines=log.read_text(encoding='utf-8-sig').splitlines()
    profile=[(s.split('{',1)[0],json.loads('{'+s.split('{',1)[1])) for s in lines if '"stacks"' in s and '{' in s]
    stacks=collections.Counter()
    def visit(obj):
        if isinstance(obj,dict):
            if isinstance(obj.get('stacks'),dict):
                for key,value in obj['stacks'].items():
                    if 'WallImpactVisuals/packed' in key:stacks[key]+=value
            for value in obj.values():visit(value)
        elif isinstance(obj,list):
            for value in obj:visit(value)
    for _,obj in profile:visit(obj)
    error=re.compile(r'\b(?:Error\s*#\d+|TypeError|ArgumentError|ReferenceError|VerifyError|RangeError|SecurityError|out of memory|ERROR)\b',re.I)
    diagnostic_errors=[]
    for role in ('host','join'):
        for p in sorted((ROOT/'build/cooperation/3b8269a9a7/module-logs'/role).glob('*.log')):
            for n,line in enumerate(p.read_text(encoding='utf-8-sig',errors='replace').splitlines(),1):
                matches=list(error.finditer(line))
                if matches:diagnostic_errors.append(dict(role=role,file=p.name,line=n,prefix=line[:90],
                    matches=[dict(token=m.group(),context=line[max(0,m.start()-70):m.end()+80]) for m in matches[:8]],
                    profile_data='"stacks"' in line or '"allocations"' in line))
    corpus=ROOT/'experimental/recovery-wall-working-set/data/flight-payloads.json'
    data=json.loads(corpus.read_text(encoding='utf-8'));sizes=[]
    for p in data['payloads']:
        words=json.loads(zlib.decompress(base64.b64decode(p['data'])))
        raw=struct.pack('>H',len(words)//2)+b''.join(struct.pack('>HI',*words[i:i+2]) for i in range(0,len(words),2))
        sizes.append(dict(id=p['id'],pixels=len(words)//2,legacy_chars=len(p['data']),
            binary_chars=4+len(base64.b64encode(zlib.compress(raw))),raw_bytes=len(raw)))
    save(HERE/'profile-review.json',dict(run='3b8269a9a7',host_log_sha256=sha(log),
        profile_prefixes=[p for p,_ in profile],packed_stacks=stacks.most_common(16),
        error_regex_matches=diagnostic_errors,original_results_unchanged=True,
        semantic_corpus_source=str(corpus),corpus_sha256=sha(corpus),
        corpus_is_current_density_distribution=False,python_zlib_size_only_not_AS_speed=True,
        size_rows=sizes,size_totals=dict(legacy=sum(x['legacy_chars'] for x in sizes),
            binary=sum(x['binary_chars'] for x in sizes))))
    print(json.dumps(dict(packed_stack_kinds=len(stacks),packed_samples=sum(stacks.values()),
        profile_error_rows=len(diagnostic_errors),profile_data_false_positives=sum(x['profile_data'] for x in diagnostic_errors),
        natural_payloads=len(sizes),pixels_min=min(x['pixels'] for x in sizes),pixels_max=max(x['pixels'] for x in sizes),
        chars_old=sum(x['legacy_chars'] for x in sizes),chars_new=sum(x['binary_chars'] for x in sizes)),ensure_ascii=False))
if __name__=='__main__':main()
