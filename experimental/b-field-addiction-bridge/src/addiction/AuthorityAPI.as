package addiction {
 import flash.display.Sprite;
 /** B-only authority lease. Scheduling and input ordering stay in RConnect;
  * the original Engine and native player child tick retain the drug rules. */
 public final class AuthorityAPI extends Sprite {
  public var authorityAPI:Object;
  private var front:Runtime,lease:Object,api:Object,records:Object={};
  private var role:String='';
  public function AuthorityAPI(runtime:Runtime){front=runtime;name='AddictionAuthorityAPI';authorityAPI={version:1,attach:attach,validAction:validAction};}
  public function get isHost():Boolean{return role=='host';}
  private function attach(options:Object):Object {
   if(options==null||options.version!==1||['host','join'].indexOf(options.role)<0||!(options.session is String)||options.session.length==0||options.session.length>128||!(options.withPlayer is Function)||!(options.submit is Function)||!(options.rebindContext is Function))throw new Error('Addiction B authority contract mismatch');
   if(lease){if(lease.session===options.session&&role===options.role)return api;throw new Error('Addiction B authority already attached');}
   lease=options;role=String(options.role);records={};front.authority=this;front.authorityKey=isHost?'0':'1';
   // The old single-player hook may already be present before joining.
   if(!isHost&&front.gg&&front.gg.childObjs&&front.gg.childObjs['addictionsystem.tick']===front)delete front.gg.childObjs['addictionsystem.tick'];
   api={version:1,register:register,profile:profile,snapshot:snapshot,present:present,execute:execute,carryState:carryState,detach:detach};return api;
  }
  private function validState(value:Object,nullable:Boolean=false):Boolean {
   if(value==null||value.version!==1)return false;
   if(nullable&&value.state===null)return true;
   return value.state is String&&value.state.length>0&&value.state.length<=65536;
  }
  public function validAction(value:Object):Boolean {
   if(value==null||value.addon!=='addiction'||!(value.key is String)||!(value.args is Array))return false;
   var args:Array=value.args;
   if(value.key=='dose')return args.length==2&&args[0] is String&&front.handles(args[0])&&args[1] is Number&&isFinite(args[1])&&args[1]==int(args[1])&&args[1]>=1&&args[1]<=1000;
   if(value.key=='treat')return args.length==1&&args[0] is String&&Catalog.families.indexOf(args[0])>=0;
   return value.key=='cancelAuto'&&args.length==0;
  }
  public function submit(action:Object):Boolean{return lease!=null&&!isHost&&validAction(action)&&lease.submit(action)===true;}
  private function profile():Object{return front.authorityProfile();}
  private function register(key:String,unit:Object,epoch:int,state:Object):void {
   if(!isHost||['0','1'].indexOf(key)<0||unit==null||unit.loc==null)throw new Error('Addiction B invalid actor registration');
   if(state!=null&&!validState(state,true))throw new Error('Addiction B invalid actor profile');
   var previous:Object=records[key],runtime:Runtime;
   if(previous!=null){
    runtime=previous.runtime;
    // Respawn/new body carries this actor's latest state, not the handshake's
    // old profile or the shared host Game trigger.
    state=runtime.authorityProfile();
   }else runtime=key=='0'?front:new Runtime(front.main,true);
   if(state!=null&&state.state!=null)new Engine(state.state); // validate before replacing native wrappers
   var record:Object={unit:unit,epoch:epoch,runtime:runtime},owner:AuthorityAPI=this;records[key]=record;
   try {
    lease.withPlayer(key,unit.loc,function():void {
     nativeOwner(record);
     runtime.authorityBind(owner,key,state,key=='0');
     // World's fields are restored by NativeScope; update its actor context
     // now so the next run installs these exact new Pers/Invent references.
     lease.rebindContext(key);
    });
   }catch(e:Error){if(previous)records[key]=previous;else delete records[key];throw e;}
  }
  private function actor(key:String):Object {
   if(!isHost||records[key]==null)throw new Error('Addiction B unknown actor');return records[key];
  }
  private function nativeOwner(record:Object):void {
   var world:Object=front.definition('fe.World')['w'];
   if(world==null||world.gg!==record.unit||world.loc!==record.unit.loc)throw new Error('Addiction B operation outside its native player context');
  }
  private function snapshot(key:String):Object{return actor(key).runtime.authoritySnapshot();}
  private function present(state:Object):void {
   if(role!='join'||state==null)return;
   if(!validState(state)||!(state.notices is Array)||state.notices.length>32)throw new Error('Addiction B invalid confirmation');
   for each(var item:Object in state.notices)if(item==null||!(item.serial is Number)||item.serial!=uint(item.serial)||!(item.text is String)||item.text.length>2048)throw new Error('Addiction B invalid notice');
   front.authorityPresent(state);
  }
  private function execute(key:String,action:Object):Boolean {
   if(!validAction(action))return false;
   var record:Object=actor(key),runtime:Runtime=record.runtime,result:Boolean=false;
   lease.withPlayer(key,record.unit.loc,function():void {
    nativeOwner(record);
    if(action.key=='dose')result=runtime.dose(action.args[0],int(action.args[1]));
    else if(action.key=='treat')result=runtime.treat(action.args[0]);
    else {runtime.cancelAuto();result=true;}
   });return result;
  }
  private function carryState(game:Object):void {
   if(role=='join'){front.authorityStore(game);return;}
   var world:Object=front.definition('fe.World')['w'];
   for each(var record:Object in records)if(world.gg===record.unit){record.runtime.authorityStore(game);return;}
   throw new Error('Addiction B save outside registered player scope');
  }
  private function detach():void {
   if(lease==null)return;
   for each(var record:Object in records)if(record.runtime!==front)record.runtime.authorityRelease(false);
   front.authorityRelease(isHost);records={};lease=null;api=null;role='';
  }
 }
}
