"""Reuse the byte-exact frozen probe; only the separately compiled helper changes."""
from pathlib import Path
import hashlib
HERE=Path(__file__).resolve().parent
BASE=HERE.parent/'recovery-early-paint-driver/tests/FirstRasterSceneProbe.as'
SHA='a1e5298292f33aa30dee4f827eb89d39270b1ae181c086ae3ff67b8c83f593e7'
def main():
    data=BASE.read_bytes();assert hashlib.sha256(data).hexdigest()==SHA
    out=HERE/'tests/FirstRasterSceneProbe.as'
    if out.exists():assert out.read_bytes()==data
    else:out.write_bytes(data)
    print(out)
if __name__=='__main__':main()
