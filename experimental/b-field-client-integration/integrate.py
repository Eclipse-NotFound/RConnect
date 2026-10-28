"""Apply the explicit B-only addon seams to the disposable clientenv source."""
from pathlib import Path
import shutil

RC=Path(__file__).resolve().parents[2]
SRC=RC/'build/ab/b190-visual-motion-clientenv-source/src'
HERE=Path(__file__).resolve().parent

def replace(name,old,new):
    p=SRC/name
    text=p.read_text(encoding='utf-8-sig')
    if text.count(old)!=1:raise ValueError(f'{name}: expected one anchor, got {text.count(old)}: {old[:80]}')
    p.write_text(text.replace(old,new),encoding='utf-8',newline='\r\n')

shutil.copyfile(HERE/'AddonsBridge.as',SRC/'authority/AddonsBridge.as')
shutil.copyfile(RC/'experimental/b-field-env-refresh/authority/InjuryBridge.as',SRC/'authority/InjuryBridge.as')
replace('authority/NativeAccess.as','public var weapons:WeaponBridge;','public var weapons:WeaponBridge;\n      public var addons:AddonsBridge;\n      public var injury:InjuryBridge;')
replace('authority/NativeAccess.as','msw:weapons==null?null:weapons.profile()','addons:addons==null?null:addons.profile(),msw:weapons==null?null:weapons.profile()')
replace('RConnectMod.as','if(config.msw!=null)access.weapons=new WeaponBridge(main,access,session,role);',
'''if(config.fa!=null || config.addiction!=null)access.addons=new AddonsBridge(main,access,session,role,config);
         if(config.injury!=null)access.injury=new InjuryBridge(main,access,session,role);
         if(config.msw!=null)access.weapons=new WeaponBridge(main,access,session,role);''')
replace('RConnectMod.as','if(access.weapons!=null){frame.msw=access.weapons.input();if(frame.msw.overlay)frame.buttons=0;}',
'''if(access.weapons!=null){frame.msw=access.weapons.input();if(frame.msw.overlay)frame.buttons=0;}
               if(access.addons!=null){frame.addons=access.addons.input();if(AddonsBridge.blocksInput(frame.addons))frame.buttons=0;}''')
replace('RConnectMod.as','hello.sandy=config.sandy;hello.name=', 'hello.sandy=config.sandy;hello.environment=config.environment;hello.name=')
replace('RConnectMod.as','if(value.sandy!==config.sandy)throw new Error("Sandevistan candidate mismatch");',
'''if(value.sandy!==config.sandy)throw new Error("Sandevistan candidate mismatch");
                  if(value.environment!==config.environment)throw new Error("B mod environment mismatch");''')
replace('RConnectMod.as','if(access.weapons!=null){access.weapons.dispose();access.weapons=null;}',
'''if(access.weapons!=null){access.weapons.dispose();access.weapons=null;}
            if(access.injury!=null){access.injury.dispose();access.injury=null;}
            if(access.addons!=null){access.addons.dispose();access.addons=null;}''')
replace('RConnectMod.as','public function requestWeaponAction(key:String):Boolean {',
'''public function requestAddonAction(action:Object):Boolean {
         if(!welcomed || access.addons==null || !AddonsBridge.validAction(action))return false;
         input.enqueue({type:"native",key:"addonAction",args:[PlainData.copy(action)]});return true;
      }
      public function requestWeaponAction(key:String):Boolean {''')
replace('authority/Commands.as','private var msw:Object;','private var msw:Object,addons:Object;')
replace('authority/Commands.as','if(!WeaponBridge.validInput(value.msw))return "msw-input";',
'''if(!WeaponBridge.validInput(value.msw))return "msw-input";
         if(!AddonsBridge.validInput(value.addons))return "addon-input";''')
replace('authority/Commands.as','msw=value.msw;','msw=value.msw;addons=value.addons;')
replace('authority/Commands.as','if(stale){pressed=0;actions=[];msw=null;projectilePick=null;}',
        'if(stale){pressed=0;actions=[];msw=null;addons=null;projectilePick=null;}')
