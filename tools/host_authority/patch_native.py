"""Add opt-in native scheduling/input seams to an isolated, pinned game copy.

Callbacks default to null. Native behavior remains the fallback for A. This
does not change the installation, loader, map generator, assets or class list.
"""
import argparse
import difflib
import re
import struct
import subprocess
import zlib
from common import ROOT, JAVA, FFDEC, inside_build, verify_baseline, sha, save


def once(source, before, after):
    if source.count(before) != 1:
        raise ValueError('Native anchor absent or ambiguous: '+before[:100])
    return source.replace(before, after, 1)


def modify_base(name, source):
    if 'RCONNECT_AUTHORITY_HOOKS' in source:
        raise ValueError('Refuse to patch an already patched native class')
    if name == 'fe.graph.Grafon':
        source = once(source, '      public function Grafon(param1:Sprite)',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b2-v1";\n\n'
            '      public function Grafon(param1:Sprite, sharedResources:Grafon = null)')
        return once(source, '         this.grLoaders = new Array();',
            '         if(sharedResources != null)\n         {\n'
            '            this.grLoaders = sharedResources.grLoaders;\n'
            '            this.checkLoaded(0);\n'
            '            this.resIsLoad = sharedResources.resIsLoad;\n'
            '            return;\n         }\n         this.grLoaders = new Array();')
    if name == 'fe.unit.Unit':
        anchor = '      public function findCel(param1:Boolean = false) : Boolean\n      {'
        return once(source, anchor,
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectFindTarget:Function = null;\n'
            '      private static var rconnectFinding:Boolean = false;\n\n'+anchor+'\n'
            '         if(rconnectFindTarget != null && !rconnectFinding)\n         {\n'
            '            rconnectFinding = true;\n            try\n            {\n'
            '               return Boolean(rconnectFindTarget(this,param1));\n            }\n'
            '            finally\n            {\n               rconnectFinding = false;\n            }\n         }')
    if name == 'fe.inter.Ctr':
        source = once(source, '      public function Ctr(param1:* = null)',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n\n'
            '      public function Ctr(param1:* = null, bindStage:Boolean = true)')
        first = '         World.w.swfStage.addEventListener(MouseEvent.MIDDLE_MOUSE_DOWN,this.onMiddleMouseDown1);'
        last = '         World.w.swfStage.addEventListener(KeyboardEvent.KEY_UP,this.onKeyboardUpEvent);'
        source = once(source, first, '         if(bindStage)\n         {\n'+first)
        return once(source, last, last+'\n         }')
    if name == 'fe.loc.Location':
        source = once(source, '      public var land:Land;',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectPlayerStep:Function = null;\n'
            '      public static var rconnectObjectStep:Function = null;\n\n      public var land:Land;')
        source = once(source, '         this.gg.step();',
            '         if(rconnectPlayerStep != null)\n         {\n            rconnectPlayerStep(this);\n         }\n'
            '         else\n         {\n            this.gg.step();\n         }')
        if source.count('               obj.step();') != 2:
            raise ValueError('Expected active and invisible object step anchors')
        return source.replace('               obj.step();',
            '               if(rconnectObjectStep != null)\n               {\n                  rconnectObjectStep(this,obj);\n               }\n'
            '               else\n               {\n                  obj.step();\n               }')
    if name == 'fe.loc.Land':
        source = once(source, '      public var loc:Location;',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectRoomStep:Function = null;\n'
            '      public static var rconnectGotoRoom:Function = null;\n\n      public var loc:Location;')
        anchor = '      public function gotoLoc(param1:int, param2:Number = -1, param3:Number = -1) : Object\n      {'
        source = once(source, anchor, anchor+'\n'
            '         if(rconnectGotoRoom != null)\n         {\n'
            '            return rconnectGotoRoom(this,param1,param2,param3);\n         }')
        block = '''            this.loc.step();
            if(this.loc_t > 0)
            {
               --this.loc_t;
               if(Boolean(this.prevloc) && this.loc != this.prevloc)
               {
                  this.prevloc.stepInvis();
               }
            }'''
        return once(source, block,
            '            if(rconnectRoomStep != null)\n            {\n               if(rconnectRoomStep(this) === false) return;\n            }\n'
            '            else\n            {\n'+block+'\n            }')
    if name == 'fe.unit.UnitPlayer':
        source = once(source, '      override public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number\n      {',
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b1-v3";\n'
            '      public static var rconnectDamage:Function = null;\n\n'
            '      override public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number\n      {\n'
            '         if(rconnectDamage != null && World.w.gg != this)\n         {\n'
            '            return Number(rconnectDamage(this,param1,param2,param3,param4));\n         }')
        return source
    raise ValueError(name)


