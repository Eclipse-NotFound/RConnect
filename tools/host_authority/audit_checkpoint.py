"""Check exact B/native/extension inputs and receipts; not a release gate."""
import argparse
import hashlib
import os
from pathlib import Path
from common import ROOT, EXPERIMENT, inside_build, read, save, sha, verify_files
from run_probe import records
from archive_evidence import blob_data


def require(ok, message):
    if not ok:raise ValueError(message)


class RuntimeFiles:
    """Check original bytes, including losslessly archived copies of a run."""
    def __init__(self, directory, verified_blobs):
        self.directory=directory.resolve()
        self.verified_blobs=verified_blobs
        self.archive=None
        archive_path=directory/'runtime-archive.json'
        if archive_path.exists():
            self.archive=read(archive_path)
            require(self.archive['format']=='rconnect-runtime-archive-v1'
                    and self.archive['complete'],'Incomplete runtime archive')
            require(self.archive['run_receipt_sha256']==sha(directory/'run.json'),
                    'Archived run receipt changed')
            self.store=inside_build(ROOT/self.archive['store'])
            # Runtime loader spelling is Rconnect, while the physical Windows
            # folder is RConnect. Keep original names and match as Windows did.
            self.entries={name.casefold():entry for name,entry in self.archive['files'].items()}
            require(len(self.entries)==len(self.archive['files']),'Ambiguous archive path casing')

    def check(self, name, digest):
        path=(self.directory/name).resolve()
        require(path.is_relative_to(self.directory),'Runtime path escaped its run')
        if path.is_file():
            require(sha(path)==digest,'Runtime input changed: '+name)
            return
        require(self.archive is not None,'Missing runtime input: '+name)
        entry=self.entries.get(Path(name).as_posix().casefold())
        require(entry is not None and entry['sha256']==digest,'Archive input differs: '+name)
        cache_key=(str(self.store),digest)
        if cache_key not in self.verified_blobs:
            self.verified_blobs[cache_key]=len(blob_data(self.store,digest))
        require(self.verified_blobs[cache_key]==entry['size'],'Archive input size differs: '+name)


