"""Source-only proposal generator. No compiler, AIR, deployment or shared writes."""
from pathlib import Path
import difflib
import hashlib
import json

HERE = Path(__file__).resolve().parent
RC = HERE.parents[1]
BASE = RC / 'build/m52/recovery-04/src'


def replace_once(text, before, after):
    assert text.count(before) == 1, before
    return text.replace(before, after)


def main():
    inputs = {}
    diffs = []
    for name in ['UnitPresentation', 'ProjectileVisuals', 'ImpactEventQueue']:
        relative = f'rconnect/game/{name}.as'
        source = BASE / relative
        old = source.read_text(encoding='utf-8')
        new = old
        if name == 'UnitPresentation':
            new = replace_once(new,
                'if(flight==null && shot.impact!=null)packet.impact=shot.impact;',
                'if(flight==null && shot.impact!=null)packet.impact=shot.impact;\n'
                '               if(flight==null && shot.explosion!=null)packet.explosion=shot.explosion;')
            new = replace_once(new,
                'if(flight==null && shot.impact==null)continue;',
                'if(flight==null && shot.impact==null && shot.explosion==null)continue;')
            new = replace_once(new,
                'if(flight==null)packet.impact=shot.impact;',
                'if(flight==null && shot.impact!=null)packet.impact=shot.impact;\n'
                '               if(flight==null && shot.explosion!=null)packet.explosion=shot.explosion;')
        elif name == 'ProjectileVisuals':
            new = replace_once(new,
                '         if(!a.exploded&&s.explosion!=null&&time>=Number(s.explosion.at)) {\n'
                '            a.exploded=true;ProjectileExplosionVisuals.play(a.main,a.loc,s.explosion);\n'
                '         }\n',
                '         // Confirmed explosions share ImpactEventQueue with no-clip events.\n'
                '         // A repeated full packet or a late clip must not replay them here.\n')
        else:
            new = replace_once(new,
                'delete state.seen[String(state.order.shift().seq)];',
                'delete state.seen[String(state.order.shift().key)];')
            start = new.index('            var s:Object=event.impact')
            end = new.index('      public function tick(', start)
            new = new[:start] + '''            var hit:Object=event.impact!=null?event.impact:(event.flight==null?null:event.flight.impact);
            var explosion:Object=event.explosion!=null?event.explosion:(event.flight==null?null:event.flight.explosion);
            if(hit!=null && hit.groups is Array)
               enqueue(state,channel,event.seq,"hit",hit,loc,main,now);
            if(explosion!=null && isFinite(Number(explosion.x)) && isFinite(Number(explosion.y)))
               enqueue(state,channel,event.seq,"explosion",explosion,loc,main,now);
         }
      }
      private function enqueue(state:Object,channel:Object,seq:*,kind:String,s:Object,loc:Object,main:Object,now:int):void {
         if(!isFinite(Number(s.at)))return;
         // One shot may have both a ballistic impact and a real detonation.
         // Keep separate identities, but share the same bounded source clock.
         var key:String=kind+":"+String(seq);
         if(state.seen[key])return;
         state.seen[key]=true;state.order.push({key:key,at:now});
         // Matches recovery-detach's bounded channel retention. Its forget()
         // method must be preserved when this delta is merged on recovery05.
         pending.push({s:s,kind:kind,loc:loc,main:main,clock:state,received:now,channel:channel});
         if(pending.length>512)pending.shift();
      }
''' + new[end:]
            new = replace_once(new,
                'if(time-Number(a.s.at)<=15000)BallisticImpactVisuals.play(a.main,a.loc,a.s);',
                'if(time-Number(a.s.at)<=15000) {\n'
                '               if(a.kind=="explosion")ProjectileExplosionVisuals.play(a.main,a.loc,a.s);\n'
                '               else BallisticImpactVisuals.play(a.main,a.loc,a.s);\n'
                '            }')
        target = HERE / 'src' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(new, encoding='utf-8', newline='\n')
        inputs[relative] = {'base':str(source), 'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                           'overlay_sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
        diffs.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                        'recovery04/'+relative, 'special-impact/'+relative))
    (HERE / 'proposal.patch').write_text(''.join(diffs), encoding='utf-8')
    (HERE / 'inputs.json').write_text(json.dumps({'base':'build/m52/recovery-04/src',
        'files':inputs,'compiled':False,'native_tested':False,'deployed':False},ensure_ascii=False,indent=2),encoding='utf-8')
    fixtures = RC / 'experimental/recovery-motion-checks/tests'
    for source in fixtures.rglob('*.as'):
        if source.name in ['CaptureEffectsChecks.as','ProjectileExplosionVisuals.as','BurnVisuals.as']:
            continue
        target = HERE / 'tests' / source.relative_to(fixtures)
        target.parent.mkdir(parents=True,exist_ok=True)
        if source.name == 'EnergyImpactVisuals.as':
            value = replace_once(source.read_text(encoding='utf-8'),
                '      public function reset():void {}',
                '      public function forget(channel:Object,now:int):void {}\n'
                '      public function reset():void {}')
            target.write_text(value,encoding='utf-8',newline='\n')
        else:
            target.write_bytes(source.read_bytes())


if __name__ == '__main__':
    main()
