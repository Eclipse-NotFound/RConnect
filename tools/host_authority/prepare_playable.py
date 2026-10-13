"""Prepare a separate B manual-play pair; never replace A or installed game files.

The two launchers share immutable game assets, but have distinct stable AIR
profiles. Players use the native menu to create/load their own B character,
then host/join from the compact overlay. This tool does not launch anything.
"""
import argparse
import json
import shutil
import uuid
from common import ROOT, inside_build, read, save, sha, verify_baseline, verify_files


def main():
    ap = argparse.ArgumentParser()
    for name in ('baseline', 'candidate', 'native', 'tdfc', 'output'):
        ap.add_argument('--'+name, required=True)
    ap.add_argument('--rv', required=True, help='Frozen independent RV authority interface')
    ap.add_argument('--msw', required=True, help='Frozen independent MSW authority interface')
    ap.add_argument('--sandy', required=True, help='Frozen independent shared-time interface; required for manual B play')
    args = ap.parse_args()
    baseline, candidate, native, tactics, out = [inside_build(ROOT/getattr(args, name))
        for name in ('baseline', 'candidate', 'native', 'tdfc', 'output')]
    b = verify_baseline(baseline)
    mod, patch, tdfc = read(candidate/'build-input.json'), read(native/'native-input.json'), read(tactics/'build-input.json')
    for directory, manifest, artifact in ((candidate, mod, 'RConnectMod.swf'), (native, patch, 'pfe.swf'), (tactics, tdfc, 'TDFCMod.swf')):
        verify_files(directory, manifest['sources'])
        if sha(directory/artifact) != manifest['candidate_sha256']:
            raise ValueError('Frozen artifact changed: '+str(directory))
    if mod['native_capability'] != patch['capability'] or patch['baseline_manifest_sha256'] != sha(baseline/'baseline.json'):
        raise ValueError('Mismatched native build or baseline')
    if not tdfc['experimental_only'] or tdfc['family'] != 'tdfc-authority-v1':
        raise ValueError('TDFC is not the isolated authority interface candidate')
    extensions = {}
    for key, directory_name, artifact in (('rv', 'RealisticVision', 'RealisticVisionMod.swf'),
                                          ('msw', 'MoreSkills&Weapons', 'MoreSkillsWeaponsMod.swf'),
                                          ('sandy', 'Sandevistan', 'SandevistanMod.swf')):
        option = getattr(args, key)
        if not option:
            continue
        directory = inside_build(ROOT/option)
        manifest = read(directory/'build-input.json')
        if not manifest.get('experimental_only') or manifest.get('family') != key+'-authority-v1':
            raise ValueError('Not an independent '+key+' authority candidate')
        verify_files(directory, manifest['sources'])
        if sha(directory/artifact) != manifest['candidate_sha256']:
            raise ValueError('Frozen '+key+' artifact changed')
        extensions[key] = dict(path=directory, directory=directory_name, artifact=artifact, manifest=manifest)
    if out.exists():
        raise FileExistsError('A manual candidate must use a new directory')
    out.mkdir(parents=True)
    game = out/'game'
    shutil.copytree(baseline/'game', game)
    replacements = {'pfe.swf': native/'pfe.swf', 'mods/Rconnect/release/RConnectMod.swf': candidate/'RConnectMod.swf',
                    'mods/TDFC/release/TDFCMod.swf': tactics/'TDFCMod.swf'}
    for entry in extensions.values():
        replacements['mods/'+entry['directory']+'/release/'+entry['artifact']] = entry['path']/entry['artifact']
    for target, source in replacements.items():
        shutil.copy2(source, game/target)
    configuration = dict(experimental=True, session=uuid.uuid4().hex, role='', autoGame=False, probe=False,
                         port=23457, hostIp='127.0.0.1', tdfc=tdfc['candidate_sha256'])
    for key, entry in extensions.items():
        configuration[key] = entry['manifest']['candidate_sha256']
    save(game/'mods/Rconnect/release/config.txt', configuration)
    expected = dict(b['files'])
    changed = {name.lower() for name in replacements} | {'mods/rconnect/release/config.txt'}
    for name in expected:
        if name.lower() in changed:
            expected[name] = sha(game/name)
    verify_files(game, expected)
    launchers = []
    for number in (1, 2):
        appid = 'pfe-modsettings-rconnect-b-player-'+str(number)
        descriptor = game/('player-'+str(number)+'.xml')
        descriptor.write_text('<?xml version="1.0" encoding="utf-8"?>\n'
            '<application xmlns="http://ns.adobe.com/air/application/30.0">'
            '<id>'+appid+'</id><versionNumber>1.0</versionNumber><filename>RConnect B Player '+str(number)+'</filename>'
            '<initialWindow><content>pfe.swf</content><visible>true</visible><width>1000</width><height>650</height></initialWindow>'
            '</application>', encoding='utf-8')
        launcher = out/('Player-'+str(number)+'.cmd')
        launcher.write_bytes(('@echo off\r\npushd "%~dp0game"\r\nstart "" "adl64.exe" -runtime "runtimes\\air\\win64" "'+descriptor.name+'" -nodebug\r\npopd\r\n').encode('ascii'))
        launchers.append(dict(appid=appid, descriptor=descriptor.relative_to(out).as_posix(),
                              descriptor_sha256=sha(descriptor), launcher=launcher.name, launcher_sha256=sha(launcher)))
    (out/'README.txt').write_text('RConnect B 独立实验版 · '+candidate.name+'\n'
        '源码指纹：'+mod['source_id']+'\n\n'
        '1. 打开 Player-1.cmd 和 Player-2.cmd。两者分别保存自己的角色。\n'
        '2. 各自在原版菜单中新建或载入自己的 B 角色，进入游戏。\n'
        '3. 展开浮窗的“连接”：一侧创建房间，另一侧加入。地址127.0.0.1，端口23457。\n'
        '4. 设置、跟随、念力许可和队友伤害都在浮窗中；F10显隐，Ctrl+Enter聊天。\n'
        '5. 测试结束请各自保存角色并退出。加入侧离开联机会回到自己的原版旅程。\n\n'
        '两个启动器不限定谁当宿主；先进入游戏，再选择创建或加入。\n'
        '不同 B 候选共用这两份 B 角色。更新候选前请退出两个旧 B 窗口，再启动新目录。\n'
        'A 的角色与存档独立保留；请不要手动覆盖到 B 的存档目录。\n\n'
        '联机时停由任一侧发动，两人正常行动、世界减速；结束回放时结算已记录的主要伤害。\n'
        '共享暂停会同时冻结回放。宿主在时停中发起换图，要等回放与结算完成。\n\n'
        'A 安装版、原版存档和启动方式保持独立。本目录只用于 B 实验；不能把这里的 SWF 单独复制回安装目录。\n'
        '这份准备脚本不代表完整验收通过，实际门禁以随候选交付的验证记录为准。\n', encoding='utf-8')
    save(out/'manual-input.json', dict(experimental_only=True, launched=False, release_gate_complete=False,
        script_sha256=sha(__file__), source_id=mod['source_id'], candidate_sha256=mod['candidate_sha256'],
        readme_sha256=sha(out/'README.txt'),
        baseline_manifest_sha256=sha(baseline/'baseline.json'), candidate_manifest_sha256=sha(candidate/'build-input.json'),
        native_manifest_sha256=sha(native/'native-input.json'), tdfc_manifest_sha256=sha(tactics/'build-input.json'),
        extension_manifests={key:sha(entry['path']/'build-input.json') for key,entry in extensions.items()},
        files=expected, config=configuration, launchers=launchers))
    print(json.dumps(dict(prepared=str(out), launched=False, release_gate_complete=False), ensure_ascii=False))


if __name__ == '__main__':
    main()