def main():
    ap=argparse.ArgumentParser()
    for name in ('candidate','native','tdfc','logic','output'):ap.add_argument('--'+name,required=True)
    for name in ('rv','msw','sandy'):ap.add_argument('--'+name)
    ap.add_argument('--run',action='append',required=True)
    ap.add_argument('--default',action='append',default=[],dest='defaults')
    ap.add_argument('--scope',choices=('single-room','dual-room'),default='single-room')
    a=ap.parse_args()
    candidate,native,tdfc,logic,out=[inside_build(ROOT/p) for p in (a.candidate,a.native,a.tdfc,a.logic,a.output)]
    require(not out.exists(),'Keep each audit immutable')
    bm,nm,tm=read(candidate/'build-input.json'),read(native/'native-input.json'),read(tdfc/'build-input.json')
    for directory,manifest in [(candidate,bm),(native,nm),(tdfc,tm)]:verify_files(directory,manifest['sources'])
    require(sha(candidate/'RConnectMod.swf')==bm['candidate_sha256'],'B bytes changed')
    require(sha(native/'pfe.swf')==nm['candidate_sha256'],'Native bytes changed')
    require(sha(tdfc/'TDFCMod.swf')==tm['candidate_sha256'],'TDFC bytes changed')
    for name,digest in bm['sources'].items():
        data=(EXPERIMENT/name).read_bytes()
        if name=='src/authority/BuildInfo.as':data=data.decode('utf-8').replace('\r\n','\n').replace('__SOURCE_HASH__',bm['source_id']).replace('\n',os.linesep).encode('utf-8')
        require(hashlib.sha256(data).hexdigest()==digest,'Uncompiled B source: '+name)
    verify_files(ROOT.parent/'TDFC',tm['sources'])
    extensions={}
    for key,folder,artifact in [('rv','RealisticVision','RealisticVisionMod.swf'),
                                ('msw','MoreSkills&Weapons','MoreSkillsWeaponsMod.swf'),
                                ('sandy','Sandevistan','SandevistanMod.swf')]:
        if getattr(a,key) is None:continue
        directory=inside_build(ROOT/getattr(a,key));manifest=read(directory/'build-input.json')
        verify_files(directory,manifest['sources'])
        verify_files(ROOT.parent/folder,manifest['sources'])
        require(sha(directory/artifact)==manifest['candidate_sha256'],key+' bytes changed')
        extensions[key]=(directory,manifest)
    evidence=dict(experimental_only=True,scope=a.scope+' technical checkpoint, not full architecture or release',
        candidate_sha256=bm['candidate_sha256'],native_sha256=nm['candidate_sha256'],tdfc_sha256=tm['candidate_sha256'],
        source_id=bm['source_id'],current_sources_match=True,runs=[],defaults=[],script_sha256=sha(__file__))
    evidence['extensions']={key:dict(candidate_sha256=m['candidate_sha256'],
        manifest_sha256=sha(d/'build-input.json')) for key,(d,m) in extensions.items()}
    verified_blobs={}
    for path in a.run:
        directory=inside_build(ROOT/path);r=read(directory/'run.json')
        for key,target in [('build_manifest_sha256',candidate/'build-input.json'),('native_manifest_sha256',native/'native-input.json'),('tdfc_manifest_sha256',tdfc/'build-input.json')]:
            require(r[key]==sha(target),'Run did not use the selected frozen inputs: '+path)
        for key in ('rv','msw','sandy'):
            expected=sha(extensions[key][0]/'build-input.json') if key in extensions else None
            require(r.get(key+'_manifest_sha256')==expected,
                    'Run used different or unaudited '+key+' inputs: '+path)
        require(r['complete'] and r['installation_unchanged'] and r['owned_processes_exited'],'Incomplete or unclean run: '+path)
        require(r['script_sha256']==sha(directory/'tools/run_probe.py'),'Run driver changed: '+path)
        runtime=RuntimeFiles(directory,verified_blobs)
        for role,value in r['roles'].items():
            for name,digest in value['files'].items():runtime.check(role+'/'+name,digest)
            events=records(directory/(role+'.log'))
            require(value['done'] and not value['failed'] and not value['fatal'] and value['runtime_unchanged'],'Failed role: '+path+'/'+role)
            require(sum(x['kind']=='PASS' for x in events)==value['passed'] and any(x['kind']=='DONE' for x in events),'Log and receipt differ')
            require(not any(x['kind'] in ('FAIL','FATAL','error') for x in events),'Raw log has failures or runtime exceptions')
            runtime.check(role+'/authority-test.xml',value['descriptor_sha256'])
            runtime.check(role+'/mods/Rconnect/release/config.txt',value['config_sha256'])
            for name,digest in value['auxiliary_logs'].items():require(sha(directory/(role+'.'+name))==digest,'Auxiliary log changed')
        require(all(sha(ROOT.parents[1]/name)==digest for name,digest in r['protected_before'].items()),'Installed bytes changed')
        evidence['runs'].append(dict(path=path,run=r['run'],receipt_sha256=sha(directory/'run.json'),
            roles={role:dict(passed=v['passed'],failed=v['failed'],done=v['done']) for role,v in r['roles'].items()}))
    lr=read(logic/'run.json')
    require(lr['build_manifest_sha256']==sha(tdfc/'build-input.json') and lr['complete'] and not lr['failed'] and lr['exit_code']==0,'TDFC logic tests did not pass')
    require(sha(logic/'LogicTests.swf')==tm['tests_sha256'],'Logic SWF mismatch')
    evidence['logic']=dict(path=a.logic,passed=lr['passed'],receipt_sha256=sha(logic/'run.json'))
    for path in a.defaults:
        directory=inside_build(ROOT/path);r=read(directory/'run.json')
        require(r['done'] and not r['failed'] and not r['fatal'] and r['default_tdfc_observed'] and r['owned_process_exited'] and r['installation_unchanged'] and r['runtime_unchanged'],'Default smoke failed')
        require(r['tdfc_manifest_sha256']==sha(tdfc/'build-input.json'),'Default TDFC bytes differ')
        for key in ('rv','msw','sandy'):
            expected=sha(extensions[key][0]/'build-input.json') if key in extensions else None
            require(r.get('external_manifests',{}).get(key)==expected,'Default '+key+' inputs differ')
        if r['native_manifest_sha256'] is not None:
            require(r['native_manifest_sha256']==sha(native/'native-input.json'),'Default native patch bytes differ')
        default_events=records(directory/'RConnect-B.log')
        require(sum(x['kind']=='PASS' for x in default_events)==r['passed'] and any(x['kind']=='DONE' for x in default_events)
            and not any(x['kind'] in ('FAIL','FATAL') for x in default_events),'Default raw log differs')
        require(sha(directory/'src/RConnectMod.as')==r['source_sha256'],'Default probe source changed')
        verify_files(directory/'game',r['files'])
        evidence['defaults'].append(dict(path=path,passed=r['passed'],receipt_sha256=sha(directory/'run.json'),
            scope='Native single-player functional smoke only; not complete numerical equivalence'))
    out.mkdir(parents=True)
    save(out/'audit.json',evidence)
    print(dict(path=str(out),ok=True,runs=len(evidence['runs']),logic=lr['passed'],defaults=len(evidence['defaults'])),flush=True)


if __name__=='__main__':main()
