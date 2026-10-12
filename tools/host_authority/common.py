"""Tools for the separate host-authority experiment. No release writes."""
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT = ROOT / 'experimental/host-authority'
BUILD = ROOT / 'build/ab'
JAVA = Path('C:/Users/hello/Documents/_sandevistan_dev/jdk-11.0.32.1+1-jre/bin/java.exe')
_OLD_TOOLS = Path('D:/RemainsMod/mods/Sandevistan/build/tools')
_LOCAL_TOOLS = ROOT.parent/'Sandevistan/build/tools'
SDK = Path(os.environ['RCONNECT_B_SDK']) if os.environ.get('RCONNECT_B_SDK') else next(
    (p/'flexsdk' for p in (_OLD_TOOLS, _LOCAL_TOOLS) if (p/'flexsdk/lib/mxmlc.jar').is_file()), _OLD_TOOLS/'flexsdk')
FFDEC = Path(os.environ['RCONNECT_B_FFDEC']) if os.environ.get('RCONNECT_B_FFDEC') else next(
    (p/'ffdec/ffdec-cli.jar' for p in (_OLD_TOOLS, _LOCAL_TOOLS) if (p/'ffdec/ffdec-cli.jar').is_file()), _OLD_TOOLS/'ffdec/ffdec-cli.jar')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


def inside_build(path):
    path = Path(path).resolve()
    if not path.is_relative_to(BUILD.resolve()) or path == BUILD.resolve():
        raise ValueError('Output must be a new directory below mods/RConnect/build/ab')
    return path


def verify_files(root, files):
    root = Path(root).resolve()
    for name, digest in files.items():
        target = (root/name).resolve()
        if not target.is_relative_to(root) or sha(target) != digest:
            raise ValueError('Changed or invalid input: '+name)


def verify_baseline(path):
    path = inside_build(path)
    data = read(path/'baseline.json')
    if data.get('kind') != 'host-authority-ab-baseline' or not data.get('experimental_only'):
        raise ValueError('Not an experimental A/B baseline')
    verify_files(path/'game', data['files'])
    return data
