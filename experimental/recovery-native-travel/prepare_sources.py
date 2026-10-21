"""Stage AS/Python text only. No compiler, game runtime or deployment commands."""
import argparse, hashlib, json
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/"build/m52/recovery-01"
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def put(source,dest):
    assert source.suffix in (".as",".py")
    dest.parent.mkdir(parents=True,exist_ok=True)
    dest.write_text(source.read_text(encoding="utf-8-sig"),encoding="utf-8",newline="\n")
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output",type=Path)
    args=parser.parse_args();out=(ROOT/args.output).resolve()
    assert out.parent==ROOT/"build/m52" and not out.exists(),"Use a fresh build/m52 directory"
    manifest=json.loads((HERE/"integration.json").read_text(encoding="utf-8"))
    frozen=json.loads((BASE/"prepared.json").read_text(encoding="utf-8-sig"))
    for rel,expected in frozen["source"].items(): assert sha(BASE/"src"/rel)==expected,rel
    for rel,expected in manifest["source_inputs"].items(): assert sha(HERE/rel)==expected,rel
    out.mkdir()
    for folder in (BASE/"src",BASE/"tools"):
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix in (".as",".py"):put(p,out/folder.name/p.relative_to(folder))
    for folder in ("src","native-import","tests"):
        for p in (HERE/folder).rglob("*.as"):put(p,out/folder/p.relative_to(HERE/folder))
    receipt=dict(kind="source-only-native-travel",base="build/m52/recovery-01",
        source={p.relative_to(out/"src").as_posix():sha(p) for p in (out/"src").rglob("*.as")},
        native_import={p.relative_to(out/"native-import").as_posix():sha(p) for p in (out/"native-import").rglob("*.as")},
        compiled=False,runtime_tested=False,deployed=False)
    (out/"prepared.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"output":str(out),"source_files":len(receipt["source"]),"native_classes":list(receipt["native_import"])}))
if __name__=="__main__":main()
