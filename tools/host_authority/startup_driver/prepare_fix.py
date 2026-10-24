"""Apply only the two startup fixes to frozen B190, excluding later performance candidates."""
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT, read, save, sha, verify_files


def main():
    original=ROOT/'build/ab/b3-build-190'
    manifest=read(original/'build-input.json');verify_files(original,manifest['sources'])
    if sha(original/'RConnectMod.swf')!=manifest['candidate_sha256']:raise ValueError('B190 artifact changed')
    out=ROOT/'build/ab/b190-startup2-source'
    if out.exists():raise FileExistsError(out)
    out.mkdir()
    for folder in ('src','stubs'):shutil.copytree(original/folder,out/folder)
    changed={}
    for name in ('src/RConnectMod.as','src/authority/PlainData.as'):
        before=(out/name).read_text(encoding='utf-8')
        current=(ROOT/'experimental/host-authority'/name).read_text(encoding='utf-8')
        if name.endswith('PlainData.as'):
            expected=before.replace('      /** Native loadGame requires its original associative Array types. */\n'
                '      public static function nativeCopy(value:*):* {return visit(value,0,{n:0},true);}',
                '      /** Only for local native saveToObj/save() data, never wire input. The\n'
                '       * complete journey is larger than a network character profile. Preserve\n'
                '       * sparse/associative Arrays and retain depth/type/key validation. */\n'
                '      public static function nativeCopy(value:*):* {return visit(value,0,{n:0},true);}')
            expected=expected.replace('if(depth>20 || ++budget.n>24000)',
                'if(depth>20 || !preserveArrays && ++budget.n>24000)')
        else:
            expected=before.replace('B3-0.1-experimental','B3-0.1-startup2').replace(
                '            if(host!=null){host.dispose();host=null;tactics=null;}\n'
                '            if(replica!=null){replica.dispose();replica=null;if(tactics!=null){tactics.dispose();tactics=null;}}',
                '            if(host!=null){host.dispose();host=null;}\n'
                '            if(replica!=null){replica.dispose();replica=null;}\n'
                '            // We acquire this lease before either side becomes fully active.\n'
                '            // A waiting host has no RoomRuntime; a failed replica constructor\n'
                '            // has no replica. Both must still release the acquired interface.\n'
                '            if(tactics!=null){tactics.dispose();tactics=null;}')
        if expected==before:raise ValueError('Patch anchor missed: '+name)
        # Only the exact startup edits are borrowed; other B development remains excluded.
        for marker in ('!preserveArrays && ++budget.n',) if name.endswith('PlainData.as') else ('B3-0.1-startup2','We acquire this lease'):
            if marker not in current:raise ValueError('Production fix missing: '+name)
        (out/name).write_text(expected,encoding='utf-8')
        changed[name]=dict(before=manifest['sources'][name],after=sha(out/name))
    stamp=out/'src/authority/BuildInfo.as'
    stamp.write_text(stamp.read_text().replace(manifest['source_id'],'__SOURCE_HASH__'),encoding='utf-8')
    save(out/'recipe.json',dict(base='b3-build-190',base_manifest=sha(original/'build-input.json'),
         changed=changed,restored_build_stamp=True,script_sha256=sha(__file__)))
    print(json.dumps(dict(source=str(out),changed=changed),ensure_ascii=False))


if __name__=='__main__':main()