replace('authority/Commands.as','actions:actions,msw:msw,projectilePick:projectilePick','actions:actions,msw:msw,addons:addons,projectilePick:projectilePick')
replace('authority/Commands.as','public function clear():void {buttons=0;pressed=0;actions=[];lastAt=-1;msw=null;projectilePick=null;}',
        'public function clear():void {buttons=0;pressed=0;actions=[];lastAt=-1;msw=null;addons=null;projectilePick=null;}')
replace('authority/NativeIntents.as','if(key=="mswFlashGive")return args.length==0;',
'''if(key=="mswFlashGive")return args.length==0;
         if(key=="addonAction")return args.length==1 && AddonsBridge.validAction(args[0]);''')
replace('authority/NativeIntents.as','if(key=="mswFlashGive")return actor.access.weapons!=null && actor.access.weapons.execute(actor,"flashGive");',
'''if(key=="mswFlashGive")return actor.access.weapons!=null && actor.access.weapons.execute(actor,"flashGive");
         if(key=="addonAction")return actor.access.addons!=null && actor.access.addons.execute(actor,args[0]);''')
replace('authority/HostSession.as','if(access.weapons!=null)access.weapons.bind(this,hello.profile.msw);',
'''if(access.addons!=null)access.addons.bind(this,hello.profile.addons);
         if(access.weapons!=null)access.weapons.bind(this,hello.profile.msw);''')
replace('authority/HostSession.as','if(access.weapons!=null)access.weapons.present(access.weapons.snapshot(0));',
'''if(access.weapons!=null)access.weapons.present(access.weapons.snapshot(0));
         if(access.addons!=null)access.addons.present(access.addons.snapshot(0));''')
replace('authority/HostSession.as','if(access.weapons!=null)frame.character.msw=access.weapons.snapshot(1);',
'''if(access.weapons!=null)frame.character.msw=access.weapons.snapshot(1);
         if(access.addons!=null)frame.character.addons=access.addons.snapshot(1);
         if(access.injury!=null)frame.character.injury=access.injury.snapshot(actors[1]);''')
replace('authority/PlayerActor.as','var actor:PlayerActor=this;\n         context.loc=',
'''var actor:PlayerActor=this;
         if(access.addons!=null)access.addons.ensure(actor);
         context.loc=''')
replace('authority/PlayerActor.as','if(!context.sats.active) {\n               var heldBefore:',
'''if(!context.sats.active) {
               if(access.addons!=null)access.addons.beforePlayer(actor,input);
               if(access.injury!=null)access.injury.beforePlayer(actor);
               var heldBefore:''')
replace('authority/PlayerActor.as','finally {if(grips!=null)grips.flights.after(actor);}',
'''finally {
                  if(grips!=null)grips.flights.after(actor);
                  if(access.injury!=null)access.injury.afterPlayer(actor);
                  if(access.addons!=null)access.addons.afterPlayer(actor);
               }''')
replace('authority/ClientReplica.as','if(!interpolated && access.weapons!=null && frame.character!=null)access.weapons.present(frame.character.msw);',
'''if(!interpolated && access.weapons!=null && frame.character!=null)access.weapons.present(frame.character.msw);
         if(!interpolated && access.addons!=null && frame.character!=null)access.addons.present(frame.character.addons);
         if(!interpolated && access.injury!=null && frame.character!=null)access.injury.present(frame.character.injury);''')
replace('authority/ClientReplica.as','public function prepareReturn():void {if(access.weapons!=null)access.weapons.carryState(entrySave.game);}',
'''public function prepareReturn():void {
         if(access.weapons!=null)access.weapons.carryState(entrySave.game);
         if(access.addons!=null)access.addons.carryState(entrySave.game);
      }''')
replace('authority/PersonalSaves.as','if(access.weapons!=null)access.weapons.carryState(w.game);',
'''if(access.weapons!=null)access.weapons.carryState(w.game);
            if(access.addons!=null)access.addons.carryState(w.game);''')
replace('authority/PersonalSaves.as','access.world.saveGame(slot);',
'''if(access.addons!=null)access.addons.carryState(access.world.game);
               access.world.saveGame(slot);''')
print('Integrated B addon leases, reliable intents, per-actor stepping, confirmed views, and personal saves.')
