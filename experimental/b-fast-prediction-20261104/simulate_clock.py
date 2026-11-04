"""Algorithm model of authority/PlaybackClock.take for the fast1 change.

Not an AS3 execution: this mirrors the two implementations line by line so the
published contract checks in ContractChecks.playbackCadence can be re-evaluated
offline. Numbers here are the model's, not game measurements.
"""
import math

SNAP_MS = 400.0
CATCHUP = 0.25


class Old:
    """position = max(position, target); every ready frame consumed."""

    def __init__(self, min_delay=65.0, max_delay=250.0):
        self.delay = min_delay
        self.min_delay = min_delay
        self.max_delay = max_delay
        self.position = 0.0
        self.current = None
        self.next = None
        self.queued = 0
        self.underflows = 0
        self.pending = []
        self.offset = float('nan')
        self.last = None
        self.intervals = []
        self.jitter = []

    def _pace(self, frame, estimate, boundary):
        if boundary:
            self.intervals = []
            self.jitter = []
            return
        if self.last is None or self.last.get('paused') or frame.get('paused'):
            return
        interval = frame['time'] - self.last['time']
        if interval <= 0 or interval > 1000:
            return
        self.intervals.append(interval)
        self.jitter.append(max(0.0, estimate - self.offset))
        if len(self.intervals) > 32:
            self.intervals.pop(0)
            self.jitter.pop(0)
        if len(self.intervals) < 4:
            return
        gaps = sorted(self.intervals)
        late = sorted(self.jitter)
        wanted = max(self.min_delay, min(self.max_delay,
                     gaps[int((len(gaps) - 1) * .9)] + late[int((len(late) - 1) * .9)] + 15))
        self.delay = wanted if wanted > self.delay else max(wanted, self.delay - 2)

    def push(self, frame, now):
        if self.last is not None and frame['time'] < self.last['time']:
            raise ValueError('backwards')
        boundary = (self.last is None or frame['room'] != self.last['room']
                    or frame.get('pauseEpoch') != self.last.get('pauseEpoch'))
        estimate = now - frame['time']
        if math.isnan(self.offset) or estimate < self.offset:
            self.offset = estimate
        self._pace(frame, estimate, boundary)
        self.pending.append(frame)
        self.last = frame
        self.queued = len(self.pending)
        return boundary

    def take(self, now, flush=False, maxFrames=0):
        out = []
        if self.last is None:
            return out
        target = self.last['time'] if flush else min(self.last['time'], now - self.offset - self.delay)
        self.position = max(self.position, target)
        while self.pending and (self.current is None or self.pending[0]['time'] <= self.position):
            self.current = self.pending.pop(0)
            out.append(self.current)
        self.next = self.pending[0] if self.pending else None
        self.queued = len(self.pending)
        if self.next is None and not self.last.get('paused'):
            self.underflows += 1
        return out


class New(Old):
    """Rate-limited catch-up plus optional per-frame budget."""

    def __init__(self, min_delay=65.0, max_delay=250.0):
        super().__init__(min_delay, max_delay)
        self.last_at = float('nan')
        self.stalls = 0
        self.throttled = 0
        self.applied = 0

    def take(self, now, flush=False, maxFrames=0):
        out = []
        if self.last is None:
            return out
        dt = 0.0 if math.isnan(self.last_at) else max(0.0, min(120.0, now - self.last_at))
        self.last_at = now
        if flush:
            self.position = self.last['time']
        elif self.current is None:
            if self.pending:
                self.position = max(self.position, self.pending[0]['time'])
        else:
            target = min(self.last['time'], now - self.offset - self.delay)
            error = target - self.position
            if error > SNAP_MS:
                self.position = target
                self.stalls += 1
            elif error > 0:
                self.position = min(target, self.position + dt + min(error, dt * CATCHUP))
        taken = 0
        while self.pending and (self.current is None or self.pending[0]['time'] <= self.position):
            if maxFrames > 0 and taken >= maxFrames:
                break
            self.current = self.pending.pop(0)
            out.append(self.current)
            taken += 1
        self.applied += taken
        if maxFrames > 0 and self.pending and taken > 0:
            held = out[-1]
            if self.position > held['time']:
                self.position = held['time']
                self.throttled += 1
        self.next = self.pending[0] if self.pending else None
        self.queued = len(self.pending)
        if self.next is None and not self.last.get('paused'):
            self.underflows += 1
        return out


def cadence(clock_cls):
    clock = clock_cls()
    sent = 0
    empty = 0
    observed = 0
    jitter = [0, 24, 48, 8, 16, 40]
    previous = -1.0
    ordered = True
    bounded = True
    boundary = False
    for now in range(1000, 8200, 16):
        while sent < 60 and 1000 + sent * 120 + jitter[sent % len(jitter)] <= now:
            frame = {'time': sent * 120, 'room': 'dense', 'pauseEpoch': 0, 'paused': False}
            boundary = clock.push(frame, 1000 + sent * 120 + jitter[sent % len(jitter)])
            if boundary:
                clock.take(now, True)
            sent += 1
        clock.take(now)
        if 2400 < now < 7800:
            observed += 1
            if clock.next is None:
                empty += 1
            ordered = ordered and clock.position >= previous
            previous = clock.position
            bounded = bounded and clock.queued < 8 and clock.current is not None \
                and clock.position <= (sent - 1) * 120
    stop = {'time': 7200, 'room': 'dense', 'pauseEpoch': 1, 'paused': True}
    boundary = clock.push(stop, 8300)
    clock.take(8300, boundary)
    pause_ok = (boundary and clock.current is stop and clock.fraction() == 0 and clock.queued == 0)
    for i in range(160):
        frame = {'time': 7233 + i * 33, 'room': 'dense', 'pauseEpoch': 2, 'paused': False}
        boundary = clock.push(frame, 8233 + i * 33)
        clock.take(8233 + i * 33, boundary)
    return dict(observed=observed, empty=empty, ordered=ordered, bounded=bounded,
                pause_ok=pause_ok, delay=clock.delay, underflows=clock.underflows,
                empty_ratio=empty / observed if observed else 1.0)


# fraction() must exist on both models for the pause assertion above.
def _fraction(self):
    if self.current is None or self.next is None or self.next['time'] <= self.current['time'] \
            or self.current.get('paused'):
        return 0.0
    return max(0.0, min(1.0, (self.position - self.current['time']) / (self.next['time'] - self.current['time'])))


Old.fraction = _fraction
New.fraction = _fraction

for name, cls in (('old', Old), ('new', New)):
    r = cadence(cls)
    ok = (r['observed'] > 300 and r['empty_ratio'] < .05 and r['ordered'] and r['bounded']
          and r['pause_ok'] and r['delay'] == 65)
    print(f"{name}: pass={ok} observed={r['observed']} empty={r['empty']} empty_ratio={r['empty_ratio']:.4f} "
          f"ordered={r['ordered']} bounded={r['bounded']} pause_ok={r['pause_ok']} delay={r['delay']} "
          f"underflows={r['underflows']}")