INTENTS = {
    'fe.unit.UnitPlayer': ('changeWeapon', 'changeArmor', 'changeSpell', 'armorAbil', 'callPet', 'uncallPet'),
    'fe.unit.Invent': ('useItem', 'usePotion', 'favItem', 'respectWeapon', 'drop', 'nextItem'),
    'fe.unit.Pers': ('addSkill', 'addPerk'),
    'fe.weapon.Weapon': ('initReload',),
    'fe.loc.Game': ('gotoLand', 'beginMission', 'gotoNextLevel'),
}

MENU_CLASSES = ['fe.inter.PipBuck','fe.inter.PipPageWork','fe.inter.PipPageVault','fe.inter.PipPageMed',
    'fe.inter.PipPageVend','fe.inter.PipPageInv','fe.inter.PipPageApp','fe.inter.Stand']

# These overrides mutate armor, shields or special boss state before calling
# Unit.damage. Intercept at the outer entry, before any native side effects.
DAMAGE_CLASSES = ['fe.unit.UnitAIRobot','fe.unit.UnitAlicorn','fe.unit.UnitBossNecr',
    'fe.unit.UnitBossRaider','fe.unit.UnitPhoenix','fe.unit.UnitRaider',
    'fe.unit.UnitTurret','fe.unit.UnitZebra','fe.unit.VirtualUnit']


def menu_hook(source, method, key, args, condition='true'):
    pattern = r'      (?:override )?(?:public|internal) function '+method+r'\([^\n]*\) : [^\n]+\n      \{'
    matches = list(re.finditer(pattern, source))
    if len(matches) != 1:
        raise ValueError('Menu anchor absent or ambiguous: '+method)
    end = matches[0].end()
    hook = ('\n         if('+condition+' && PipBuck.rconnectMenu != null && '
        'Boolean(PipBuck.rconnectMenu(this,"'+key+'",['+args+'])))\n'
        '         {\n            return;\n         }')
    return source[:end]+hook+source[end:]


