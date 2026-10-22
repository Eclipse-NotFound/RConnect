"""FD92 -> wall-surface Grafon only; reuse registered first-raster FFDec flow.

No AIR or deployment. Source-only preparation is never host acceptance.
The existing main is adapted at exact anchors; its launch/registration/child
cleanup, representative/class/header/non-code checks remain in place.
"""
import hashlib
import importlib.util
import inspect
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
M52=ROOT/'build/m52'
PROPOSAL=ROOT/'experimental/recovery-wall-surfaces'
BASE_RECIPE=ROOT/'experimental/recovery-first-raster/prepare_host.py'
RASTER=ROOT/'experimental/recovery-first-raster-native'
HOST=M52/'recovery-first-raster-host-03'
HOST_SHA='fd92fbd5ae92b5c8d4cbf8151d11796a140810f34988b7031e258c747d86734e'
HOST_RECHECK=M52/'recovery-first-raster-host-recheck-03/receipt.json'
HANDOFF_SHA='74fb4fa581be26f7f56710ab692c2158a1d65016c7cae6d16fa97356ff6fe0f1'
REL='fe/graph/Grafon.as'
REFERENCE_SHA='405db96290d7a5cc3df1cab45cb4ec42657ce37a54bb774e25042d38dda6e88a'
PINS={BASE_RECIPE:'d233ac3d770e15f4a15d43e7290edac139c26c8c38fa52545853c97611ced16d',
      RASTER/'readback.py':'96e413ff9a596e40a8ad74fe66a4d1c8b8325f3b3890c5a9c0595b53287231e2',
      RASTER/'reverify_host.py':'47ce9c10e256d56554ea3ab1704b7db2833cc5dbb242e03a285ea2149e4472a6',
      PROPOSAL/'verify_readback.py':'85443bb1415abcd0eec851bc8742836a940faf5af2795ac07f7dc421c21bd0de'}


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read(path):return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def load(name,path):
    assert path in PINS and sha(path)==PINS[path], 'Pinned helper changed: '+str(path)
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


base=load('wall_surface_original_host_recipe',BASE_RECIPE)
raster=load('wall_surface_retained_raster_check',RASTER/'readback.py')
wall=load('wall_surface_new_readback_check',PROPOSAL/'verify_readback.py')


def verify_grafon(source):
    raster.verify_grafon(source)
    assert wall.verify(source) is True


def source_meta():
    assert sha(PROPOSAL/'handoff.json')==HANDOFF_SHA, 'Freeze a new recipe for changed wall proposal'
    handoff=read(PROPOSAL/'handoff.json')
    assert handoff['status']=='source-frozen-awaiting-parent-build'
    assert not handoff['compiled'] and not handoff['air_started'] and not handoff['installed']
    for name,digest in handoff['files'].items():
        path=(PROPOSAL/name).resolve();assert path.is_relative_to(PROPOSAL.resolve()) and sha(path)==digest,name
    source=PROPOSAL/'native'/REL
    assert sha(source)==handoff['files']['native/'+REL]
    verify_grafon(source.read_text(encoding='utf-8-sig'))
    assert sha(HOST/'after/scripts'/REL)==REFERENCE_SHA
    return dict(overlays={'native/'+REL:sha(source)})


def host_evidence():
    sys.path.insert(0,str(RASTER))
    verifier=load('wall_surface_reverify_fd92',RASTER/'reverify_host.py')
    value=verifier.verify()
    assert value==read(HOST_RECHECK), 'FD92 independent readback receipt no longer matches'
    assert value['candidate_sha256']==HOST_SHA and value['original_receipt_preserved']
    return value


def helpers():
    sys.path.insert(0,str(ROOT/'tools/validation'))
    from prepare_recovery_native_travel import normalized,movie_header
    from run_security_terminals import installation
    sys.path.insert(0,str(ROOT/'tools/host_authority'))
    from patch_native import swf_tags
    return normalized,movie_header,installation,swf_tags


def extra_inputs():
    source_meta();evidence=host_evidence()
    paths=[Path(__file__),HERE/'README.md',HERE/'check_offline.py',HERE/'handoff.json',PROPOSAL/'handoff.json',HOST_RECHECK,
           *PINS, RASTER/'test_readback.py',ROOT/'tools/host_authority/common.py',
           ROOT/'tools/validation/run_security_terminals.py']
    paths += [PROPOSAL/name for name in read(PROPOSAL/'handoff.json')['files']]
    paths += [HOST/name for name in evidence['host_files']]
    paths += [Path(path) for path in read(HOST/'prepared.json')['inputs']]
    return {str(p.resolve()):sha(p) for p in paths}


