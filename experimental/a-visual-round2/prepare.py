"""Integrate independent reviewed overlays into one owned candidate tree."""
from pathlib import Path
import shutil
HERE=Path(__file__).resolve().parent
BASE=HERE.parents[1]/'build/m52/a-stutter-repair-02/src'

def copytree_files(source,destination):
    for path in source.rglob('*.as'):
        dest=destination/path.relative_to(source)
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,dest)

def replace_one(s,old,new):
    assert s.count(old)==1,old
    return s.replace(old,new)

copytree_files(HERE.parent/'a-visual-round2-weapons/src',HERE/'src')
# Keep actor/impact time unchanged. The abandoned late-replay experiment is
# preserved in its original directory, but is not included in this candidate.
text=(BASE/'rconnect/game/ProjectileVisuals.as').read_text('utf8')
text=replace_one(text,'var s:Object=a.s,list:Array=s.frames as Array,time:Number=',
                 'var s:Object=a.s,time:Number=')
start=text.index('         if(list==null || list.length==0 || time<Number(list[0].at))return true;')
end=text.index('         var v:DisplayObject=a.vis as DisplayObject;',start)
text=text[:start]+'''         if(a.frameState==null)a.frameState={};
         var point:Object=ProjectilePlayback.sample(s,time,a.frameState);
         if(point==null)return true;
'''+text[end:]
start=text.index('         // Flight position is continuous')
end=text.index('         var laser:Object=GameBridge.probe(v,"laser");',start)
text=text[:start]+text[end:]
(HERE/'src/rconnect/game/ProjectileVisuals.as').write_text(text,encoding='utf8')
helper=(HERE.parent/'a-visual-round2-projectiles/src/rconnect/game/ProjectilePlayback.as').read_text('utf8')
start=helper.index('      /** Recover an unseen')
end=helper.index('      /** Only interpolate',start)
helper=helper[:start]+helper[end:]
(HERE/'src/rconnect/game/ProjectilePlayback.as').write_text(helper,encoding='utf8')
print('Weapon pose and confirmed projectile interpolation integrated; no late-replay clock.')
copytree_files(HERE.parent/'a-visual-round2-feedback/src',HERE/'src')
mod=(BASE/'RConnectMod.as').read_text('utf8').replace('0.2.24-animfix2','0.2.24-animfix3')
mod=replace_one(mod,'         game.enemyGrip = this.enemyGrip;',
                   '         game.enemyGrip = this.enemyGrip;\n         new rconnect.game.NativeTextVisuals(this);')
(HERE/'src/RConnectMod.as').write_text(mod,encoding='utf8')
grip=(BASE/'rconnect/core/EnemyGrip.as').read_text('utf8')
anchor='                  released.dx+=Number(kick.x);released.dy+=Number(kick.y);released.t_throw=45;'
grip=replace_one(grip,anchor,anchor+'\n                  rconnect.game.NativeTextVisuals.watchThrow(released,link);')
(HERE/'src/rconnect/core').mkdir(exist_ok=True)
(HERE/'src/rconnect/core/EnemyGrip.as').write_text(grip,encoding='utf8')
copytree_files(HERE.parents[1]/'tools/stubs',HERE/'stubs')
copytree_files(HERE.parent/'a-visual-round2-feedback/stubs',HERE/'stubs')
unit=(HERE/'stubs/fe/unit/Unit.as').read_text('utf8')
unit=replace_one(unit,'import fe.weapon.Bullet;','import fe.weapon.Bullet;\nimport fe.graph.Emitter;')
unit=replace_one(unit,'internal var hitPart:*;','internal var hitPart:*;\ninternal var numbEmit:Emitter;')
(HERE/'stubs/fe/unit/Unit.as').write_text(unit,encoding='utf8')
shutil.copyfile(HERE.parent/'a-visual-round2-feedback/FeedbackProbe.as',HERE/'FeedbackProbe.as')
print('Native feedback and compile-only external declarations integrated.')
