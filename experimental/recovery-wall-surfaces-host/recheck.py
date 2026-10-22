"""Independent readback for host01; preserve its original failed receipt.

FFDec emits two pseudo expressions in the unchanged sceneDrawSteps closure.
Only that complete, baseline-identical method is excluded from the new bridge
textual-anchor check. All actual changed methods and all other host gates run.
No JVM, AIR, binary mutation, deployment or gameplay qualification.
"""
import argparse
import hashlib
from pathlib import Path
import prepare_host as h


def verify_prepared(out):
    out=Path(out).resolve(); assert out.parent==h.M52
    meta=h.read(out/'prepared.json')
    assert meta['kind']=='isolated-wall-surfaces-host'
    assert meta['compiled'] and not meta['validated']
    assert meta['error']=='AssertionError()'
    assert meta['source_unchanged'] and meta['installed_unchanged']
    assert not any(meta[k] for k in ('air_started','installed','gameplay_qualified','performance_qualified'))
    assert meta['patched_classes']==['fe.graph.Grafon']
    assert meta['base_sha256']==h.HOST_SHA
    assert meta['candidate_sha256']==h.sha(out/'pfe.swf')
    assert meta['recipe_sha256']==h.sha(h.__file__)
    assert meta['source_handoff_sha256']==h.HANDOFF_SHA
    assert set(meta['import_sources'])=={h.REL}
    assert {p.relative_to(out/'import').as_posix() for p in (out/'import').rglob('*.as')}=={h.REL}
    for path,digest in meta['inputs'].items(): assert h.sha(path)==digest,path
    for path,digest in meta['readback_files'].items(): assert h.sha(out/path)==digest,path
    assert h.sha(out/'import'/h.REL)==meta['import_sources'][h.REL]
    assert h.sha(out/'native-input.json')==meta['native_input_sha256']
    binding=h.read(out/'native-input.json')
    assert binding['input_sources']==meta['inputs'] and binding['import_sources']==meta['import_sources']
    h.source_meta(); h.host_evidence()
    normalized,movie_header,installation,swf_tags=h.helpers()
    installed=installation()
    assert len(installed)==22 and installed==meta['installation_before']==meta['installation_after']
    before=(out/'before/scripts'/h.REL).read_text(encoding='utf-8-sig')
    after=(out/'after/scripts'/h.REL).read_text(encoding='utf-8-sig')
    assert normalized(before)==normalized((h.HOST/'after/scripts'/h.REL).read_text(encoding='utf-8-sig'))
    old_closure=h.wall.method(before,'sceneDrawSteps')
    new_closure=h.wall.method(after,'sceneDrawSteps')
    assert normalized(old_closure)==normalized(new_closure)
    assert before.count('§§')==after.count('§§')==new_closure.count('§§')==2
    assert after.count(new_closure)==1
    h.verify_grafon((out/'import'/h.REL).read_text(encoding='utf-8-sig'))
    h.raster.verify_grafon(after)
    assert h.wall.verify(after.replace(new_closure,'')) is True
    representatives={}
    for name in h.base.REPRESENTATIVES:
        p=Path(*name.split('.')).with_suffix('.as')
        a=normalized((out/'before/scripts'/p).read_text(encoding='utf-8-sig'))
        b=normalized((out/'after/scripts'/p).read_text(encoding='utf-8-sig'))
        assert a==b,name
        representatives[name]=hashlib.sha256(a.encode()).hexdigest()
    old,new=swf_tags(h.HOST/'pfe.swf'),swf_tags(out/'pfe.swf')
    assert len(old)==len(new); changed=[]
    for i,(a,b) in enumerate(zip(old,new)):
        assert a[0]==b[0]
        if a!=b:
            assert a[0] in (72,82)
            changed.append(i)
    assert changed and movie_header(h.HOST/'pfe.swf')==movie_header(out/'pfe.swf')
    assert normalized((out/'before-classes.txt').read_text(encoding='utf-8-sig'))==normalized((out/'after-classes.txt').read_text(encoding='utf-8-sig'))
    for name in ('before.log','import.log','after.log','before-classes.txt','after-classes.txt'):h.check_log(out,name)
    return dict(kind='isolated-wall-surfaces-host-independent-recheck',validated=True,
        candidate_sha256=meta['candidate_sha256'],base_sha256=h.HOST_SHA,
        original_sha256=meta['original_sha256'],manifest_sha256=h.sha(out/'prepared.json'),
        native_input_sha256=meta['native_input_sha256'],recipe_sha256=h.sha(__file__),
        source_handoff_sha256=h.HANDOFF_SHA,original_failed_receipt_preserved=True,
        unchanged_closure_sha256=hashlib.sha256(normalized(new_closure).encode()).hexdigest(),
        first_raster_readback_checked=True,wall_surface_readback_checked=True,
        representative_normalized_sha256=representatives,changed_code_tags=changed,
        non_code_tags_unchanged=True,movie_header_unchanged=True,class_list_unchanged=True,
        installation_unchanged=True,gameplay_qualified=False,performance_qualified=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('host',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();out=(h.ROOT/a.output).resolve()
    assert out.parent==h.M52 and not out.exists()
    value=verify_prepared(h.ROOT/a.host)
    out.mkdir();h.base.save(out/'receipt.json',value)
    print(value['candidate_sha256'], 'independent readback passed; no runtime qualification')
