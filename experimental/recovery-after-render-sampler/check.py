"""Static AS delta checks and explicit Python lifecycle model; not an AS runtime test."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
import sampler
from analyze import summarize


class WindowModel:
    """Counterexample model only; no native dispatch/sampler behavior is claimed."""
    def __init__(self):
        self.record = None
        self.rows = []
        self.counts = {}
        self.phase = 0
        self.number = 0

    def close(self, stop, reason='next-enter', collect_ms=0):
        if self.record is None:
            return
        row = self.record
        self.record = None
        row.update(stop=stop, pauseReturned=stop if row['sampled'] else 0,
                   collectStart=stop, collectEnd=stop+collect_ms, collectMs=collect_ms)
        row['complete'] = reason == 'next-enter' and row['phase'] == self.phase and row['renderAt'] > 0
        row['reason'] = 'next-enter' if row['complete'] else ('no-render' if reason == 'next-enter' and not row['renderAt'] else reason)
        self.rows.append(row)

    def enter(self, at, collect_ms=0):
        self.close(at, collect_ms=collect_ms)
        self.number += 1
        self.record = dict(phase=self.phase, frame=self.number, at=at, after=0, renderAt=0,
            startCallAt=0, start=0, stop=0, pauseReturned=0, selected=False, sampled=False,
            complete=False, reason='open', cpu=0, stacks={}, extraRenders=0,
            stackOverflow=0, depthTruncated=0, collectStart=0, collectEnd=0, collectMs=0)

    def render(self, after, rendered, started):
        row = self.record
        if row is None:
            return
        if row['renderAt']:
            row['extraRenders'] += 1
            return
        row.update(after=after, renderAt=rendered)
        selected = self.phase in (0, 1, 5, 6) and self.number % 5 == 1 and self.number < 30 and self.counts.get(self.phase, 0) < 6
        row['selected'] = selected
        if selected:
            self.counts[self.phase] = self.counts.get(self.phase, 0)+1
            row.update(startCallAt=rendered, start=started, sampled=True)

    def phase_end(self, stop, phase):
        self.close(stop, 'phase-change')
        self.phase, self.number = phase, 0

    def payload(self):
        return dict(schema=1, scope='stage-render-tail-to-next-stage-enter-entry',
                    counts=self.counts, droppedRows=0, frames=self.rows)


def main():
    here, root = sampler.HERE, sampler.ROOT
    inputs = sampler.read(here/'inputs.json')
    labels = []
    def check(ok, label):
        assert ok, label
        labels.append(label)
    for name, digest in inputs['dependencies'].items():
        check(sampler.sha(Path(name)) == digest, 'dependency '+str(Path(name).relative_to(root)))
    sampler.original.verify(sampler.SOURCE)
    for name, digest in inputs['tests'].items():
        check(sampler.sha(sampler.SOURCE/name) == digest, 'original source '+name)
    before = (sampler.SOURCE/'tests/SustainedDensityTestDoc.as').read_text('utf-8-sig')
    after = (here/'tests/SustainedDensityTestDoc.as').read_text('utf-8')
    edits = sampler.read(here/'as-edits.json')
    rebuilt = before
    for i, edit in enumerate(edits):
        check(rebuilt.count(edit['before']) == 1, 'unique AS diagnostic edit '+str(i+1))
        rebuilt = rebuilt.replace(edit['before'], edit['after'])
    check(rebuilt == after, 'only five declared diagnostic sites changed')
    for edit in reversed(edits):
        rebuilt = rebuilt.replace(edit['after'], edit['before'])
    check(rebuilt == before, 'removing diagnostic delta reproduces driver03 byte-for-byte text')
    check('Event.ENTER_FRAME,diagBegin,false,1000000' in after and 'Event.RENDER,diagEnd,false,-1000000' in after,
          'original stage boundaries preserved, no highest-priority RENDER expansion')
    methods = after[after.index('      private function diagBegin('):after.index('      public function SustainedDensityTestDoc(')]
    check(methods.index('if(wasSampling)pauseSampling();') < methods.index('for each(var sample:Sample in getSamples())'), 'pause precedes all sample enumeration')
    check('startSampling();\n         var started:int=getTimer();' in methods, 'start timestamp immediately after startSampling returns')
    check('var entered:int=getTimer();\n         diagClose(entered,"next-enter");' in methods, 'stop timestamp at next stage ENTER entry')
    check('sample is NewObjectSample || sample is DeleteObjectSample)continue;' in methods and 'created.type' not in methods,
          'allocation objects skipped with no retained object/type summaries')
    check('diagRows.length<4096' in methods and 'unique>=1024' in methods and 'names.length>=64' in methods,
          'timing rows, distinct stacks and stack depth bounded and truncation recorded')
    check('if(diagEnabled)diagClose(getTimer(),"phase-change");' in after and 'diagClose(getTimer(),"finish");' in after,
          'phase changes and finish close active windows explicitly')
    check('if(diagEnabled && phase=="load" && s!="load")diagClose' in after, 'load exit closes partial window')
    # The timed stimulus and criteria retain every original byte except one diagnostic close hook.
    for start, end in [('      private function tick(', '      private function nextPhase('), ('      private function frame(', None)]:
        def block(s):
            return s[s.index(start):] if end is None else s[s.index(start):s.index(end)]
        check(block(before) == block(after), 'non-diagnostic timed method unchanged '+start)
    model = WindowModel()
    model.enter(10); model.render(25, 30, 32); model.enter(320, collect_ms=40)
    row = model.rows[0]
    check(row['complete'] and row['stop']-row['start'] == 288 and row['collectMs'] == 40,
          'collection duration excluded from completed sample interval')
    check(model.record['at'] == 320 and row['collectEnd'] == 360, 'original next ENTER at retained before collection overhead')
    result = summarize(model.payload())
    check(result['timings'][0]['render_to_stop_ms'] == 290, 'render tail wall time reported independently')
    check(result['zero_cpu_does_not_prove_waiting'] and not result['valid_cpu_sample'], 'zero CPU samples do not prove sleep/wait')
    model = WindowModel(); model.enter(10); model.render(20, 30, 31); model.render(21, 40, 41)
    check(model.counts[0] == 1 and model.record['start'] == 31 and model.record['extraRenders'] == 1, 'repeated RENDER never restarts or expands sampling')
    model.phase_end(80, 1); model.enter(100); model.render(110, 120, 121); model.enter(150)
    check(not model.rows[0]['complete'] and model.rows[0]['reason'] == 'phase-change' and model.rows[0]['phase'] == 0,
          'old phase partial window retained as incomplete')
    check(model.rows[1]['complete'] and model.rows[1]['phase'] == 1 and model.rows[1]['start'] == 121,
          'new phase window does not splice old source timestamps')
    model = WindowModel(); model.enter(10); model.render(20, 30, 31); model.close(40, 'finish')
    check(not model.rows[0]['complete'] and model.record is None and model.rows[0]['stop'] == 40, 'finish stops active sampling with incomplete reason')
    model = WindowModel(); model.enter(10); model.enter(20)
    check(model.rows[0]['reason'] == 'no-render' and not model.rows[0]['sampled'], 'missing RENDER never borrows a later frame')
    model = WindowModel()
    for phase in range(7):
        model.phase_end(phase*10000, phase)
        for f in range(40):
            t=phase*10000+f*100+1
            model.enter(t); model.render(t+10, t+20, t+21)
        model.close(phase*10000+4001, 'phase-change')
    check(model.counts == {0:6, 1:6, 5:6, 6:6}, 'exactly at most six samples in each original selected phase')
    model.phase, model.number = 6, 0
    model.enter(80001); model.render(80011,80021,80022)
    check(model.counts[6] == 6 and not model.record['sampled'], 'frame counter reset cannot exceed phase budget')
    # Test the reader against contradictory recorded collection boundaries.
    one = WindowModel();one.enter(10);one.render(20,30,31);one.enter(50)
    bad = one.payload();bad['frames'][0]['collectStart'] = bad['frames'][0]['collectEnd'] = 49
    rejected = False
    try:summarize(bad)
    except AssertionError:rejected=True
    check(rejected, 'reader rejects collection beginning before pause returned')
    prior = root/'experimental/recovery-current-profile-sampler/run.py'
    expected = prior.read_text('utf-8')
    for edit in sampler.read(here/'run-edits.json'):
        assert expected.count(edit['before']) == 1
        expected = expected.replace(edit['before'],edit['after'])
    check(expected == (here/'run.py').read_text('utf-8'), 'run adapter retains original guards/audit except default new driver directory')
    for name in ('sampler.py','run.py','analyze.py','check.py'):
        compile((here/name).read_text('utf-8'),name,'exec');check(True,'Python syntax '+name)
    data = dict(assertions=len(labels),passed=len(labels),failed=0,labels=labels,
        static_and_python_model_only=True,as_runtime_verified=False,compiled=False,air_started=False,performance_qualified=False)
    sampler.save(here/'static-check.json',data)
    print(json.dumps({k:v for k,v in data.items() if k!='labels'}))


if __name__ == '__main__':
    main()
