"""Assemble recovery19 source only from exact18 plus the passed Base64 overlay.
No compiler, AIR, deployment or copied binary artifacts. Refuses to overwrite.
"""
from pathlib import Path
import hashlib,json,statistics
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-18';PROPOSAL=ROOT/'experimental/recovery-wall-base64'
RUN=ROOT/'build/m52/recovery-wall-base64-component-01'
REVIEW=ROOT/'experimental/recovery-wall-base64-runtime-review'
CODEC='rconnect/net/WallCellCodec.as';VERSION='0.2.24-recovery19'
PIN='11b795d0d6681caa4edfcc2d1c0df73cb38f6d706a1fb3c26518163f738fe4d3'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def save(p,data):p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(p):return {q.relative_to(p).as_posix():sha(q) for q in sorted(p.rglob('*.as'))}
def main():
    assert not (HERE/'src').exists() and not (HERE/'integration.json').exists()
    assert not REVIEW.exists()
    meta=read(BASE/'prepared.json');before=inventory(BASE/'src')
    assert meta['compiled'] and meta['sha256']==PIN and meta['source']==before and len(before)==90
    handoff=read(PROPOSAL/'handoff.json')
    assert all(sha(PROPOSAL/p)==h for p,h in handoff['files'].items())
    rec,intent,result=[read(RUN/n) for n in ('receipt.json','intent.json','component-result.json')]
    assert rec['passed'] and rec['compiled'] and rec['air_started'] and rec['exit_code']==0
    assert rec['observed_checks']==63 and rec['checks_failed']==0 and rec['installation_unchanged'] and rec['source_unchanged']
    assert result['passed'] and result['failed']==0 and len(result['assertions'])==63
    assert all(x['passed'] for x in result['assertions'])
    current={p.relative_to(PROPOSAL/'components').as_posix():sha(p) for p in (PROPOSAL/'components').rglob('*') if p.is_file()}
    frozen={p.relative_to(RUN/'src').as_posix():sha(p) for p in (RUN/'src').rglob('*') if p.is_file()}
    assert current==frozen==intent['sources']
    assert sha(PROPOSAL/'src'/CODEC)==sha(RUN/'src'/CODEC)
    blocks=result['measurements']['abba']['blocks'];assert len(blocks)==24
    for i,r in enumerate(blocks):
        assert r['block']==i and r['side']==['old','new','new','old'][i%4]
        assert r['calls']==246 and r['chars']==743736 and r['checksum']==19128
        assert r['coldDecode']['calls']==246 and r['coldDecode']['words']==297180 and r['coldDecode']['checksum']==2240691086
    inputs={str(p):sha(p) for p in (Path(__file__),BASE/'prepared.json',BASE/'integration.json',PROPOSAL/'handoff.json',PROPOSAL/'inputs.json',
      PROPOSAL/'src'/CODEC,RUN/'intent.json',RUN/'receipt.json',RUN/'component-result.json')}
    for name in before:
        source=PROPOSAL/'src'/name if name==CODEC else BASE/'src'/name
        inputs[str(source)]=sha(source);data=source.read_bytes()
        if name=='RConnectMod.as':
            old=b'"0.2.24-recovery18"';new=b'"0.2.24-recovery19"'
            assert data.count(old)==1;data=data.replace(old,new,1)
        p=HERE/'src'/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    after=inventory(HERE/'src');assert set(after)==set(before)
    changes={n for n in before if before[n]!=after[n]};assert changes=={CODEC,'RConnectMod.as'}
    assert all(sha(Path(p))==h for p,h in inputs.items()) and inventory(BASE/'src')==before
    integration={'version':VERSION,'baseline':'build/m52/recovery-18','baseline_sha256':PIN,
      'baseline_manifest_sha256':sha(BASE/'prepared.json'),'ancestor_integration_sha256':sha(BASE/'integration.json'),
      'input_sources':inputs,'source':[{'path':p,'sha256':h} for p,h in after.items()],
      'static_errors':[],'changed':sorted(changes),'added':[],'unchanged_class_count':88,
      'functional_delta':[CODEC],'version_only':['RConnectMod.as'],'complete_class_count':90,
      'component':{'run':'build/m52/recovery-wall-base64-component-01','checks':63,'failed':0,
        'artifact_sha256_from_runner':rec['component_sha256'],'receipt_sha256':sha(RUN/'receipt.json'),
        'assertions_sha256':sha(RUN/'component-result.json'),'frozen_component_sources_match':True},
      'compiled':False,'native_game_tested':False,'performance_qualified':False,'installed':False,
      'diagnostic_only':True,'next_comparison':'same frozen density driver02/runner and thresholds, ordinary corridor, installed BEFC host, recovery18 then19; not large-surface/early-loading qualification'}
    save(HERE/'integration.json',integration)
    def summary(side,field):
        values=[r['ms'] if field=='pack' else r['coldDecode']['ms'] for r in blocks if r['side']==side]
        return {'blocks':len(values),'min_ms':min(values),'max_ms':max(values),'sum_ms':sum(values),'mean_ms':statistics.mean(values),'median_ms':statistics.median(values)}
    summaries={s:{k:summary(s,k) for k in ('pack','cold_decode')} for s in ('old','new')}
    groups=[]
    for i in range(0,24,4):
        a,b,c,d=blocks[i:i+4];old=(a['ms']+d['ms'])/2;new=(b['ms']+c['ms'])/2
        groups.append({'group':i//4+1,'blocks':[i,i+1,i+2,i+3],'old_mean_ms':old,'new_mean_ms':new,'reduction_percent':(old-new)/old*100})
    old=summaries['old']['pack']['mean_ms'];new=summaries['new']['pack']['mean_ms']
    REVIEW.mkdir()
    analysis={'run':str(RUN.relative_to(ROOT)),'formal_receipt':rec,'receipt_sha256':sha(RUN/'receipt.json'),
      'component_result_sha256':sha(RUN/'component-result.json'),'all_24_blocks':blocks,'summaries':summaries,'paired_ABBA_groups':groups,
      'pack_mean_reduction_percent':(old-new)/old*100,'pack_ms_saved_per_call_on_this_corpus':(old-new)/246,
      'component_assertions':result['assertions'],'native_game_tested':False,'performance_qualified':False,
      'encoding_bytes_unchanged':True,'cold_decode_code_unchanged':True,'corpus_is_current_dense_encode_distribution':False,
      'next_comparison':integration['next_comparison'],'integration_sha256':sha(HERE/'integration.json')}
    save(REVIEW/'runtime-analysis.json',analysis)
    table='\n'.join(f"| {r['block']} | {r['side']} | {r['ms']} | {r['coldDecode']['ms']} |" for r in blocks)
    paired='\n'.join(f"| {r['group']} | {r['old_mean_ms']:.1f} | {r['new_mean_ms']:.1f} | {r['reduction_percent']:.2f}% |" for r in groups)
    report=f'''# Base64 输出候选：实际组件结果

准确来源：recovery18（{PIN}）加唯一 WallCellCodec 覆盖。实际运行 `build/m52/recovery-wall-base64-component-01`，63/0；产物指纹来自正式 runner 回执 `{rec['component_sha256']}`。回执记录来源及22项安装输入不变。原提案 handoff 和原始结果均未修改。

完整编码路径的24块均已核对。旧12块范围是 **502–578 ms**（不是509起），均值 **{old:.3f} ms**；新12块362–432 ms，均值 **{new:.3f} ms**。均值下降 **{(old-new)/old*100:.2f}%**，本数据集每次编码平均少 **{(old-new)/246:.3f} ms**。六组配对均下降，全部块都保留如下；这只是本组件完整 packed 路径的结果，不能换算为整机或游戏帧率提升。

每块246次（82份×3），均743736字符、checksum19128。计时包含校验、排序、原生zlib、Base64和外壳；构造输入和文件在计时外。冷解码每块246次、297180个words、checksum2240691086，代码没有改；其时间变化不登记为解码优化。

| 块 | 路径 | 完整编码 ms | 冷解码 ms |
|---:|---|---:|---:|
{table}

| ABBA组 | 旧两块均值 ms | 新两块均值 ms | 编码减少 |
|---:|---:|---:|---:|
{paired}

全部统计与原始断言绑定见 `runtime-analysis.json`。63项通过包括原49项完整墙痕语义及14项字节/填充/边界检查。历史82份数据来自decode miss，不能代表当前密集开火的编码频次、分布或缓存命中率；这是一次ABBA运行，未测多进程整体收益、长期内存或实际画面。

`../recovery-wall-base64-buildsrc/integration.json` 已组装 recovery19，仍未编译。总90类不变：唯一功能差异为codec，另RConnectMod只改版本，其他88类逐字相同。候选没有混入普通房颜色、early旅行或其它尚未合并修正。

下一步由主会话保持同一冻结 driver02、原 density runner、全部原门槛和 **BEFC安装宿主的普通走廊**，先18后19作单变量整体对照；不是ACC，也不提供合并大图墙面、early加载、部署资格。组件与组装均保持 performance_qualified=false。
'''
    (REVIEW/'runtime-review.md').write_text(report,encoding='utf-8')
    print(json.dumps({'classes':90,'byte_identical_classes':88,'changed':sorted(changes),'component_checks':63,'component_failed':0,
      'pack_old_mean_ms':old,'pack_new_mean_ms':new,'reduction_percent':(old-new)/old*100,'integration_sha256':sha(HERE/'integration.json'),
      'compiled':False,'JVM_AIR_started':False}))
if __name__=='__main__':main()
