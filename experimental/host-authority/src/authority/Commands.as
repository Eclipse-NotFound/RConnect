package authority {
   /** Input acceptance is independent of rendering. No world-side effects here. */
   public class Commands {
      public static const LEFT:int=1,RIGHT:int=2,JUMP:int=4,FIRE:int=8,SIT:int=16,RUN:int=32;
      public var session:String,room:String,player:int,epoch:int=1,weaponEpoch:int=1;
      public var accepted:int=0,consumed:int=0,lastAt:int=-1;
      public var roomEpoch:int=1;
      public var buttons:int=0,aimX:Number=0,aimY:Number=0;
      private var actions:Array=[];
      private var lastAction:int=0;
      private var pressed:int=0;
      public function Commands(session:String,player:int,room:String) {this.session=session;this.player=player;this.room=room;}
      public function accept(value:Object,now:int):String {
         if(value==null || value.session!==session || value.player!==player || value.epoch!==epoch || value.room!==room || value.roomEpoch!==roomEpoch || value.weaponEpoch!==weaponEpoch)return "identity";
         if(!(value.seq is Number) || value.seq<=accepted || value.seq!=int(value.seq))return "sequence";
         if(!(value.buttons is Number) || value.buttons!=int(value.buttons) || value.buttons<0 || value.buttons>63)return "buttons";
         if(!(value.aimX is Number) || !(value.aimY is Number) || !isFinite(value.aimX) || !isFinite(value.aimY)
            || Math.abs(value.aimX)>100000 || Math.abs(value.aimY)>100000)return "aim";
         if(!(value.actions is Array) || value.actions.length>16 || actions.length+value.actions.length>64)return "actions";
         var nextAction:int=lastAction, staged:Array=[];
         for each(var action:Object in value.actions) {
            if(action==null || !(action.id is Number) || action.id!=int(action.id) || action.id<=0)return "action-id";
            if(action.type!="reload" && action.type!="equip")return "unsupported-action";
            if(action.type=="equip" && (!(action.weapon is String) || action.weapon.length==0 || action.weapon.length>80))return "weapon";
            if(action.id<=nextAction)continue;
            nextAction=int(action.id);staged.push({id:nextAction,type:action.type,weapon:action.weapon});
         }
         pressed|=(int(value.buttons)&~buttons)&(FIRE|JUMP);
         accepted=int(value.seq);lastAt=now;buttons=int(value.buttons);aimX=value.aimX;aimY=value.aimY;
         lastAction=nextAction;actions=actions.concat(staged);
         return "";
      }
      public function consume(now:int):Object {
         if(lastAt<0 || now-lastAt>500){buttons=0;pressed=0;actions=[];}
         var result:Object={seq:accepted,buttons:buttons|pressed,aimX:aimX,aimY:aimY,actions:actions};
         consumed=accepted;actions=[];pressed=0;return result;
      }
      public function clear():void {buttons=0;pressed=0;actions=[];lastAt=-1;}
      public function retarget(room:String,roomEpoch:int):void {clear();this.room=room;this.roomEpoch=roomEpoch;}
      public static function greetingMatches(value:Object,session:String):Boolean {
         return value!=null && value.family===BuildInfo.FAMILY && value.revision===BuildInfo.REVISION
            && value.source===BuildInfo.SOURCE && value.native===BuildInfo.NATIVE && value.session===session;
      }
      public static function greeting(type:String,session:String):Object {
         return {type:type,family:BuildInfo.FAMILY,revision:BuildInfo.REVISION,source:BuildInfo.SOURCE,native:BuildInfo.NATIVE,session:session};
      }
   }
}
