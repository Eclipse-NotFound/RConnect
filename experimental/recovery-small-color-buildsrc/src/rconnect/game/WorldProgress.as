package rconnect.game {
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import fe.loc.Location;
   /** The room owner runs native XP pickup once, including its final-point and
    * stealth bonuses. Both characters receive that exact reward once. */
   public class WorldProgress {
      private var game:GameBridge,room:Object,epoch:int=-1;
      private var states:Object={},pending:Object={},out:Array=[];
      private var tracked:Dictionary=new Dictionary();
      public function WorldProgress(g:GameBridge) {game=g;}
      public function reset():void {room=null;epoch=-1;states={};pending={};out=[];tracked=new Dictionary();}
      private function prefix():String {return game.roomEpoch+"|"+game.roomKey()+"|";}
      private function key(o:Object):String {
         var k:String=kind(o),list:Array=k=="xp"?game.loc.bonuses:game.loc.acts;
         return prefix()+k+"|"+list.indexOf(o);
      }
      private function points(loc:Object):Array {return (loc.bonuses as Array).concat(loc.acts as Array);}
      public function capture(loc:Object):Object {
         var list:Array=[];
         for each(var o:Object in loc.bonuses)list.push({id:String(o.id),x:Number(o.X),y:Number(o.Y),sost:int(o.sost),code:o.code,uid:o.uid});
         var cps:Array=[];for each(o in loc.acts)if(kind(o)=="cp")cps.push({index:loc.acts.indexOf(o),id:String(o.id),x:Number(o.X),y:Number(o.Y),active:int(o.active),code:o.code,uid:o.uid});
         return {bonuses:list,cps:cps,unXp:Number(loc.unXp),maxXp:int(loc.maxXp),kolXp:int(loc.kolXp),summXp:Number(loc.summXp),detecting:Boolean(loc.detecting)};
      }
      public function restore(data:Object):void {
         if(data==null || !(data.bonuses is Array) || game.loc==null)return;
         var loc:Object=game.loc;syncEpoch();
         // Native random XP placement is independent of the room tile seed.
         // Use the owner's slots and positions, retaining native save references.
         for(var i:int=0;i<data.bonuses.length;i++) {
            var s:Object=data.bonuses[i],o:Object=i<loc.bonuses.length?loc.bonuses[i]:null;
            if(s.id!="xp")continue;
            if(o==null || o.id!="xp" || Number(o.X)!=Number(s.x) || Number(o.Y)!=Number(s.y)) {
               var replacement:Object=new CooperativeBonus(loc as Location,int(s.x),int(s.y),{sost:s.sost},this);
               if(o!=null)replace(o,replacement,i);else {loc.bonuses[i]=replacement;if(int(s.sost)==1)loc.addObj(replacement);}
               o=replacement;
            }
            identity(o,s.code,s.uid);
            if(int(s.sost)!=1 && int(o.sost)==1){o.sost=2;o.liv=0;if(o.vis!=null)o.vis.gotoAndPlay(2);}
            if(states[key(o)]!=null)apply(o,states[key(o)]);
         }
         while(loc.bonuses.length>data.bonuses.length) {
            var extra:Object=loc.bonuses.pop();loc.remObj(extra);identity(extra,"","");
         }
         // A local pending request cannot change these owner counters.
         loc.unXp=Number(data.unXp);loc.maxXp=int(data.maxXp);loc.kolXp=int(data.kolXp);
         loc.summXp=Number(data.summXp);
         if(data.detecting is Boolean)loc.detecting=data.detecting;
         for each(s in data.cps) {
            var n:int=int(s.index);o=n<loc.acts.length?loc.acts[n]:null;
            if(o==null) {
               var cls:Class=game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.CheckPoint") as Class;
               o=new cls(loc,String(s.id),int(s.x),int(s.y),null,null);loc.acts[n]=o;loc.addObj(o);
               if(loc.cp==null)loc.cp=o;
            }
            if(kind(o)!="cp")continue;
            identity(o,s.code,s.uid);
            if(Number(o.X)!=Number(s.x) || Number(o.Y)!=Number(s.y)) {
               o.X=Number(s.x);o.Y=Number(s.y);o.X1=o.X-o.scX/2;o.X2=o.X+o.scX/2;o.Y1=o.Y-o.scY;o.Y2=o.Y;
               if(o.area!=null)o.area.setSize(o.X1,o.Y1,o.X2,o.Y2);
               if(o.vis!=null){o.vis.x=o.X;o.vis.y=o.Y;}
               loc.getAbsTile(o.X-20,o.Y+10).shelf=true;loc.getAbsTile(o.X+20,o.Y+10).shelf=true;
            }
            if(int(s.active)>0)apply(o,{kind:"cp"});
         }
         prepare();
      }
      private function identity(o:Object,code:*,uid:*):void {
         var loc:Object=game.loc,index:int=loc.saves.indexOf(o);
         if(o.uid!=null && String(o.uid)!="" && loc.land.uidObjs[o.uid]===o)delete loc.land.uidObjs[o.uid];
         o.code=code==null?"":String(code);o.uid=uid==null?"":String(uid);
         if(o.code!="" && index<0)loc.saves.push(o);
         else if(o.code=="" && index>=0)loc.saves.splice(index,1);
         if(o.uid!="")loc.land.uidObjs[o.uid]=o;
      }
      private function replace(o:Object,replacement:Object,index:int):void {
         var loc:Object=game.loc,live:Boolean=o.in_chain;
         replacement.code=o.code;replacement.uid=o.uid;replacement.nazv=o.nazv;
         loc.remObj(o);loc.bonuses[index]=replacement;
         var saveIndex:int=loc.saves.indexOf(o);if(saveIndex>=0)loc.saves[saveIndex]=replacement;
         if(o.uid!=null && o.uid!="" && loc.land.uidObjs[o.uid]===o)loc.land.uidObjs[o.uid]=replacement;
         if(live && int(replacement.sost)==1)loc.addObj(replacement);
      }
      private function kind(o:Object):String {
         var cls:String=getQualifiedClassName(o);
         if((o is CooperativeBonus || cls=="fe.loc::Bonus") && o.id=="xp")return "xp";
         if(cls=="fe.loc::CheckPoint" && !o.main && !o.hide)return "cp";
         return "";
      }
      private function taken(o:Object,k:String):Boolean {return k=="xp"?int(o.sost)!=1:int(o.active)>0;}
      private function syncEpoch():void {if(epoch!=game.roomEpoch){reset();epoch=game.roomEpoch;}}
      public function prepare():void {
         if(game.loc==null || game.gg==null)return;
         syncEpoch();
         if(room!==game.loc){room=game.loc;tracked=new Dictionary();}
         for each(var o:Object in points(room)) {
            var k:String=kind(o);if(k=="")continue;
            if(k=="xp" && !(o is CooperativeBonus) && int(o.sost)==1) {
               var replacement:Object=new CooperativeBonus(room as Location,int(o.X),int(o.Y),o.save(),this);
               replacement.val=o.val;replacement.liv=o.liv;
               replace(o,replacement,room.bonuses.indexOf(o));o=replacement;
            }
            var id:String=key(o),v:Boolean=taken(o,k),prev:Object=tracked[o];
            if(states[id]!=null)apply(o,states[id]);
            else if((prev==null && v) || (prev!=null && v && !prev.taken))publish(o,k,0);
            tracked[o]={taken:taken(o,k)};
         }
      }
      public function scan():Array {prepare();var result:Array=out;out=[];return result;}
      private function publish(o:Object,k:String,reward:Number):void {
         var record:Object={key:key(o),room:prefix(),kind:k,epoch:game.roomEpoch,reward:reward};
         states[record.key]=record;delete pending[record.key];out.push(record);
      }
      public function take(o:Object):void {
         syncEpoch();var id:String=key(o);
         if(states[id]!=null){apply(o,states[id]);return;}
         if(int(o.sost)!=1)return;
         if(game.mirrorsRoom) {
            if(!pending[id]){pending[id]=true;out.push({request:true,key:id,room:prefix(),kind:"xp",epoch:epoch});}
            return;
         }
         var reward:Number=Number(game.loc.unXp);
         if(int(game.loc.kolXp)==1 && int(game.loc.maxXp)>1) {
            reward*=int(game.loc.maxXp);
            if(!game.loc.detecting)reward+=Math.max(0,Number(game.loc.summXp));
         }
         o.takeNative();publish(o,"xp",reward);
      }
      public function receive(events:Array):void {
         if(events==null || game.gg==null || game.loc==null)return;
         prepare();
         for each(var s:Object in events) {
            if(s==null || int(s.epoch)!=epoch || (s.kind!="xp" && s.kind!="cp"))continue;
            var id:String=String(s.key),local:Object=null;
            if(s.room==prefix())for each(var o:Object in points(game.loc))
               if(kind(o)==s.kind && key(o)==id){local=o;break;}
            if(s.request===true) {
               if(!game.mirrorsRoom && s.room==prefix()) {
                  if(states[id]!=null)out.push(states[id]);
                  else if(local is CooperativeBonus)take(local);
               }
               continue;
            }
            if(states[id]!=null)continue;
            if(!isFinite(Number(s.reward)) || Number(s.reward)<0 || Number(s.reward)>1000000)continue;
            states[id]=s;delete pending[id];
            if(s.kind=="xp" && Number(s.reward)>0)game.world.pers.expa(Number(s.reward));
            if(local!=null){apply(local,s);tracked[local]={taken:true};}
         }
      }
      private function apply(o:Object,s:Object):void {
         if(s.kind=="xp") {
            if(int(o.sost)==1){o.sost=2;o.liv=0;game.loc.kolXp=Math.max(0,int(game.loc.kolXp)-1);if(o.vis!=null)o.vis.gotoAndPlay(2);}
         } else if(int(o.active)==0) {
            // Unlock only. The player's own interaction selects their respawn
            // point and invokes native saveGame for their own character.
            o.active=1;o.inter.setAct("lock",0);o.inter.setAct("mine",0);
            if(o.vis!=null)o.vis.osn.gotoAndStop("reopen");
            o.inter.actFun=o.activate;o.inter.userAction="activate";o.inter.active=true;o.inter.action=100;o.inter.update();
         }
      }
   }
}
