package addiction {
 import flash.display.*;import flash.events.*;import flash.filesystem.*;import flash.utils.*;
 import flash.system.ApplicationDomain;import flash.desktop.NativeApplication;
 public class Runtime {
  public static const VERSION:String='0.1.0';
  public static const KEY:String='addictionsystem.state.v1';
  public static const PROFILE:String='addictionsystem_profile';
  public var main:Object,world:Object,gg:Object,engine:Engine,ui:Panel;
  public var bridge:Class;public var attached:Boolean=false;public var vis:Object=null;
  private var boundGame:Object,boundPers:Object,profile:XML;
  private var tick:int=0,frames:int=0,busy:Boolean=false,failedPlayer:Object;
  public var authority:AuthorityAPI,authorityKey:String='';
  private var managed:Boolean=false,awaitOwnGame:Boolean=false,suspendedUnit:Object,authorityReceived:Boolean=false;
  private var savedJSON:String=null,notices:Array=[],noticeSerial:uint=0,presentSerial:uint=0,presentRefresh:int=0;
  public function Runtime(host:Object,managed:Boolean=false){
   main=host;this.managed=managed;
   if(managed)return;
   var carrier:MovieClip=new MovieClip();carrier.name='AddictionSystemCarrier';carrier.api=this;main.addChild(carrier);
   main.addChild(new AuthorityAPI(this));
   log('v'+VERSION+' B bridge loaded '+NativeApplication.nativeApplication.applicationID);main.stage.addEventListener(Event.ENTER_FRAME,frame);
  }
  public function definition(name:String):Class{return ApplicationDomain.currentDomain.getDefinition(name) as Class;}
  public function log(message:String):void {
   trace('[AddictionSystem] '+message);
   try{var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath('AddictionSystem.log'),FileMode.APPEND);stream.writeUTFBytes(new Date().toUTCString()+' '+message+'\n');stream.close();}catch(e:Error){trace(e.message);}
  }
  private function frame(event:Event):void {
   try{
    if(!world)world=definition('fe.World')['w'];
    if(!world)return;
    if(Number(world.constructor['boxDamage'])!=.2){log('Unsupported host; 1.02 required');main.stage.removeEventListener(Event.ENTER_FRAME,frame);return;}
    // RConnect owns binding and native child ticks while leased. ENTER_FRAME
    // must never mistake the temporary remote-player scope for a new save.
    if(authority){if(ui){if(attached&&world.gg===gg&&world.allStat>=1)ui.update();else ui.hide();}return;}
    if(awaitOwnGame){if(world.gg===suspendedUnit){if(ui)ui.hide();return;}awaitOwnGame=false;suspendedUnit=null;}
    if(world.gg && world.pers && world.invent && world.game && world.allStat>=1 && world.gg!==failedPlayer){
     if(world.gg!==gg || world.game!==boundGame || world.pers!==boundPers)attach();
     if(attached){if(world.gg.childObjs)world.gg.childObjs['addictionsystem.tick']=this;if(ui)ui.update();}
    }else if(ui)ui.hide();
    if(++frames%300==0)log('heartbeat attached='+attached+' t='+(engine?engine.s.t.toFixed(3):'-'));
   }catch(e:Error){failedPlayer=world?world.gg:null;attached=false;log('ERROR frame '+e.getStackTrace());if(ui)ui.message('药物模组未能接入，详见日志。');}
  }
  private function attach(saved:String=null,explicit:Boolean=false,showUI:Boolean=true):void {
   attached=false;if(ui){ui.dispose();ui=null;}
   if(gg&&gg.childObjs&&gg.childObjs['addictionsystem.tick']===this)delete gg.childObjs['addictionsystem.tick'];
   var oldInv:Object=world.invent,oldPers:Object=world.pers;
   var ownInv:Boolean=getQualifiedClassName(oldInv)=='fe.unit::AddictionInvent'&&oldInv.controller===this;
   var ownPers:Boolean=getQualifiedClassName(oldPers)=='fe.unit::AddictionPers'&&oldPers.controller===this;
   if((!ownInv&&getQualifiedClassName(oldInv)!='fe.unit::Invent') || (!ownPers&&getQualifiedClassName(oldPers)!='fe.unit::Pers'))throw new Error('Another mod replaced Invent/Pers; refusing destructive replacement.');
   gg=world.gg;boundGame=world.game;
   var stored:*=explicit?saved:world.game.triggers[KEY];
   if(stored!==undefined && stored!==null && !(stored is String))throw new Error('Saved state is not JSON text; original preserved.');
   engine=new Engine(stored==null?null:String(stored),oldPers.addictions);
   var invClass:Class=definition('fe.unit.AddictionInvent'),persClass:Class=definition('fe.unit.AddictionPers');
   bridge=definition('fe.inter.AddictionUIBridge');
   var inv:Object=ownInv?oldInv:new invClass(oldInv,this),pers:Object=ownPers?oldPers:new persClass(oldPers,this);
   world.invent=gg.invent=inv;world.pers=gg.pers=pers;boundPers=pers;
   if(world.stand)world.stand.inv=inv;
   bridge['bind'](world.pip,inv,pers,gg);
   // First store migrated values, then suppress native addiction notices/effects.
   persist();
   for each(var id:String in Catalog.families)pers.addictions[id]=0;
   for(var i:int=gg.effects.length-1;i>=0;i--){var eff:Object=gg.effects[i];
    if(Catalog.drugs[eff.id] || Catalog.categories[eff.id]){
     if(stored==null){var family:String=Catalog.drugs[eff.id]?Catalog.drugs[eff.id].category:eff.id,f:Object=engine.s.families[family];
      if(Catalog.drugs[eff.id]&&!eff.vse){f.active={drug:eff.id,end:engine.s.t+Math.max(0,eff.t)/1800,strength:1,level:eff.lvl>=2?2:1};f.until=f.active.end;}
      else if(!f.dependent&&!eff.vse)f.post=engine.s.t+Math.max(0,eff.t)/1800;
     }
     // These eight buffs have only parameter effects: removing them avoids native post generation.
     gg.effects.splice(i,1);
    }
   }
   var data:XML=definition('fe.AllData')['d'];
   var existing:XMLList=data.eff.(@id==PROFILE);
   if(existing.length())profile=existing[0];else{profile=<eff/>;profile.@id=PROFILE;profile.@t=1;data.appendChild(profile);}
   attached=true;tick=0;persist();if(parametersAllowed())world.pers.setParameters();
   if(showUI)ui=new Panel(this);
   if(parametersAllowed()&&gg.childObjs)gg.childObjs['addictionsystem.tick']=this;
   log('attached '+getQualifiedClassName(inv)+' '+getQualifiedClassName(pers)+' migrated='+(stored==null));
  }
  public function handles(id:String):Boolean{return id!=null && (Catalog.drugs[id]!=null || id=='detoxin');}
  public function stock(id:String):int {var item:Object=world.invent.items[id];return item?Math.max(0,int(item.kol)):0;}
  public function stocks():Object {var s:Object={};for each(var id:String in Catalog.ids)s[id]=stock(id);return s;}
  public function dose(id:String,count:int=1,automatic:Boolean=false):Boolean {
   if(authority&&!authority.isHost){if(automatic)return false;return authority.submit({addon:'addiction',key:'dose',args:[id,count]});}
   if(!attached || !handles(id) || world.alicorn || gg.sost>=3 || count<1 || count>1000)return false;
   engine.boundaries();var q:int=id=='detoxin'?1:count;
   if(stock(id)<q){notice('背包里的药品数量不足。');return false;}
   var data:XML=definition('fe.AllData')['d'],pot:XMLList=data.item.(@id==id);
   if(!pot.length() || Number(pot.@minmed)>world.pers.medic){notice('医疗技能不足。');return false;}
   if(id=='detoxin'){
    if(!engine.detox()){notice('瘾头解还需间隔 '+Math.ceil(engine.s.lastDetox+engine.p.detox_gap-engine.s.t)+' 游戏分钟。');return false;}
   }else engine.dose(id,q,world.pers.himBadMult,world.pers.himBadDif,world.pers.himTimeMult,world.pers.himLevel);
   world.invent.minusItem(id,q);persist();world.pers.setParameters();
   notice((automatic?'不由自主地服用：':'已服用：')+(id=='detoxin'?'瘾头解':Catalog.drugs[id].name)+' ×'+q);
   if(ui && ui.expanded)ui.refresh();log('dose '+id+' q='+q+' auto='+automatic);return true;
  }
  public function doctor():Boolean{return attached && world.pip.active && !world.pip.noAct && bridge['page'](world.pip)==6 && world.pip.npcInter!='adoc' && world.pip.npcInter!='vdoc' && !world.alicorn;}
  public function treat(id:String):Boolean {
   if(authority&&!authority.isHost)return authority.submit({addon:'addiction',key:'treat',args:[id]});
   if(!doctor() || !engine.s.families[id])return false;
   engine.boundaries();var fee:int=engine.cost(id);
   if(world.invent.money.kol<fee){notice('治疗费用不足；停药也能缓慢恢复。');return false;}
   if(!engine.beginClinic(id)){notice('已有疗程，或这一类不需要治疗。');return false;}
   world.invent.minusItem(world.invent.money.id,fee);persist();world.pers.setParameters();notice('已开始疗程。关闭菜单后按有效游戏时间推进。');log('clinic '+id+' fee='+fee);return true;
  }
  public function cancelAuto():void {if(authority&&!authority.isHost){authority.submit({addon:'addiction',key:'cancelAuto',args:[]});return;}if(engine && engine.cancelAuto()){persist();notice('已忍住服药冲动。');}}
  public function step():void {
   if(authority&&!authority.isHost)return;
   if(!attached || world.gg!==gg || world.allStat!=1 || world.onPause || world.catPause || world.t_die>0 || gg.sost>=3 || world.pip.active || world.mm.active)return;
   try{
    engine.advance(1/1800);
    if(!world.alicorn){var drug:String=engine.automatic(stocks());if(drug)dose(drug,1,true);}
    else engine.s.pending=null;
    persist();
    if(++tick%15==0)world.pers.setParameters();
    while(engine.events.length){var ev:String=engine.events.shift();if(ev=='clinic-complete')notice('本次疗程完成。');if(ev=='clinic-interrupted')notice('同类服药中断了疗程。');log(ev);}
   }catch(e:Error){log('ERROR step '+e.getStackTrace());attached=false;}
  }
  public function err():void {log('ERROR native child step');}
  public function addVisual():void {}
  public function remVisual():void {}
  public function persist():void {
   if(!engine)return;savedJSON=engine.json();
   // The shared Game belongs to host 0. Remote state travels with that
   // character's profile/confirmation and is copied only into its own save.
   if(world&&world.game===boundGame&&(!authority||(authority.isHost&&authorityKey=='0')))world.game.triggers[KEY]=savedJSON;
  }
  public function parametersAllowed():Boolean{return authority==null||authority.isHost;}
  public function authorityProfile():Object {
   if(!world)world=definition('fe.World')['w'];
   if(engine&&((authority!=null)||world==null||gg===world.gg))return {version:1,state:savedJSON==null?engine.json():savedJSON};
   if(world&&world.pers&&world.game){var raw:*=world.game.triggers[KEY];if(raw!=null&&!(raw is String))throw new Error('Saved addiction state is not JSON text');return {version:1,state:new Engine(raw==null?null:String(raw),world.pers.addictions).json()};}
   return {version:1,state:null};
  }
  public function authorityBind(owner:AuthorityAPI,key:String,state:Object,showUI:Boolean):void {
   authority=owner;authorityKey=key;world=definition('fe.World')['w'];awaitOwnGame=false;suspendedUnit=null;
   if(!world||!world.gg||!world.pers||!world.invent||!world.game)throw new Error('Addiction B player context unavailable');
   if(attached&&gg===world.gg&&boundGame===world.game&&boundPers===world.pers){
    if(owner.isHost&&gg.childObjs)gg.childObjs['addictionsystem.tick']=this;
    return;
   }
   attach(state==null?null:state.state,true,showUI);
  }
  public function authoritySnapshot():Object {
   var result:Object=authorityProfile();result.notices=notices.concat();return result;
  }
  public function authorityPresent(state:Object):void {
   var next:Engine=new Engine(state.state),changed:Boolean=state.state!==savedJSON;
   world=definition('fe.World')['w'];
   if(!attached||gg!==world.gg||boundGame!==world.game||boundPers!==world.pers)attach(state.state,true,true);
   engine=next;savedJSON=state.state;authorityReceived=true;
   if(changed&&ui&&ui.expanded&&++presentRefresh%8==0)ui.refresh();
   for each(var item:Object in state.notices)if(uint(item.serial)>presentSerial){presentSerial=uint(item.serial);if(ui)ui.message(item.text);}
  }
  public function authorityStore(game:Object):void {
   if(!game||!engine)return;if(!game.triggers)game.triggers={};game.triggers[KEY]=savedJSON==null?engine.json():savedJSON;
  }
  public function authorityRelease(resume:Boolean):void {
   // A rejected handshake can leave the original single-player body in place.
   // In that case there is no remote replica to quarantine until a load.
   if(!resume&&!managed&&!authorityReceived&&world&&world.gg===gg&&world.game===boundGame)resume=true;
   if(gg&&gg.childObjs&&gg.childObjs['addictionsystem.tick']===this)delete gg.childObjs['addictionsystem.tick'];
   authority=null;authorityKey='';notices=[];presentSerial=0;noticeSerial=0;authorityReceived=false;
   if(resume){if(attached&&gg&&gg.childObjs)gg.childObjs['addictionsystem.tick']=this;persist();}
   else {attached=false;awaitOwnGame=!managed;suspendedUnit=gg;if(ui){ui.dispose();ui=null;}}
  }
  public function nativeSave(data:Object):void {if(!engine)return;for each(var id:String in Catalog.families)data.addictions[id]=engine.s.families[id].A;}
  public function beforeParameters():Object {
   if(!attached || busy || !profile || world.gg!==gg || world.alicorn)return null;
   busy=true;profile.setChildren(new XMLList());var metrics:Object=engine.metrics();
   for(var id:String in metrics){var v:Number=metrics[id];if(Math.abs(v-(Catalog.mult[id]?1:0))<1e-9)continue;
    var sk:XML=<sk/>;sk.@id=id;sk.@ref=Catalog.mult[id]?'mult':'add';sk.@v1=v;profile.appendChild(sk);
   }
   var E:Class=definition('fe.unit.Effect'),effect:Object=new E(PROFILE,gg);gg.effects.push(effect);return effect;
  }
  public function afterParameters(effect:Object):void {if(effect){var i:int=gg.effects.indexOf(effect);if(i>=0)gg.effects.splice(i,1);
   // Keep the measured result but do not reveal hidden dependency as a named factor.
   for each(var factors:* in world.pers.factor)if(factors is Array)for(i=factors.length-1;i>=0;i--)if(factors[i].id==PROFILE)factors.splice(i,1);
   busy=false;}}
  public function notice(message:String):void {if(authority&&authority.isHost){notices.push({serial:++noticeSerial,text:message});if(notices.length>32)notices.shift();}if(ui)ui.message(message);}
 }
}
