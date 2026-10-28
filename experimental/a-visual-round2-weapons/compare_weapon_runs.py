"""Compare two real weapon-pose runs; write derived results only in this analysis dir."""
from pathlib import Path
import argparse
import hashlib
import json
import statistics
import analyze_weapon_pose as analysis

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]

def quantiles(values):
    if not values:
        return None
    ordered = sorted(values)
    return {'samples': len(values), 'mean': statistics.mean(values), 'median': statistics.median(values),
            'p95': ordered[min(len(ordered)-1, int(len(ordered)*.95))], 'max': max(values),
            'gt100': sum(x > 100 for x in values)}

def frame_gaps(data, active=False):
    rows = data['rows']
    if active:
        rows = [r for r in rows if 1200 <= r['age'] < 13000]
    return quantiles([b['at']-a['at'] for a, b in zip(rows, rows[1:])])

def flips(rows):
    rows = [r for r in rows if 1200 <= r['age'] < 13000]
    return [{'age': b['age'], 'at': b['at'], 'to_sign': analysis.signature(b['matrix'])}
            for a, b in zip(rows, rows[1:])
            if analysis.signature(a['matrix']) != analysis.signature(b['matrix'])]

def paired_flips(source, remote, offset):
    src, dst = flips(source), flips(remote)
    matches, missing, used = [], [], set()
    for index, event in enumerate(src):
        first = event['at'] + offset
        # Attribute a transition only within this source state's actual duration.
        end = src[index+1]['at'] + offset if index+1 < len(src) else source[-1]['at'] + offset
        choices = [(i, e) for i, e in enumerate(dst) if i not in used
                   and e['to_sign'] == event['to_sign'] and first <= e['at'] < end]
        if not choices:
            missing.append(event)
            continue
        i, observed = choices[0]
        used.add(i)
        matches.append({'source_age': event['age'], 'source_at': event['at'],
                        'remote_age': observed['age'], 'remote_at': observed['at'],
                        'to_sign': event['to_sign'], 'lag_ms_after_min_transit_calibration': observed['at']-first})
    return {'source_transitions': len(src), 'remote_transitions': len(dst),
            'matches': matches, 'missing_source_transitions': missing,
            'unpaired_remote_transitions': [e for i, e in enumerate(dst) if i not in used],
            'lag_ms': quantiles([m['lag_ms_after_min_transit_calibration'] for m in matches])}