def check_log(out,name):
    for path in (out/name,out/(name+'.stderr.log')):
        text=path.read_text(encoding='utf-8',errors='replace')
        assert not any(token in text for token in ('SEVERE:','Unknown preprocessor instruction','Exception in thread')),path


def save(path,value):
    if path.name=='prepared.json':
        assert path.parent.parent==M52
        _,_,installation,_=helpers()
        value.update(recipe_sha256=sha(__file__),base_recipe_sha256=PINS[BASE_RECIPE],
            source_handoff_sha256=HANDOFF_SHA,original_sha256=value['installation_before']['pfe.swf'],
            base_host_original_failed_receipt_sha256=sha(HOST/'prepared.json'),
            base_host_independent_recheck_sha256=sha(HOST_RECHECK),
            first_raster_readback_checked=bool(value['validated']),wall_surface_readback_checked=bool(value['validated']))
        binding=path.parent/'native-input.json'
        frozen=dict(kind='wall-surface-host-inputs',base_sha256=HOST_SHA,
            original_installed_sha256=value['original_sha256'],source_handoff_sha256=HANDOFF_SHA,
            input_sources=value['inputs'],import_sources=value['import_sources'],
            original_failed_fd92_receipt_sha256=value['base_host_original_failed_receipt_sha256'],
            fd92_independent_recheck_sha256=value['base_host_independent_recheck_sha256'])
        if binding.exists():assert read(binding)==frozen,'Frozen native inputs changed'
        else:base.save(binding,frozen)
        value['native_input_sha256']=sha(binding)
        if 'installed_unchanged' in value:
            after=installation();value['installation_after']=after
            if len(after)!=22 or after!=value['installation_before']:
                value.update(validated=False,installed_unchanged=False,validation_error='22 installed inputs changed')
        if value.get('compiled'):
            value['readback_files']={p.relative_to(path.parent).as_posix():sha(p)
                for folder in ('before','after') for p in sorted((path.parent/folder).rglob('*')) if p.is_file()}
            for name in ('before.log','import.log','after.log','before-classes.txt','after-classes.txt'):
                for suffix in ('','.stderr.log'):
                    p=path.parent/(name+suffix)
                    if p.is_file():value['readback_files'][p.name]=sha(p)
        # Success tags cannot survive a final installation/source failure.
        if not value['validated']:
            value['first_raster_readback_checked']=value['wall_surface_readback_checked']=False
    base.save(path,value)


def complete(out,built):
    if built:
        receipt=read(out/'prepared.json')
        assert receipt['compiled'] and receipt['validated'] and receipt['source_unchanged'] and receipt['installed_unchanged']
    print(out)


def adapted_main():
    text=inspect.getsource(base.main)
    edits=[
        ("meta=json.loads((HERE/'integration.json').read_text(encoding='utf-8'))","meta=_wall_source_meta()"),
        ("reference=ROOT/'build/m52/recovery-native-travel-host-01/after/scripts'/REL","reference=ROOT/'build/m52/recovery-first-raster-host-03/after/scripts'/REL"),
        ("'09ff2387e744acb9716ae6760de2f8a1c49963da76ae97d072d1bcb759ab6ef3'",repr(REFERENCE_SHA)),
        ("HERE/'integration.json'","HERE/'handoff.json'"),
        ("installed=installation();assert len(installed)==22","inputs.update(_wall_extra_inputs())\n    installed=installation();assert len(installed)==22"),
        ("kind='isolated-first-raster-host'","kind='isolated-wall-surfaces-host'"),
        ("owner='RConnect / 首次栅格 Grafon 隔离补丁'","owner='RConnect / 大图墙痕 Grafon 隔离补丁'"),
        ("purpose='E159 Grafon only; FFDec, no AIR'","purpose='FD92 Grafon only; retain raster and add wall bridge, no AIR'"),
        ("if name=='import.log':receipt.update(compiled=True,candidate_sha256=sha(out/'pfe.swf'))",
         "_wall_check_log(out,name)\n                    if name=='import.log':receipt.update(compiled=True,candidate_sha256=sha(out/'pfe.swf'))"),
        ("print(out)","_wall_complete(out,a.build)"),
    ]
    for before,after in edits:
        assert text.count(before)==1, 'Shared recipe anchor changed: '+before
        text=text.replace(before,after)
    scope=dict(base.__dict__)
    scope.update(HERE=PROPOSAL,HOST=HOST/'pfe.swf',PIN=HOST_SHA,verify_grafon=verify_grafon,save=save,
                 _wall_source_meta=source_meta,_wall_extra_inputs=extra_inputs,_wall_check_log=check_log,_wall_complete=complete)
    exec(compile(text,'<wall-surface exact host adapter>','exec'),scope)
    return scope['main'],text,edits


