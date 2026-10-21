"""Scalar timing model for parameter review, not the AS component verdict."""
import json
from pathlib import Path
from prepare import trace

HERE=Path(__file__).resolve().parent
def clamp(x,a,b):return max(a,min(b,x))

class Clock:
    def __init__(self,new=False,cap=.5,accel=.003):
        self.new=new;self.cap=cap;self.accel=accel
        self.frames=[];self.gaps=[];self.offset=0;self.cursor=0;self.sampled=0;self.arrived=0
        self.debt=0;self.rate=1;self.active=False
    def delay(self):return min(250,max([100]+[g*1.25 for g in self.gaps]))
    def push(self,stamp,now):
        last=self.frames[-1] if self.frames else None;co=now-stamp
        if last is None or now-self.arrived>1000 or stamp-last>1000 or co<self.offset-250:
            self.frames=[];self.gaps=[];self.offset=co;self.cursor=stamp-self.delay();self.sampled=now
            self.debt=0;self.rate=1;self.active=False
        else:
            if stamp<=last:return
            previous=self.offset;self.offset=min(self.offset,co);correction=previous-self.offset
            if self.new:self.debt+=correction
            elif correction>100:self.cursor+=correction
            self.gaps.append(stamp-last);self.gaps=self.gaps[-8:]
        self.arrived=now;self.frames.append(stamp);self.frames=self.frames[-32:]
    def sample(self,now):
        dt=max(0,now-self.sampled);self.sampled=max(self.sampled,now)
        wanted=now-self.offset-self.delay();before=self.cursor;nxt=before+dt
        ordinary=nxt+clamp(wanted-nxt,-dt*.1,dt*.1)
        if self.new:
            if dt>0:self.debt=min(self.debt,max(0,wanted-nxt))
            if not self.active and self.debt>100:self.active=True
            if self.active and dt>0:
                ordinary_rate=(ordinary-before)/dt
                desired=max(ordinary_rate,1+min(self.cap,self.debt/200)) if self.debt>0 else ordinary_rate
                previous=self.rate;self.rate+=clamp(desired-self.rate,-dt*self.accel,dt*self.accel)
                self.cursor+=dt*(previous+self.rate)*.5
                if self.debt==0 and self.rate==ordinary_rate:self.active=False
            else:
                self.cursor=ordinary
                if dt>0:self.rate=(ordinary-before)/dt
        else:self.cursor=ordinary
        self.cursor=min(self.cursor,self.frames[-1])
        if self.new and dt>0:self.debt=max(0,self.debt-max(0,self.cursor-before-dt))
        while len(self.frames)>2 and self.frames[1]<=self.cursor:self.frames.pop(0)
        return wanted

def replay(cap=.5,accel=.003):
    t=trace();a=Clock();b=Clock(True,cap,accel);s=t['seed']
    for m in [a,b]:m.push(s['stamp'],s['now']);m.sample(s['sampleNow'])
    rows=[];max_old_error=0;old_first=None;new_first=None
    for i,r in enumerate(t['rows']):
        op,now,stamp,expected,offset,delay,latest,wanted,at=r
        before=b.cursor
        if op==1:
            max_old_error=max(max_old_error,abs(a.cursor-expected))
            a.push(stamp,now);b.push(stamp,now)
            rows.append({'index':i,'op':'push','at':at,'now':now,'old':a.cursor,'new':b.cursor,'delta':b.cursor-a.cursor,'debt':b.debt,'rate':b.rate})
        elif op==2:max_old_error=max(max_old_error,abs(a.cursor-expected))
        elif op==3:
            a.sample(now);b.sample(now);max_old_error=max(max_old_error,abs(a.cursor-expected))
            if old_first is None and a.cursor>=t['first_projectile_stamp']:old_first=at
            if new_first is None and b.cursor>=t['first_projectile_stamp']:new_first=at
            rows.append({'index':i,'op':'sample','at':at,'now':now,'old':a.cursor,'new':b.cursor,'delta':b.cursor-a.cursor,'debt':b.debt,'rate':b.rate})
    return {'model_only':True,'AS_executed':False,'cap':1+cap,'accel_per_ms':accel,'old_trace_max_abs_error':max_old_error,
        'old_first_eligible_at':old_first,'new_first_eligible_at':new_first,
        'eligible_gain_ms':old_first-new_first,'new_wait_after_real_frames_ms':new_first-t['first_real_frames_receive_at'],
        'rows':rows}

def main():
    comparisons=[replay(c,a) for c,a in [(.25,.003),(.5,.003),(.5,.002)]]
    assert all(x['old_trace_max_abs_error']<1e-7 for x in comparisons)
    selected=comparisons[1]
    (HERE/'model-replay.json').write_text(json.dumps({'selected':selected,'comparison':[{k:v for k,v in x.items() if k!='rows'} for x in comparisons]},indent=2)+'\n',encoding='utf-8')
    print(json.dumps([{k:v for k,v in x.items() if k!='rows'} for x in comparisons]))

if __name__=='__main__':main()
