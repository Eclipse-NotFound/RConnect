"""Freeze verified source and update this A milestone without rewriting B history."""
import json,shutil
from build import HERE,RC,sha,inventory,save
out=RC/'build/m52/visual2-combined-04'
proof=json.loads((out/'release-qualification.json').read_text('utf8'))
receipt=RC/'build/m52/visual2-deploy-5c955c7f/deployment.json'
deployment=json.loads(receipt.read_text('utf8'))
assert deployment['status']=='verified' and sha(RC/'release/RConnectMod.swf')==proof['candidate_sha256']
assert not (HERE/'validated-src').exists()
shutil.copytree(out/'src',HERE/'validated-src')
assert inventory(HERE/'validated-src')==proof['source']
assert inventory(HERE/'stubs')==inventory(out/'stubs')
save(HERE/'validated-manifest.json',dict(source=proof['source'],stubs=inventory(out/'stubs'),
 swf_sha256=proof['candidate_sha256'],version='0.2.24-animfix3',build='build/m52/visual2-combined-04',
 source_base='F14A / animfix2',qualification_sha256=sha(out/'release-qualification.json')))
(HERE/'evidence').mkdir(exist_ok=True)
for path in [out/'compile.json',out/'prepared.json',out/'class-audit.json',out/'release-qualification.json',receipt]:
 shutil.copyfile(path,HERE/'evidence'/path.name)

memory=RC/'state/MEMORY.md';text=memory.read_text('utf8')
anchor='**10月28日当前主线与交付**：'
assert text.count(anchor)==1
latest='''**10月28日晚最新A交付（animfix3）**：用户六项视觉反馈已做窄修并部署 `0.2.24-animfix3` / `eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127`。准确全源 `build/m52/visual2-combined-04/src`，Git全源副本 `experimental/a-visual-round2/validated-src`；回执 `build/m52/visual2-deploy-5c955c7f/deployment.json` verified，旧F14A备份同目录。门开关误碎片、话语缺失、抛掷原生数字、敌人武器翻转/近战停顿已获对应实证；特殊弹已收轨迹内平滑，火焰重复343/454→0，近战翻转6/6、高频历史减至2–4帧。**普通枪弹仍伴随整帧停顿，coexist时序混合，不能声称全部卡顿或性能无回退。** 只改RC，宿主/配置/存档和B不改。自有测试均结束，运行副本已清理。详细六项状态、失败记录、验证复用与遗留见 `state/a-visual-feedback-repair-2026-10-28.md`。双方需重启。

**10月28日前一轮A交付（animfix2，已由上述版本替代）**：'''
text=text.replace(anchor,latest,1)
old='正式RC：`0.2.24-animfix2`，SHA `f14a44e74ac98ec480875203d4d714acfbc496141980e5a1d7b0de0c7ad222fb`。'
assert text.count(old)==1
text=text.replace(old,'正式RC：`0.2.24-animfix3`，SHA `eb6d11e6f20068f76d44d180bc5f579c14ba359caa46e4706d0506b0d4abc127`。旧F14A备份见本轮visual2-deploy-5c955c7f回执。',1)
text=text.replace('本轮验证边界：driver02早期input','上一轮animfix2验证边界：driver02早期input',1)
memory.write_text(text,encoding='utf8')
journal=RC/'state/journal.md';previous=journal.read_text('utf8')
entry='''## 2026-10-28 A 六项视觉反馈窄修，animfix3已部署

- 已部署EB6D11…ABC127，准确全源visual2-combined-04；Git完整快照experimental/a-visual-round2/validated-src。回执visual2-deploy-5c955c7f verified，旧F14A备份保留，宿主/配置/玩家存档/B不改。
- 原生门/窗测试确认假碎片旧12/24→0、真实碎片两侧仍24；话语、提前取消、重复包及普通67/累计65→127数字的真实文字/颜色/帧一致。近战原先最长2702ms定格，最终四种武器6/6翻转，普通近战重复0、动画近战6（源12）；高频历史实机减至2–4帧，419,546个真实游标等价检查。
- 火焰飞行非原生停留重复主343/加454→0；闪电仅7发窄证据。独立迟到补播会与枪口/命中逆序，已撤回未部署。普通枪弹仍有整帧停顿，coexist性能结果混合，不能宣称完全修复或无性能回退；这也是后续优先停点。
- 最终字节武器2e24094452通过，85类审计通过；仅两处近战窗口改动，复用03门737e1ba68c、反馈02364cdc46、弹道a7a84ad6d5的未变路径证据。原始失败、分析边界和输入指纹保留，不以completed代替效果。详情state/a-visual-feedback-repair-2026-10-28.md。

'''
assert 'A 六项视觉反馈窄修，animfix3已部署' not in previous
journal.write_text(entry+previous,encoding='utf8')
print(json.dumps({'source_files':len(proof['source']),'installed_sha256':sha(RC/'release/RConnectMod.swf'),'memory_lines':len(text.splitlines())}))
