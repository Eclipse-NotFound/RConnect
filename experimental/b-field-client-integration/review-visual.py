"""Review retained native visual observations; does not run or change the game."""
from pathlib import Path
import hashlib, json

ROOT = Path(__file__).resolve().parents[2]
VIS = ROOT / 'build/ab/b-clientenv-visualfield-01'
MOTION = ROOT / 'build/ab/b-clientenv-textmotion-01'

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def clean(value):
    if isinstance(value, dict):
        return {k: clean(v) for k, v in value.items() if k != 'name'}
    if isinstance(value, list):
        return [clean(v) for v in value]
    return value

def main():
    pairs = read(VIS / 'visualfield-join-final.json')['pairs']
    stats = dict(presentations=len(pairs), box_pairs=0, tree_differences=0,
                 artwork_differences=0, backdrop_differences=0, count_differences=0,
                 shadow_order_or_count_errors=0, screen_patches=0,
                 screen_patch_differences=0, front_bitmap_differences=0,
                 back_bitmap_differences=0)
    for pair in pairs:
        host, join = pair['host'], pair['join']
        stats['count_differences'] += not (host['backCount'] == join['backCount'] == 63
                                          == len(host['backobjs']) == len(join['backobjs']))
        for a, b in zip(host['backobjs'], join['backobjs']):
            stats['backdrop_differences'] += (
                clean({k: a.get(k) for k in ('x', 'y', 'tree')}) !=
                clean({k: b.get(k) for k in ('x', 'y', 'tree')}))
        for key, a in host['objects'].items():
            if a['kind'] not in ('term', 'medbox'):
                continue
            b = join['objects'][key]
            stats['box_pairs'] += 1
            stats['tree_differences'] += clean(a['tree']) != clean(b['tree'])
            stats['artwork_differences'] += a['pixels'] != b['pixels']
            if pair['phase'] == 0 and not a['screen'].get('offscreen') and not b['screen'].get('offscreen'):
                stats['screen_patches'] += 1
                stats['screen_patch_differences'] += a['screen']['pixels'] != b['screen']['pixels']
            reference = a['hostShadow']
            for obj in (a, b):
                shadows = [s for s in obj['siblings']['items']
                           if s['cls'] == reference['cls'] and s['m'] == reference['m']
                           and any(f.get('hideObject') for f in s['filters'])]
                stats['shadow_order_or_count_errors'] += (
                    len(shadows) != 1 or shadows[0]['index'] >= obj['siblings']['targetIndex'])
        for key in ('front', 'back'):
            stats[key + '_bitmap_differences'] += host[key] != join[key]
    ack_files = [VIS / f'visualfield-{stage}-ack-{phase}.json'
                 for stage in ('birth', 'after') for phase in range(1, 5)]
    observations = [o for path in ack_files for o in read(path)['observations']]
    speech = dict(observations=len(observations), passed=all(o['passed'] for o in observations),
                  max_scale_error=max(abs(n - o['expected']) for o in observations for n in o['actual']))
    fields = ('samples', 'selfXStart', 'selfXEnd', 'missingText', 'textMax', 'rootMax',
              'unshakenCameraReversals', 'maxUnshakenCameraReverse', 'underflow', 'renderIntervalMaxMS')
    motion = {role: {name: {k: v.get(k) for k in fields}
                     for name, v in read(MOTION / f'{role}-text-motion-final.json')['phases'].items()}
              for role in ('host', 'join')}
    failures = ('tree_differences', 'artwork_differences', 'backdrop_differences',
                'count_differences', 'shadow_order_or_count_errors', 'screen_patch_differences')
    accepted = bool(pairs) and all(stats[k] == 0 for k in failures) and speech['passed'] and len(observations) == 16
    evidence = [VIS / 'result.json', VIS / 'visualfield-join-final.json',
                VIS / 'host-visualfield-0.png', VIS / 'join-visualfield-0.png',
                MOTION / 'result.json', MOTION / 'host-text-motion-final.json',
                MOTION / 'join-text-motion-final.json', *ack_files]
    report = dict(schema='b-clientenv-native-visual-review-1', accepted_for_component_scope=accepted,
                  candidate_sha256=read(VIS / 'result.json')['candidate_sha256'],
                  visual=stats, speech=speech, motion=motion,
                  screenshot_review='已亲自查看两侧 phase0：未遮挡部分的基地装饰、背景位置对应，医疗箱和终端未见黑影覆盖；主侧对话面板不同，不做整图相等判断。',
                  limitations=[
                      '整层 front/back 位图摘要仍不同，未据局部一致宣称整图逐像素一致。',
                      '运动文字与粒子位置误差不超过0.05像素且无缺失，但加入侧镜头仍有反向跳动；功能断言不代表无卡顿。',
                      '移动测试记录到加入侧静止阶段299毫秒间隔；未测输入到画面的端到端延迟。'],
                  files={str(p.relative_to(ROOT)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in evidence})
    destination = Path(__file__).with_name('visual-motion-review.json')
    if destination.exists():
        raise RuntimeError('Keep an existing review immutable')
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(dict(accepted_for_component_scope=accepted, visual=stats, speech=speech)))
    if not accepted:
        raise SystemExit(1)

if __name__ == '__main__':
    main()
