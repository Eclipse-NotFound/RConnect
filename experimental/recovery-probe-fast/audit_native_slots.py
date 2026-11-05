"""Minimal read-only SWF/ABC trait inspection. No decompiler or VM is started.

Only parses enough ABC to inspect instance inheritance and slot/accessor kind.
This is structural evidence, not a substitute for native execution.
"""
import hashlib
import json
from pathlib import Path
import struct
import zlib


class Reader:
    def __init__(self, data):
        self.data, self.at = data, 0

    def byte(self):
        value = self.data[self.at]
        self.at += 1
        return value

    def uint(self):
        result = 0
        for shift in range(0, 35, 7):
            value = self.byte()
            result |= (value & 127) << shift
            if value < 128:
                return result
        return result

    def take(self, n):
        assert 0 <= n <= len(self.data) - self.at
        value = self.data[self.at:self.at + n]
        self.at += n
        return value


def inspect_abc(data):
    r = Reader(data)
    r.take(4)  # ABC version
    for _ in range(2):
        for _ in range(max(0, r.uint() - 1)):
            r.uint()
    r.take(max(0, r.uint() - 1) * 8)
    strings = ['']
    for _ in range(max(0, r.uint() - 1)):
        strings.append(r.take(r.uint()).decode('utf-8'))
    namespaces = [(0, '')]
    for _ in range(max(0, r.uint() - 1)):
        namespaces.append((r.byte(), strings[r.uint()]))
    for _ in range(max(0, r.uint() - 1)):
        for _ in range(r.uint()):
            r.uint()
    names = [dict(name='*', namespace='', namespace_kind=0)]
    for _ in range(max(0, r.uint() - 1)):
        kind = r.byte()
        entry = dict(name='?', namespace='', namespace_kind=0)
        if kind in (0x07, 0x0D):
            ns = namespaces[r.uint()]
            entry = dict(name=strings[r.uint()], namespace=ns[1], namespace_kind=ns[0])
        elif kind in (0x0F, 0x10):
            entry['name'] = strings[r.uint()]
        elif kind in (0x11, 0x12):
            pass
        elif kind in (0x09, 0x0E):
            entry['name'] = strings[r.uint()]
            r.uint()
        elif kind in (0x1B, 0x1C):
            r.uint()
        elif kind == 0x1D:
            r.uint()
            for _ in range(r.uint()):
                r.uint()
        else:
            raise ValueError('Unknown multiname kind ' + hex(kind))
        names.append(entry)

    def qualified(index):
        n = names[index]
        return (n['namespace'] + '::' if n['namespace'] else '') + n['name']

    for _ in range(r.uint()):  # method signatures
        count = r.uint()
        r.uint()
        for _ in range(count):
            r.uint()
        r.uint()
        flags = r.byte()
        if flags & 8:
            for _ in range(r.uint()):
                r.uint()
                r.byte()
        if flags & 128:
            for _ in range(count):
                r.uint()
    for _ in range(r.uint()):  # metadata
        r.uint()
        count = r.uint()
        for _ in range(count * 2):
            r.uint()

    def traits():
        out = []
        for _ in range(r.uint()):
            n = names[r.uint()]
            flags = r.byte()
            kind = flags & 15
            entry = dict(n, kind=kind)
            if kind in (0, 6):
                entry['slot'] = r.uint()
                entry['type'] = qualified(r.uint())
                value = r.uint()
                if value:
                    r.byte()
            elif kind in (1, 2, 3, 4, 5):
                r.uint()
                r.uint()
            else:
                raise ValueError('Unknown trait kind ' + str(kind))
            if flags & 64:
                for _ in range(r.uint()):
                    r.uint()
            out.append(entry)
        return out

    instances = []
    for _ in range(r.uint()):
        name, parent, flags = qualified(r.uint()), qualified(r.uint()), r.byte()
        if flags & 8:
            r.uint()
        for _ in range(r.uint()):
            r.uint()
        r.uint()
        instances.append(dict(name=name, parent=parent, flags=flags, traits=traits()))
    return instances


def inspect_swf(path):
    blob = Path(path).read_bytes()
    if blob[:3] == b'CWS':
        body = zlib.decompress(blob[8:])
    else:
        assert blob[:3] == b'FWS', 'Unsupported SWF compression; no claim made'
        body = blob[8:]
    assert len(body) + 8 == struct.unpack_from('<I', blob, 4)[0]
    pos = (5 + 4 * (body[0] >> 3) + 7) // 8 + 4
    instances = []
    while pos < len(body):
        header = struct.unpack_from('<H', body, pos)[0]
        pos += 2
        kind, length = header >> 6, header & 63
        if length == 63:
            length = struct.unpack_from('<I', body, pos)[0]
            pos += 4
        payload = body[pos:pos + length]
        assert len(payload) == length
        pos += length
        if kind == 82:
            start = payload.index(b'\0', 4) + 1
            instances.extend(inspect_abc(payload[start:]))
        elif kind == 72:
            instances.extend(inspect_abc(payload))
        if kind == 0:
            break
    return hashlib.sha256(blob).hexdigest(), instances


def main():
    from prepare import GAME, HERE, WEAPON, BULLET
    path = GAME / 'pfe.swf'
    digest, classes = inspect_swf(path)
    result = dict(path=str(path), sha256=digest, classes={}, public_slots_verified=True,
                  JVM_started=False, AIR_started=False)
    parents = {'fe.weapon::Weapon':'fe::Obj', 'fe.weapon::Bullet':'fe::Obj',
               'fe::Obj':'fe::Pt', 'fe::Pt':'Object',
               'fe.weapon::PhisBullet':'fe.weapon::Bullet', 'fe.weapon::SmartBullet':'fe.weapon::Bullet'}
    for name, parent in parents.items():
        matches = [x for x in classes if x['name'] == name]
        assert len(matches) == 1, (name, len(matches))
        cls = matches[0]
        assert cls['parent'] == parent, (name, cls['parent'], parent)
        wanted = WEAPON if name == 'fe.weapon::Weapon' else BULLET if name == 'fe.weapon::Bullet' else []
        slots = {}
        for field in wanted:
            traits = [t for t in cls['traits'] if t['name'] == field and
                      t['namespace_kind'] == 0x16 and t['namespace'] == '']
            assert len(traits) == 1 and traits[0]['kind'] == 0, (name, field, traits)
            slots[field] = traits[0]
        result['classes'][name] = dict(parent=parent, flags=cls['flags'], slots=slots)
    (HERE / 'native-slots.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(swf_sha256=digest, verified_slots=len(WEAPON)+len(BULLET),
                         inheritance_links=len(parents), JVM_started=False, AIR_started=False)))


if __name__ == '__main__':
    main()