def verify_prepared(out):
    """Read-only future native-test gate: rejects source-only/failed receipts."""
    out=Path(out).resolve();assert out.parent==M52
    meta=read(out/'prepared.json');assert meta['kind']=='isolated-wall-surfaces-host'
    assert meta['patched_classes']==['fe.graph.Grafon'] and set(meta['import_sources'])=={REL}
    assert {p.relative_to(out/'import').as_posix() for p in (out/'import').rglob('*.as')}=={REL}
    for key in ('compiled','validated','source_unchanged','installed_unchanged','non_code_tags_unchanged',
                'loader_unchanged','class_list_unchanged','movie_header_unchanged','first_raster_readback_checked','wall_surface_readback_checked'):
        assert meta.get(key) is True,key
    assert not meta['air_started'] and not meta['installed'] and not meta['gameplay_qualified'] and not meta['performance_qualified']
    assert meta['base_sha256']==HOST_SHA and meta['candidate_sha256']==sha(out/'pfe.swf')
    assert meta['recipe_sha256']==sha(__file__) and meta['source_handoff_sha256']==HANDOFF_SHA
    for path,digest in meta['inputs'].items():assert sha(path)==digest,path
    for name,digest in meta['import_sources'].items():assert sha(out/'import'/name)==digest,name
    for name,digest in meta['readback_files'].items():assert sha(out/name)==digest,name
    assert meta['native_input_sha256']==sha(out/'native-input.json')
    binding=read(out/'native-input.json');assert binding['input_sources']==meta['inputs'] and binding['import_sources']==meta['import_sources']
    source_meta();host_evidence()
    normalized,movie_header,installation,swf_tags=helpers()
    assert len(installation())==22 and installation()==meta['installation_before']==meta['installation_after']
    assert normalized((out/'before/scripts'/REL).read_text(encoding='utf-8-sig'))==normalized((HOST/'after/scripts'/REL).read_text(encoding='utf-8-sig'))
    verify_grafon((out/'import'/REL).read_text(encoding='utf-8-sig'))
    verify_grafon((out/'after/scripts'/REL).read_text(encoding='utf-8-sig'))
    for name in base.REPRESENTATIVES:
        p=Path(*name.split('.')).with_suffix('.as')
        old=normalized((out/'before/scripts'/p).read_text(encoding='utf-8-sig'))
        new=normalized((out/'after/scripts'/p).read_text(encoding='utf-8-sig'))
        assert old==new and hashlib.sha256(old.encode()).hexdigest()==meta['representative_normalized_sha256'][name],name
    old,new=swf_tags(HOST/'pfe.swf'),swf_tags(out/'pfe.swf');assert len(old)==len(new);changed=[]
    for n,(a,b) in enumerate(zip(old,new)):
        assert a[0]==b[0]
        if a!=b:assert a[0] in (72,82);changed.append(n)
    assert changed==meta['changed_code_tags'] and changed and movie_header(HOST/'pfe.swf')==movie_header(out/'pfe.swf')
    assert normalized((out/'before-classes.txt').read_text(encoding='utf-8-sig'))==normalized((out/'after-classes.txt').read_text(encoding='utf-8-sig'))
    return dict(kind=meta['kind'],validated=True,candidate_sha256=meta['candidate_sha256'],base_sha256=HOST_SHA,
        original_sha256=meta['original_sha256'],manifest_sha256=sha(out/'prepared.json'),native_input_sha256=meta['native_input_sha256'],
        recipe_sha256=sha(__file__),source_handoff_sha256=HANDOFF_SHA,gameplay_qualified=False,performance_qualified=False)


if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='verify':
        assert len(sys.argv)==3
        print(json.dumps(verify_prepared(ROOT/sys.argv[2]),ensure_ascii=False))
    else:adapted_main()[0]()