def load(run_id):
    run = RC/'build/cooperation'/run_id
    files = {role: run/'logs'/role/'stutter-result.json' for role in ('host', 'join')}
    data = {role: json.loads(path.read_text(encoding='utf-8-sig')) for role, path in files.items()}
    result = analysis.analyze(data['host'], data['join'])
    result['run_id'] = run_id
    receipt = json.loads((run/'result.json').read_text(encoding='utf-8-sig'))
    result['profile'] = receipt.get('profile')
    frozen = json.loads((run/'input.json').read_text(encoding='utf-8-sig'))
    result['frozen_artifacts'] = {key: frozen.get(key) for key in ('candidate_sha256', 'driver_sha256', 'harness_sha256')}
    result['frozen_artifacts']['game_sha256'] = frozen.get('assets', {}).get('pfe.swf')
    resources = receipt.get('resource_before', {})
    result['environment_before'] = {'memory': resources.get('memory'), 'other_air': resources.get('air'),
                                    'qualification': 'coexist observation; not isolated performance ranking'}
    offsets = [p['at']-p['stamp'] for p in data['join']['wire'] if p.get('stream') == 'enemyMotion'
               and isinstance(p.get('stamp'), (int, float))]
    offset = min(offsets)
    result['clock_alignment'] = {
        'receiver_minus_source_min_ms': offset,
        'receiver_minus_source_median_ms': statistics.median(offsets),
        'samples': len(offsets),
        'boundary': 'Clock offset uses minimum real receive-at minus source-stamp. Reported lag excludes unknown minimum transit and source render scheduling; it is not exact one-way network latency.'}
    result['inputs'] = {role: {'path': str(path.resolve()), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                        for role, path in files.items()}
    result['frame_gaps_ms'] = {role: {'full': frame_gaps(trace), 'active': frame_gaps(trace, True)}
                              for role, trace in data.items()}
    for actor in result['actors']:
        actor['actual_reflection_transitions'] = paired_flips(analysis.actor_rows(data['host'], actor['id']),
                                                            analysis.actor_rows(data['join'], actor['id']), offset)
    return result

def number(n):
    return f'{n:.2f}' if isinstance(n, float) else str(n)

def report(old, new):
    lines = ['# 原生敌人武器显示：基线与候选实测对照', '',
             f'基线 `{old["run_id"]}`；候选 `{new["run_id"]}`。使用同一 driver02；两轮均为 `{new["profile"]}` 单轮。', '',
             '结论：候选消除了本夹具中的普通近战长时间定格，动画近战的重复已接近源端自身停留；六次左右翻转都收到。未证明整体性能提升，帧间隔有小幅增大且尾部结果混合。', '',
             '## 夹具与观察范围', '',
             '双方四种原生武器均有真实舞台样本；源执行原生 attack/step，加入侧仅由产品显示。比较窗为开始后 1.2–13 秒。只从最终 RENDER 的实际矩阵/帧号统计，不以 completed 判视觉正确。', '',
             '## 持续运动与根动画', '',
             '| 武器 | 基线源变化/重复 | 基线加入侧变化/重复 | 候选源变化/重复 | 候选加入侧变化/重复 | 加入侧最长重复：旧→新 |',
             '|---|---:|---:|---:|---:|---:|']
    for a, b in zip(old['actors'], new['actors']):
        def counts(r):
            return f'{r["native_or_remote_changed_frames"]}/{r["same_pose_frames"]}'
        lines.append(f'| {a["id"]} | {counts(a["source"])} | {counts(a["remote"])} | {counts(b["source"])} | {counts(b["remote"])} | {a["remote"]["longest_same_pose_ms"]}→{b["remote"]["longest_same_pose_ms"]} ms |')
    for label, result in [('基线', old), ('候选', new)]:
        laser = next(a for a in result['actors'] if a['id'] == 'weaponpose_laser')
        roots = [next(c for c in laser[r]['clip_frames'] if c['path'] == '')['changes'] for r in ('source', 'remote')]
        children = [sum(c['changes'] for c in laser[r]['clip_frames'] if c['path']) for r in ('source', 'remote')]
        lines.append(f'\n{label} ripper 根帧变化源/加入侧={roots[0]}/{roots[1]}；子帧变化={children[0]}/{children[1]}。')
    lines += ['', '旧版的子动画本就运行，异常主要在根姿态/挥砍历史停滞。候选不重写子时间线。自由/固定 LMG 本轮旧版也会翻转，不能把这轮结果写成“旧枪械完全不翻转”。', '',
              '## 实际翻转与延迟', '',
              '用真实接收包的最小“加入侧接收时刻－主侧源戳”校准两个进程时钟，再匹配同向的实际矩阵行列式符号变化。直接比较 age 会漏掉两轮不同的起跑握手时间。数值扣除了未知最小传输时间，另受源端最终绘制取样影响，不能叫精确网络延迟。', '',
              '| 武器 | 基线收到/源变化 | 候选收到/源变化 | 基线匹配延迟中位/最大 | 候选匹配延迟中位/最大 |',
              '|---|---:|---:|---:|---:|']
    for a, b in zip(old['actors'], new['actors']):
        x, y = a['actual_reflection_transitions'], b['actual_reflection_transitions']
        lines.append(f'| {a["id"]} | {len(x["matches"])}/{x["source_transitions"]} | {len(y["matches"])}/{y["source_transitions"]} | {number(x["lag_ms"]["median"])}/{number(x["lag_ms"]["max"])} ms | {number(y["lag_ms"]["median"])}/{number(y["lag_ms"]["max"])} ms |')
    lines += ['', '基线近战漏掉约6秒和8秒处的两次翻转；候选六次均匹配。完整配对原始时间、方向和漏失记录保留在JSON。', '',
              '## 绘制间隔', '', '| 活跃窗 | 基线均值/P95/最大 | 候选均值/P95/最大 | >100ms 旧→新 |', '|---|---:|---:|---:|']
    for role in ('host', 'join'):
        a, b = old['frame_gaps_ms'][role]['active'], new['frame_gaps_ms'][role]['active']
        lines.append(f'| {role} | {number(a["mean"])}/{a["p95"]}/{a["max"]} ms | {number(b["mean"])}/{b["p95"]}/{b["max"]} ms | {a["gt100"]}→{b["gt100"]} |')
    lines += ['', '候选主侧均值略增，加入侧均值与P95略增；加入侧最大间隔下降，超过100ms的次数增加。两轮启动前均记录到同样两个B版AIR进程，负载和调度未受严格控制，因此既不能认定稳定性能回退，也不能宣称性能无回退。证据支持本次四敌人的武器显示改善，不推广到全部敌人、密集战斗或全侧流畅。', '',
              'JSON同时保留完整时段间隔、实际夹具状态、矩阵拟合误差与原始文件SHA。拟合公共延迟只是观察量，不是读取了私有播放游标；未用拟合结果替代实际翻转匹配。', '']
    return '\n'.join(lines)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('baseline', nargs='?', default='fa76007751')
    parser.add_argument('candidate', nargs='?', default='b49865e3c1')
    args = parser.parse_args()
    old, new = load(args.baseline), load(args.candidate)
    output = HERE/'analysis'
    output.mkdir(exist_ok=True)
    stem = args.baseline+'-vs-'+args.candidate
    (output/(stem+'.json')).write_text(json.dumps({'baseline': old, 'candidate': new,
        'performance_qualification': False, 'scope': 'Same driver02, four native NPC weapon fixture, coexist single run each.'}, ensure_ascii=False, indent=2), encoding='utf-8')
    (output/(stem+'.md')).write_text(report(old, new), encoding='utf-8')
    print(str(output/(stem+'.md')))

if __name__ == '__main__':
    main()