def modify(name, source):
    original = source
    core = ('fe.inter.Ctr','fe.loc.Location','fe.loc.Land','fe.unit.Unit','fe.unit.UnitPlayer','fe.graph.Grafon')
    if name in core:
        source = modify_base(name, source)
    else:
        constructor = '      public function '+name.split('.')[-1]+'('
        source = once(source, constructor,
            '      public static const RCONNECT_AUTHORITY_HOOKS:String = "b3-v1";\n\n'+constructor)
    if name=='fe.graph.Grafon':
        source=once(source,'      public function Grafon(param1:Sprite, sharedResources:Grafon = null)',
            '      public static var rconnectInk:Function = null;\n\n'
            '      public function rconnectSurface(layer:String):BitmapData\n      {\n'
            '         return layer == "front" ? this.frontBmp : layer == "back" ? this.backBmp : null;\n      }\n\n'
            '      public function Grafon(param1:Sprite, sharedResources:Grafon = null)')
        source=once(source,'         this.drawAllObjs();\n         World.w.gr_stage = 0;',
            '         this.drawAllObjs();\n         World.w.gr_stage = 0;\n'
            '         if(rconnectInk != null) rconnectInk(this,"reset",null);')
        anchor='            this.frontBmp.copyChannel(_loc12_,_loc15_,_loc16_,BitmapDataChannel.GREEN,BitmapDataChannel.ALPHA);\n         }'
        source=once(source,anchor,anchor+'\n         if(rconnectInk != null)\n         {\n'
            '            rconnectInk(this,"front",this.frontBmp,null,_loc8_,this.m);\n'
            '            rconnectInk(this,"front",this.frontBmp,null,_loc9_,this.m);\n         }')
        source=once(source,'         this.frontBmp.draw(_loc4_,_loc3_);',
            '         this.frontBmp.draw(_loc4_,_loc3_);\n'
            '         if(rconnectInk != null) rconnectInk(this,"front",this.frontBmp,null,_loc4_,_loc3_);')
        anchor='         this.backBmp.copyChannel(this.brData,this.brRect,this.brPoint,BitmapDataChannel.GREEN,BitmapDataChannel.ALPHA);'
        source=once(source,anchor,anchor+'\n'
            '         if(rconnectInk != null) rconnectInk(this,"back",this.backBmp,new Rectangle(_loc11_,_loc13_,_loc12_-_loc11_,_loc14_-_loc13_));')
    if name in INTENTS:
        constructor = '      public function '+name.split('.')[-1]+'('
        source = once(source, constructor, '      public static var rconnectIntent:Function = null;\n\n'+constructor)
        for method in INTENTS[name]:
            pattern = r'      public function '+method+r'\(([^\n]*)\) : ([^\n]+)\n      \{'
            matches = list(re.finditer(pattern,source))
            if len(matches)!=1:
                raise ValueError('Intent anchor absent or ambiguous: '+name+'.'+method)
            match=matches[0]
            args = re.findall(r'(param\d+)\s*:',match.group(1))
            result = match.group(2).strip()
            return_value = 'false' if result=='Boolean' else '0' if result in ('int','uint','Number') else ''
            statement = ('\n         if(rconnectIntent != null && Boolean(rconnectIntent(this,"'+method+'",['+','.join(args)+'])))\n'
                '         {\n            return'+(' '+return_value if return_value else '')+';\n         }')
            source = source[:match.end()]+statement+source[match.end():]
    if name=='fe.unit.UnitPlayer':
        # UnitPet.call hard-codes the single-player roster's slot 1. Preserve
        # every real combatant when this native player is under B scheduling.
        if source.count('               this.pet.call();') != 1 or source.count('            this.pet.call();') != 2:
            raise ValueError('Native pet call anchors changed')
        source = source.replace('this.pet.call();', 'this.rconnectCallPet();')
        source = once(source, '      public function callPet(param1:String, param2:Boolean = false) : *',
            '      private function rconnectCallPet() : void\n      {\n'
            '         var roster:Array = Location.rconnectPlayerStep == null || loc == null ? null : loc.units.concat();\n'
            '         this.pet.call();\n'
            '         if(roster != null)\n         {\n'
            '            if(roster.indexOf(this.pet) < 0) roster.push(this.pet);\n'
            '            loc.units = roster;\n         }\n      }\n\n'
            '      public function callPet(param1:String, param2:Boolean = false) : *')
        anchor='         if(this.pers.hardcore && param1 >= 0)'
        source=once(source,anchor,'         if(rconnectDeath != null && Boolean(rconnectDeath(this,param1)))\n'
            '         {\n            return;\n         }\n'+anchor)
        source=once(source,'      public static var rconnectDamage:Function = null;',
            '      public static var rconnectDamage:Function = null;\n      public static var rconnectDeath:Function = null;')
    if name=='fe.World':
        source=once(source,'      public function newGame(param1:int = -1, param2:String = "LP", param3:Object = null) : *\n      {',
            '      public static var rconnectChangeWorld:Function = null;\n\n'
            '      public function newGame(param1:int = -1, param2:String = "LP", param3:Object = null) : *\n      {\n'
            '         if(rconnectChangeWorld != null) rconnectChangeWorld();')
        anchor='      public function loadGame(param1:int = 0) : *\n      {'
        source=once(source,anchor,anchor+'\n         if(rconnectChangeWorld != null) rconnectChangeWorld();')
        anchor='      public function saveGame(param1:int = -1) : *\n      {'
        source=once(source,anchor,'      public static var rconnectSave:Function = null;\n\n'+anchor+'\n'
            '         if(rconnectSave != null && Boolean(rconnectSave(this,param1)))\n         {\n            return;\n         }')
    if name=='fe.loc.Land':
        source=once(source,'      public var act:LandAct;',
            '      public static var rconnectSeedSource:Function = null;\n'
            '      public var rconnectLayoutSeed:uint = 0;\n'
            '      public static var rconnectGotoChallenge:Function = null;\n\n      public var act:LandAct;')
        source=once(source,'            rndDeterm(rndSeedFor(this.act.id));',
            '            this.rconnectLayoutSeed = rconnectSeedSource == null ? rndSeedFor(this.act.id) : uint(rconnectSeedSource(this));\n'
            '            rndDeterm(this.rconnectLayoutSeed);\n'
            '            this.rconnectLayoutSeed = _rndSeed;')
        anchor='      public function gotoProb(param1:String = "", param2:Number = -1, param3:Number = -1) : *\n      {'
        source=once(source,anchor,anchor+'\n'
            '         if(rconnectGotoChallenge != null && Boolean(rconnectGotoChallenge(this,param1,param2,param3)))\n'
            '         {\n            return;\n         }')
    if name=='fe.unit.Unit':
        anchor='      public static var rconnectFindTarget:Function = null;'
        source=once(source,anchor,anchor+'\n      public static var rconnectDeferDamage:Function = null;\n'
            '      public static var rconnectHitPolicy:Function = null;\n'
            '      public static var rconnectTeleported:Function = null;\n'
            '      public static function rconnectAllowed(source:Unit, target:Unit, nativeAllowed:Boolean, kind:String = "impact"):Boolean\n'
            '      {\n         return rconnectHitPolicy == null ? nativeAllowed : Boolean(rconnectHitPolicy(source,target,nativeAllowed,kind));\n      }')
        anchor='            Emitter.emit("teleport",loc,X,Y - scY / 2);\n         }'
        source=once(source,anchor,anchor+'\n         if(rconnectTeleported != null) rconnectTeleported(this);')
    if name=='fe.weapon.Bullet':
        source=once(source,'(this.targetObj || _loc2_.fraction != this.owner.fraction)',
            '(Unit.rconnectAllowed(this.owner,_loc2_,Boolean(this.targetObj || _loc2_.fraction != this.owner.fraction)))')
        for local in ('_loc1_','_loc3_'):
            anchor='         for each('+local+' in loc.units)\n         {'
            source=once(source,anchor,anchor+'\n            if(!Unit.rconnectAllowed(this.owner,'+local+',true,"explosion")) continue;')
        source=once(source,'Boolean(this.weap.owner.fraction == Unit.F_PLAYER) && _loc1_.player',
            'Boolean(this.weap.owner.fraction == Unit.F_PLAYER) && _loc1_.player && (Unit.rconnectHitPolicy == null || this.weap.owner == _loc1_)')
        source=once(source,'if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER)',
            'if(Boolean(this.weap) && this.weap.owner.fraction == Unit.F_PLAYER && (Unit.rconnectHitPolicy == null || this.weap.owner == _loc3_))')
    if name=='fe.weapon.PhisBullet':
        source=once(source,'_loc1_.fraction != owner.fraction',
            'Unit.rconnectAllowed(owner,_loc1_,_loc1_.fraction != owner.fraction,"sensor")')
    if name=='fe.unit.Mine':
        source=once(source,'      public var explRadius:Number = 0;',
            '      public var rconnectOwner:Unit = null;\n      public static var rconnectMineSight:Function = null;\n\n'
            '      public var explRadius:Number = 0;')
        source=once(source,'|| _loc1_.fraction == fraction || _loc1_.fraction == 0',
            '|| !Unit.rconnectAllowed(this,_loc1_,_loc1_.fraction != fraction && _loc1_.fraction != 0,"mine")')
        source=once(source,'isVis = World.w.gg.lookInvis(this);',
            'isVis = rconnectMineSight == null ? World.w.gg.lookInvis(this) : Boolean(rconnectMineSight(this));')
        source=once(source,'                              World.w.gg.bindChain(X,Y);',
            '                              if(Unit.rconnectHitPolicy == null) World.w.gg.bindChain(X,Y);\n'
            '                              else (_loc1_ as UnitPlayer).bindChain(X,Y);')
    if name=='fe.weapon.WThrow':
        source=once(source,'            _loc5_.fraction = owner.fraction;',
            '            _loc5_.rconnectOwner = owner;\n            _loc5_.fraction = owner.fraction;')
    if name=='fe.inter.PipBuck':
        source=once(source,'      public function PipBuck(',
            '      public static var rconnectMenu:Function = null;\n\n      public function PipBuck(')
        source=once(source,'         World.w.ctr.keyPressed = false;\n      }\n      \n      public function resizeScreen',
            '         World.w.ctr.keyPressed = false;\n'
            '         if(!this.active && rconnectMenu != null) rconnectMenu(this,"menuClose",[]);\n'
            '      }\n      \n      public function resizeScreen')
    if name=='fe.inter.PipPageWork':
        source=menu_hook(source,'itemClick','menuWork','page2,String(param1.currentTarget.id.text),pip.workTip')
    if name=='fe.inter.PipPageVault':
        source=menu_hook(source,'chKol','menuVault','page2,String(param1.id.text),param2')
        source=menu_hook(source,'sbrosHlam','menuVaultAll','page2')
    if name=='fe.inter.PipPageMed':
        source=menu_hook(source,'itemClick','menuMedical','page2,String(param1.currentTarget.id.text)')
    if name=='fe.inter.PipPageVend':
        source=menu_hook(source,'itemClick','menuRepair','page2,String(param1.currentTarget.id.text)','page2 == 3')
        source=menu_hook(source,'itemClick','menuQuest','page2,String(param1.currentTarget.id.text)','page2 == 4')
        source=menu_hook(source,'trade','menuVendor','1')
        source=menu_hook(source,'sell','menuVendor','2')
    if name=='fe.inter.PipPageInv':
        source=menu_hook(source,'itemClick','menuAmmo','page2,String(param1.currentTarget.id.text)','page2 == 5')
    if name=='fe.inter.PipPageApp':
        source=menu_hook(source,'funVidOk','menuAppearance','')
    if name=='fe.inter.Stand':
        source=once(source,'         }\n      }\n      \n      public function resizeScreen',
            '         }\n         if(!this.active && PipBuck.rconnectMenu != null) PipBuck.rconnectMenu(this,"menuStandClose",[]);\n'
            '      }\n      \n      public function resizeScreen')
    if name == 'fe.Snd':
        source = once(source, '      public static function combatMusic(param1:String, param2:int = 0, param3:int = 150) : *',
            '      public static var rconnectCombatMusic:Function = null;\n'
            '      public static var rconnectPlayMusic:Function = null;\n'
            '      public static function combatMusic(id:String, priority:int = 0, duration:int = 150) : *\n'
            '      {\n         if(rconnectCombatMusic != null) return rconnectCombatMusic(id,priority,duration);\n'
            '         return rconnectNativeCombatMusic(id,priority,duration);\n      }\n'
            '      public static function rconnectNativeCombatMusic(param1:String, param2:int = 0, param3:int = 150) : *')
        source = once(source, '      public static function playMusic(param1:String = null, param2:int = 10000) : *',
            '      public static function playMusic(id:String = null, repeats:int = 10000) : *\n'
            '      {\n         if(rconnectPlayMusic != null) return rconnectPlayMusic(id,repeats);\n'
            '         return rconnectNativeMusic(id,repeats);\n      }\n'
            '      public static function rconnectNativeMusic(param1:String = null, param2:int = 10000) : *')
        source = once(source, '         if(t_combat > 0)\n         {\n            if(t_combat == 1)',
            '         if(t_combat > 0 && rconnectCombatMusic == null)\n         {\n            if(t_combat == 1)')
        source = once(source, '      public static function ps(param1:String, param2:Number = -1000, param3:Number = -1000, param4:Number = 0, param5:Number = 1) : SoundChannel',
            '      public static var rconnectPlaySound:Function = null;\n'
            '      public static var rconnectHumSound:Function = null;\n'
            '      public static var rconnectStopSound:Function = null;\n'
            '      public static function ps(id:String, x:Number = -1000, y:Number = -1000, start:Number = 0, volume:Number = 1) : SoundChannel\n'
            '      {\n         if(rconnectPlaySound != null) return rconnectPlaySound(id,x,y,start,volume) as SoundChannel;\n'
            '         return rconnectNativeSound(id,x,y,start,volume);\n      }\n'
            '      public static function rconnectStopChannel(channel:SoundChannel) : void\n'
            '      {\n         if(rconnectStopSound != null) rconnectStopSound(channel);\n         channel.stop();\n      }\n'
            '      public static function rconnectNativeSound(param1:String, param2:Number = -1000, param3:Number = -1000, param4:Number = 0, param5:Number = 1) : SoundChannel')
        source = once(source, '      public static function pshum(param1:String, param2:Number = 1) : *',
            '      public static function pshum(id:String, volume:Number = 1) : *\n'
            '      {\n         if(rconnectHumSound != null) return rconnectHumSound(id,volume);\n'
            '         return rconnectNativeHum(id,volume);\n      }\n'
            '      public static function rconnectNativeHum(param1:String, param2:Number = 1) : *')
    if name in ('fe.weapon.Weapon', 'fe.weapon.WClub', 'fe.serv.Interact'):
        channel = {'fe.weapon.Weapon':'this.sndCh','fe.weapon.WClub':'sndCh','fe.serv.Interact':'this.moveCh'}[name]
        expected = 1 if name == 'fe.serv.Interact' else 2
        if source.count(channel+'.stop();') != expected:
            raise ValueError('Native sound stop anchors changed: '+name)
        source = source.replace(channel+'.stop();','Snd.rconnectStopChannel('+channel+');')
    if source==original:
        raise ValueError('No native change: '+name)
    # FFDec's importer loses @ in E4X filters when an attribute and a
    # lexical variable share a name: (@id == id) becomes (id == id).
    # Preserve the query with an explicit attribute read outside `with`.
    # This applies to every recompiled class, including unrelated methods.
    term = r'(?:[A-Za-z_][\w.]*|"[^"\n]*")'
    pattern = r'([A-Za-z_][\w.]*)\.\(@([A-Za-z_]\w*)\s*==\s*('+term+r'(?:\s*\+\s*'+term+r')*)\)'
    source, queries = re.subn(pattern,
        lambda m: 'rconnectXmlFind('+m[1]+',"'+m[2]+'",'+m[3]+')', source)
    if queries:
        constructor = '      public function '+name.split('.')[-1]+'('
        source = once(source, constructor,
            '      private static function rconnectXmlFind(nodes:XMLList, key:String, expected:*):XMLList\n'
            '      {\n         var result:XMLList = new XMLList();\n'
            '         for each(var node:XML in nodes)\n         {\n'
            '            if(node.attribute(key) == expected) result += node;\n'
            '         }\n         return result;\n      }\n\n'+constructor)
    if name in DAMAGE_CLASSES or name in ('fe.unit.Unit','fe.unit.UnitPlayer'):
        prefix = '      ' + ('' if name=='fe.unit.Unit' else 'override ')
        anchor = prefix+'public function damage(param1:Number, param2:int, param3:Bullet = null, param4:Boolean = false) : Number\n      {'
        source=once(source,anchor,anchor+'\n'
            '         if(Unit.rconnectDeferDamage != null && Boolean(Unit.rconnectDeferDamage(this,param1,param2,param3,param4)))\n'
            '         {\n            return 0;\n         }')
    return source.replace('"b1-v3"','"b3-v12"').replace('"b2-v1"','"b3-v12"').replace('"b3-v1"','"b3-v12"')


