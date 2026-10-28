package fa {
 import flash.display.Sprite;
 import flash.utils.getDefinitionByName;
 /** Explicit B lease over the 0.3.5 implementation. Native world scheduling
  * and reliable input ordering remain owned by RConnect, not ENTER_FRAME. */
 public final class AuthorityAPI extends Sprite {
  public var authorityAPI:Object;
  private var front:Runtime,worldType:Class,lease:Object,records:Object={},role:String="";
  public function AuthorityAPI(runtime:Runtime) {
   front=runtime;worldType=getDefinitionByName("fe.World") as Class;name="FAAuthorityAPI";
   authorityAPI={version:1,attach:attach,validAction:validAction,validInput:validInput};
  }
  private function attach(options:Object):Object {
   if(lease!=null)throw new Error("FA B authority already attached");
   if(options==null||options.version!==1||["host","join"].indexOf(options.role)<0||!(options.withPlayer is Function)||!(options.submit is Function))throw new Error("FA B authority contract mismatch");
   lease=options;role=String(options.role);records={};front.authorityBegin(role=="join");
   front.authoritySubmit=function(key:String,args:Array):Boolean {
    var action:Object={addon:"fa",key:key,args:args};return validAction(action)&&lease!=null&&lease.submit(action)===true;
   };
   return {version:1,register:register,profile:profile,input:input,beforePlayer:beforePlayer,afterPlayer:afterPlayer,
    snapshot:snapshot,present:present,execute:execute,carryState:carryState,detach:detach};
  }
  private function bounded(value:Object,maximum:int):Boolean {
   try{return value!=null&&JSON.stringify(value).length<=maximum;}catch(e:Error){return false;}
   return false;
  }
  public function validAction(value:Object):Boolean {
   if(value==null||value.addon!=="fa"||!(value.key is String)||!(value.args is Array))return false;
   if(value.key=="modify") {
    try {return value.args.length==2&&value.args[0] is String&&front.catalog.guns.hasOwnProperty(value.args[0])&&bounded(value.args[1],12000)&&front.catalog.validate(value.args[0],value.args[1])=="";}
    catch(invalid:Error){return false;}
   }
   return ["grenade","bayonet","bipod","optic","grenadeMode","leaveGrenadeMode"].indexOf(value.key)>=0&&value.args.length==0;
  }
  public function validInput(value:Object):Boolean {
   if(value==null)return true;
   if(!(value.overlay is Boolean)||value.settings==null||!bounded(value.settings,4096))return false;
   for(var key:String in value.settings) {
    if(!AttachmentSettings.DEFAULTS.hasOwnProperty(key))return false;
    if(AttachmentSettings.DEFAULTS[key] is Boolean){if(!(value.settings[key] is Boolean))return false;}
    else if(!(value.settings[key] is Number)||!isFinite(value.settings[key]))return false;
   }
   return true;
  }
  private function profile():Object{return front.authorityProfile();}
  private function input():Object{return {overlay:front.ui!=null&&front.ui.opened,settings:Catalog.clone(front.settings.values)};}
  private function register(key:String,unit:Object,epoch:uint,profile:Object):void {
   if(role!="host"||["0","1"].indexOf(key)<0||unit==null)throw new Error("FA B invalid actor registration");
   if(profile!=null&&(!bounded(profile,64000)||profile.version!==1||profile.weapons==null))throw new Error("FA B invalid profile");
   var previous:Object=records[key],runtime:Runtime;
   if(previous!=null&&previous.unit===unit&&previous.epoch==epoch)return;
   // Resurrection increments epoch without replacing the inventory. Keep the
   // original-value cache, otherwise already-modified guns become new bases.
   runtime=previous!=null?previous.runtime:key=="0"?front:new Runtime(front.main,true);
   runtime.authorityAllowHarm=lease.allowHarm as Function;
   records[key]={unit:unit,epoch:epoch,runtime:runtime,inStep:false};
   lease.withPlayer(key,unit.loc,function():void {
    if(previous!=null)runtime.authorityResetActor();
    runtime.authorityBind(previous!=null || key=="0"?null:profile);
   });
  }
  private function actor(key:String):Object {
   if(role!="host"||records[key]==null)throw new Error("FA B unknown actor");return records[key];
  }
  private function nativeOwner(record:Object):void {
   if(worldType.w.gg!==record.unit||worldType.w.loc!==record.unit.loc)throw new Error("FA B operation outside its native player context");
  }
  private function beforePlayer(key:String,unit:Object,epoch:uint,input:Object):void {
   var record:Object=actor(key);nativeOwner(record);
   if(record.unit!==unit||record.epoch!=epoch||record.inStep)throw new Error("FA B actor identity or step mismatch");
   if(!validInput(input))throw new Error("FA B invalid input");
   record.runtime.authoritySettings(input==null?null:input.settings);
   record.runtime.authorityBefore();record.inStep=true;
  }
  private function afterPlayer(key:String):void {
   var record:Object=actor(key);nativeOwner(record);if(!record.inStep)throw new Error("FA B after without before");
   try {record.runtime.authorityAfter();}finally{record.inStep=false;}
  }
  private function execute(key:String,action:Object):Boolean {
   if(!validAction(action))return false;
   var record:Object=actor(key);nativeOwner(record);return record.runtime.authorityExecute(action.key,action.args);
  }
  private function snapshot(key:String):Object{return actor(key).runtime.authoritySnapshot();}
  private function present(state:Object):void {if(role=="join"&&state!=null)front.authorityPresent(state);}
  private function carryState(game:Object):void {
   if(role=="join"){front.authorityStore(game);return;}
   for each(var record:Object in records)if(worldType.w.gg===record.unit){record.runtime.authorityStore(game);return;}
   throw new Error("FA B save outside registered player scope");
  }
  private function detach():void {
   for each(var record:Object in records)if(record.runtime!==front)record.runtime.authorityDetach();
   front.authorityDetach();records={};lease=null;role="";
  }
 }
}
