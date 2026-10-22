"""Read-only correction of first-change versus first-final-colour wording.

No old assertion, proof or result is changed. All matching is exact uint and
uses only pixels different from the corresponding pre-shot baseline. Source
matching is causal in observation time: no future source sample is consulted.
"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def read(p):
    return json.loads(Path(p).read_text(encoding='utf-8-sig'))


def changed(frame, channel, baseline):
    words = frame[channel]
    assert len(words) % 2 == 0
    result = {}
    previous = -1
    for i, value in zip(words[::2], words[1::2]):
        assert isinstance(i, int) and previous < i < len(baseline)
        assert isinstance(value, int) and 0 <= value <= 0xffffffff
        previous = i
        # Explicitly exclude unchanged baseline pixels, even if a future
        # fixture accidentally puts one into its purported sparse delta.
        if value != baseline[i]:
            result[i] = value
    return result


def observed(row, channel):
    baseline = row['baseline' if channel == 'native' else 'baselineDisplay']
    out = []
    last = None
    for ordinal, frame in enumerate(row['frames']):
        assert row['start'] <= frame['at'] <= row['end']
        assert last is None or frame['wall'] >= last
        last = frame['wall']
        out.append(dict(ordinal=ordinal, wall=frame['wall'], at=frame['at'],
                        cost=frame['cost'], pixels=changed(frame, channel, baseline)))
    return out


def first_summary(row, frames, predicate):
    for n, frame in enumerate(frames):
        if predicate(frame):
            before = frames[n-1]['wall'] if n else None
            return dict(ordinal=n, wall=frame['wall'], at=frame['at'],
                        capture_cost_ms=frame['cost'], changed_pixels=len(frame['pixels']),
                        preceding_sample_wall=before,
                        preceding_sample_gap_ms=None if before is None else frame['wall']-before,
                        prior_sample_count=n,
                        lower_bound_kind='previous RENDER sample' if n else 'unknown; no earlier RENDER sample')
    return None


def gaps(frames):
    values = [b['wall']-a['wall'] for a,b in zip(frames,frames[1:])]
    ordered = sorted(values)
    return dict(samples=len(frames), maximum_ms=max(values),
                p95_ms=ordered[min(len(ordered)-1,int(.95*(len(ordered)-1)))],
                over_100_ms=sum(x>100 for x in values),
                max_capture_ms=max(x['cost'] for x in frames))


def channel_result(source, remote, channel):
    sf, rf = observed(source, channel), observed(remote, channel)
    source_first = first_summary(source, sf, lambda f: bool(f['pixels']))
    remote_first = first_summary(remote, rf, lambda f: bool(f['pixels']))
    assert source_first and remote_first
    # History represents all actually observed prior changed colours at each
    # coordinate; latest represents the last source observation at that time.
    history, latest, si, found = {}, {}, 0, None
    for ri, frame in enumerate(rf):
        while si < len(sf) and sf[si]['wall'] <= frame['wall']:
            current = sf[si]
            for i, value in current['pixels'].items():
                history.setdefault((i,value), dict(wall=current['wall'], ordinal=si))
            latest = current['pixels']
            si += 1
        matches = [(i,value,history[i,value]) for i,value in frame['pixels'].items()
                   if (i,value) in history]
        if matches:
            found = first_summary(remote, rf, lambda x: x['ordinal'] == ri)
            found.update(exact_prior_source_matches=len(matches),
                         latest_observed_source_matches=sum(latest.get(i)==value for i,value,_ in matches),
                         eligible_source_samples=si,
                         latest_source_sample_wall=sf[si-1]['wall'],
                         examples=[dict(index=i,argb=f'{value:08x}',source_first_observed=entry['wall'],
                                        source_sample_ordinal=entry['ordinal']) for i,value,entry in matches[:4]])
            break
    assert found
    return dict(source_first_render_change=source_first, remote_first_render_change=remote_first,
                remote_first_prior_source_match=found,
                observed_first_change_difference_ms=remote_first['wall']-source_first['wall'],
                remote_first_change_minus_native_contact_end_ms=remote_first['wall']-source['sourceFirst'],
                observed_prior_match_difference_ms=found['wall']-source_first['wall'],
                source_observation_gaps=gaps(sf), remote_observation_gaps=gaps(rf))


def main():
    target = HERE/'analysis.json'
    assert not target.exists(), 'Never overwrite an earlier result'
    out = dict(purpose='correct metric names; not a new gameplay test or qualification',
               air_started=False, jvm_started=False, performance_qualified=False,
               original_results_preserved=True, rows=[], input_sha256={})
    for version in (16,18):
        evidence = ROOT/'build/m52'/f'recovery{version}-wall-surfaces-native-01'
        prior = ROOT/'experimental/recovery-wall-surfaces-native-proof-review'/(
            'candidate-reanalysis.json' if version==16 else 'recovery18-reanalysis-01.json')
        old = read(prior)
        assert len(old['rows']) == 4 and old['png_representation_compatible']
        # Bind and recheck all the prior review's original proof, PNG, log and
        # result inputs; no new compatibility or image tolerance is introduced.
        for name, digest in old['input_sha256'].items():
            assert sha(name)==digest, 'Prior evidence changed: '+name
            out['input_sha256'][name] = digest
        for p in [prior, evidence/'result.json', evidence/'wall-surface-result.json', Path(__file__)]:
            out['input_sha256'][str(p.resolve())] = sha(p)
        for n in range(4):
            role = 'host' if n%2==0 else 'join'
            other = 'join' if role=='host' else 'host'
            source = read(evidence/'wall-proof'/role/f'round-{n}-proof.json')
            remote = read(evidence/'wall-proof'/other/f'round-{n}-proof.json')
            assert source['source'] and not remote['source']
            assert source['baseline']==remote['baseline'] and source['baselineDisplay']==remote['baselineDisplay']
            assert source['area']==remote['area'] and source['target']==remote['target']
            original = old['rows'][n]
            assert original['round']==n
            out['rows'].append(dict(version=version,round=n,source=role,weapon=source['weapon'],
                candidate_sha256=old['candidate_sha256'], native_host_sha256=old['native_host_sha256'],
                original_metrics_unmodified=original,
                source_native_contact_interval=dict(before=source['sourceFirstBefore'],after=source['sourceFirst'],
                                                    width_ms=source['sourceFirst']-source['sourceFirstBefore']),
                native=channel_result(source,remote,'native'), display=channel_result(source,remote,'display')))
    assert all(sha(p)==digest for p,digest in out['input_sha256'].items())
    out['inputs_unchanged_after_analysis'] = True
    target.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for row in out['rows']:
        n=row['native'];o=row['original_metrics_unmodified']
        print(json.dumps(dict(version=row['version'],round=row['round'],
            contact_to_first_change=n['remote_first_change_minus_native_contact_end_ms'],
            render_to_first_change=n['observed_first_change_difference_ms'],
            first_final_color=o['native_first_delay_ms'],functional_pass=o['functional_pass'],
            first_change_bracket=n['remote_first_render_change']['preceding_sample_gap_ms'],
            maximum_gap=n['remote_observation_gaps']['maximum_ms']),ensure_ascii=False))


if __name__=='__main__':main()