def swf_tags(path):
    raw = path.read_bytes()
    if raw[:3] == b'CWS':
        raw = raw[:8]+zlib.decompress(raw[8:])
    elif raw[:3] != b'FWS':
        raise ValueError('Unsupported SWF header')
    pos = 8+(5+4*(raw[8] >> 3)+7)//8+4
    result = []
    while pos < len(raw):
        tag = struct.unpack_from('<H', raw, pos)[0]
        pos += 2
        size, kind = tag & 63, tag >> 6
        if size == 63:
            size = struct.unpack_from('<I', raw, pos)[0]
            pos += 4
        data = raw[pos:pos+size]
        if len(data) != size:
            raise ValueError('Invalid SWF tag length')
        result.append((kind, data))
        pos += size
        if kind == 0:
            break
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--baseline', required=True)
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    baseline = inside_build(ROOT/args.baseline)
    verify_baseline(baseline)
    out = inside_build(ROOT/args.output)
    if out.exists():
        raise FileExistsError('Native experiments never overwrite an earlier result')
    out.mkdir(parents=True)
    original = baseline/'game/pfe.swf'
    classes = ['fe.inter.Ctr', 'fe.loc.Location', 'fe.loc.Land', 'fe.unit.Unit', 'fe.unit.UnitPlayer', 'fe.graph.Grafon',
        'fe.unit.Invent','fe.unit.Pers','fe.weapon.Weapon','fe.loc.Game','fe.World','fe.weapon.Bullet','fe.unit.Mine','fe.weapon.WThrow','fe.weapon.PhisBullet',
        'fe.Snd','fe.weapon.WClub','fe.serv.Interact']+MENU_CLASSES+DAMAGE_CLASSES
    ff = [str(JAVA), '-Xmx768m', '-jar', str(FFDEC)]
    with (out/'patch.log').open('w', encoding='utf-8') as log:
        def run(args):
            subprocess.run(ff+args, stdout=log, stderr=subprocess.STDOUT, check=True)
        run(['-selectclass', ','.join(classes+['MainFE']), '-export', 'script', str(out/'export'), str(original)])
        for name in classes:
            rel = name.replace('.', '/')+'.as'
            source = (out/'export/scripts'/rel).read_text(encoding='utf-8-sig')
            modified = modify(name, source)
            dest = out/'import'/rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(modified, encoding='utf-8')
            (out/(name+'.patch')).write_text(''.join(difflib.unified_diff(source.splitlines(True), modified.splitlines(True),
                fromfile='A/'+rel, tofile='B/'+rel)), encoding='utf-8')
        run(['-importScript', str(original), str(out/'pfe.swf'), str(out/'import')])
        run(['-selectclass', ','.join(classes+['MainFE']), '-export', 'script', str(out/'verified'), str(out/'pfe.swf')])
    for name in classes:
        source = (out/'verified/scripts'/(name.replace('.', '/')+'.as')).read_text(encoding='utf-8-sig')
        if 'RCONNECT_AUTHORITY_HOOKS' not in source:
            raise RuntimeError('Patch missing after round trip: '+name)
        imported = (out/'import'/(name.replace('.', '/')+'.as')).read_text(encoding='utf-8')
        if imported.count('rconnectXmlFind(') != source.count('rconnectXmlFind('):
            raise RuntimeError('XML query helper changed after round trip: '+name)
        if re.search(r'\.\((\w+) == \1\)', source):
            raise RuntimeError('Ambiguous XML query survived import: '+name)
    if (out/'export/scripts/MainFE.as').read_bytes() != (out/'verified/scripts/MainFE.as').read_bytes():
        raise RuntimeError('Loader unexpectedly changed')
    before, after = swf_tags(original), swf_tags(out/'pfe.swf')
    if len(before) != len(after):
        raise RuntimeError('SWF tag list changed')
    changed = [i for i, (a, b) in enumerate(zip(before, after)) if a != b]
    if not changed or any(before[i][0] != 82 or after[i][0] != 82 for i in changed):
        raise RuntimeError('Non-code SWF content changed')
    for label, path in [('before', original), ('after', out/'pfe.swf')]:
        with (out/(label+'-classes.txt')).open('w', encoding='utf-8') as log:
            subprocess.run(ff+['-dumpAS3', str(path)], stdout=log, check=True)
    if (out/'before-classes.txt').read_bytes() != (out/'after-classes.txt').read_bytes():
        raise RuntimeError('Native class list changed')
    save(out/'native-input.json', dict(experimental_only=True, capability='b3-v12',
        baseline=str(baseline.relative_to(ROOT)), baseline_manifest_sha256=sha(baseline/'baseline.json'),
        original_sha256=sha(original), candidate_sha256=sha(out/'pfe.swf'),
        sources={p.relative_to(out).as_posix():sha(p) for p in sorted((out/'import').rglob('*.as'))},
        changed_tags=changed, loader_unchanged=True, class_list_unchanged=True,
        script_sha256=sha(__file__)))
    verify_baseline(baseline)
    print('Opt-in native hooks: '+str(out/'pfe.swf'), flush=True)


if __name__ == '__main__':
    main()
