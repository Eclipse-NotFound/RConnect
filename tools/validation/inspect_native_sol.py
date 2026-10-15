"""Read a named native AMF3 SOL without opening the game or writing the save.

Only explicit files are read. Reports may be saved inside this RConnect repo.
Unsupported externalizable types fail closed; no application classes execute.
"""
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class AMF3:
    def __init__(self, data):
        self.data, self.pos = data, 0
        self.strings, self.objects, self.traits = [], [], []

    def take(self, count):
        if count < 0 or self.pos + count > len(self.data):
            raise ValueError(f'Truncated AMF3 at {self.pos}: {count}')
        result = self.data[self.pos:self.pos + count]
        self.pos += count
        return result

    def u8(self):
        return self.take(1)[0]

    def u29(self):
        value = 0
        for _ in range(3):
            b = self.u8()
            if b < 128:
                return (value << 7) | b
            value = (value << 7) | (b & 127)
        return (value << 8) | self.u8()

    def string(self):
        head = self.u29()
        if not head & 1:
            return self.strings[head >> 1]
        value = self.take(head >> 1).decode('utf-8')
        if value:
            self.strings.append(value)
        return value

    def value(self):
        tag = self.u8()
        if tag in (0, 1):
            return None
        if tag in (2, 3):
            return tag == 3
        if tag == 4:
            value = self.u29()
            return value - 0x20000000 if value & 0x10000000 else value
        if tag == 5:
            return struct.unpack('>d', self.take(8))[0]
        if tag == 6:
            return self.string()
        if tag in (7, 8, 11, 12):
            head = self.u29()
            if not head & 1:
                return self.objects[head >> 1]
            if tag == 8:
                result = {'$date_ms': struct.unpack('>d', self.take(8))[0]}
            elif tag == 12:
                value = self.take(head >> 1)
                result = {'$bytes': len(value), '$sha256': hashlib.sha256(value).hexdigest()}
            else:
                result = {'$xml': self.take(head >> 1).decode('utf-8')}
            self.objects.append(result)
            return result
        if tag == 9:
            head = self.u29()
            if not head & 1:
                return self.objects[head >> 1]
            result = {'$dense': []}
            self.objects.append(result)
            while True:
                key = self.string()
                if not key:
                    break
                result[key] = self.value()
            for _ in range(head >> 1):
                result['$dense'].append(self.value())
            return result
        if tag == 10:
            head = self.u29()
            if not head & 1:
                return self.objects[head >> 1]
            if not head & 2:
                trait = self.traits[head >> 2]
            else:
                external, dynamic, count = bool(head & 4), bool(head & 8), head >> 4
                name = self.string()
                trait = (external, dynamic, name, [self.string() for _ in range(count)])
                self.traits.append(trait)
            external, dynamic, name, keys = trait
            if external:
                raise ValueError(f'Externalizable class is not executed: {name}')
            result = {} if not name else {'$class': name}
            self.objects.append(result)
            for key in keys:
                result[key] = self.value()
            if dynamic:
                while True:
                    key = self.string()
                    if not key:
                        break
                    result[key] = self.value()
            return result
        if tag in (13, 14, 15, 16):
            head = self.u29()
            if not head & 1:
                return self.objects[head >> 1]
            result = {'$vector': tag, '$fixed': bool(self.u8()), '$dense': []}
            self.objects.append(result)
            if tag == 16:
                result['$type'] = self.string()
            for _ in range(head >> 1):
                result['$dense'].append(self.value() if tag == 16 else
                    struct.unpack({13: '>i', 14: '>I', 15: '>d'}[tag], self.take(8 if tag == 15 else 4))[0])
            return result
        if tag == 17:
            head = self.u29()
            if not head & 1:
                return self.objects[head >> 1]
            result = {'$dictionary': [], '$weak': bool(self.u8())}
            self.objects.append(result)
            for _ in range(head >> 1):
                result['$dictionary'].append([self.value(), self.value()])
            return result
        raise ValueError(f'Unsupported AMF3 marker {tag} at {self.pos - 1}')


def decode_sol(data):
    r = AMF3(data)
    if r.take(2) != b'\x00\xbf':
        raise ValueError('Not a SOL header')
    declared = struct.unpack('>I', r.take(4))[0]
    if declared != len(data) - 6 or r.take(10) != b'TCSO\x00\x04\x00\x00\x00\x00':
        raise ValueError('Unexpected SOL length/signature')
    name = r.take(struct.unpack('>H', r.take(2))[0]).decode('utf-8')
    version = struct.unpack('>I', r.take(4))[0]
    if version != 3:
        raise ValueError(f'Expected AMF3, found {version}')
    values = {}
    while r.pos < len(data):
        key = r.string()
        if not key:
            raise ValueError(f'Empty top-level SOL key at {r.pos}')
        values[key] = r.value()
        if r.u8() != 0:
            raise ValueError(f'Unexpected SOL property terminator at {r.pos}')
    return name, values


def scalars(value, path='', seen=None):
    seen = set() if seen is None else seen
    if isinstance(value, (dict, list)):
        if id(value) in seen:
            return
        seen.add(id(value))
        for key, child in (value.items() if isinstance(value, dict) else enumerate(value)):
            yield from scalars(child, f'{path}.{key}' if path else str(key), seen)
    else:
        yield path, value


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('files', nargs='+', type=Path)
    ap.add_argument('--output', type=Path)
    ap.add_argument('--brief', action='store_true', help='Omit section key lists')
    ap.add_argument('--match', default=r'^(pers\.(persName|level|manaHP|skills\.tele|perks\.(telethrow|telemaster))|n|date|ver)$')
    args = ap.parse_args()
    out = []
    pattern = re.compile(args.match, re.I)
    for path in args.files:
        path = path.resolve(strict=True)
        before = path.stat()
        data = path.read_bytes()
        name, values = decode_sol(data)
        after = path.stat()
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            raise RuntimeError('Save changed while reading; discard this observation: ' + str(path))
        summary = {p: v for p, v in scalars(values) if pattern.search(p)}
        record = dict(path=str(path),name=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest(),
            mtime_ns=before.st_mtime_ns,top_keys=list(values),
            section_keys={k: list(v) for k,v in values.items() if isinstance(v,dict)},selected=summary)
        if args.brief:
            del record['top_keys']
            del record['section_keys']
        out.append(record)
    text = json.dumps(out, ensure_ascii=False, indent=2, allow_nan=False)
    if args.output:
        output = args.output.resolve()
        if not output.is_relative_to(ROOT):
            raise ValueError('Analysis output must stay inside RConnect')
        if output.exists():
            raise FileExistsError('Keep prior observations: ' + str(output))
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text + '\n', encoding='utf-8')
    print(text)


if __name__ == '__main__':
    main()
