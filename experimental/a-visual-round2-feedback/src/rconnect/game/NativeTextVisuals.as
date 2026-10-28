package rconnect.game {
   import flash.events.Event;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import fe.graph.Emitter;
   import fe.unit.Unit;
   import fe.unit.RConnectTextAccess;
   import rconnect.core.Session;
   import rconnect.core.Log;
   import rconnect.net.TcpLink;
   import rconnect.net.NetMessageEvent;

   /** Native speech and authoritative throw feedback, with their own lifetimes.
    * Never derive numbers from hp deltas or replay Unit.damage/replic. */
   public class NativeTextVisuals {
      public static var instance:NativeTextVisuals;
      private var mod:Object,room:String="",nextId:int=0;
      // Keep source Parts until their ending is sent; a weak key could vanish
      // after a native cancellation before the observer publishes it.
      private var taps:Object={},sources:Dictionary=new Dictionary(),throws:Dictionary=new Dictionary(true);
      private var received:Object={},links:Dictionary=new Dictionary(),faults:int=0;
      public function NativeTextVisuals(m:Object) {
         mod=m;instance=this;
         mod.stage.addEventListener(Event.ENTER_FRAME,before,false,98000);
         mod.stage.addEventListener(Event.ENTER_FRAME,after,false,-12000);
      }
      private function get game():Object {return mod.game;}
      private function get session():Object {return mod.session;}
      private function get rooms():Object {return session.rooms;}
      private function ready():Boolean {
         if(session.mode==Session.CONNECTED) {
            if(session.link==null||!session.link.isOpen)return false;
         } else if(session.mode==Session.HOSTING) {
            if(session.server==null||session.peers.length==0)return false;
         } else return false;
         return game.loc!=null && game.gg!=null && rooms.canSyncWorld && !game.roomHold && !game.isTransitioning();
      }
      private function stamp():String {return game.roomKey()+":"+rooms.epoch+":"+rooms.term;}
      private function watch(link:TcpLink):void {
         if(link==null||links[link])return;
         links[link]=true;link.addEventListener(TcpLink.MESSAGE,receive);
      }
      private function install(kind:String):void {
         var original:Emitter=Emitter.arr==null?null:Emitter.arr[kind] as Emitter;
         if(original==null||original===taps[kind])return;
         var self:NativeTextVisuals=this;
         var tap:NativeTextEmitter=new NativeTextEmitter(original,function(p:Object):void{self.observe(p,kind,null);});
         taps[kind]=tap;Emitter.arr[kind]=tap;
      }
      private function installImpact():void {
         var original:Emitter=Emitter.arr==null?null:Emitter.arr["bum"] as Emitter;
         if(original==null||original===taps["bum"])return;
         var tap:NativeTextEmitter=new NativeTextEmitter(original,null,impact);
         taps["bum"]=tap;Emitter.arr["bum"]=tap;
      }
      private function uninstall():void {
         for(var kind:String in taps) {
            var tap:NativeTextEmitter=taps[kind] as NativeTextEmitter;
            // Another owner may have replaced this entry; never overwrite it.
            if(Emitter.arr!=null&&Emitter.arr[kind]===tap)Emitter.arr[kind]=tap.source;
            delete taps[kind];
         }
      }
      private function before(e:Event):void {
         try {
            for(var old:Object in links)if(!old.isOpen){old.removeEventListener(TcpLink.MESSAGE,receive);delete links[old];}
            if(session.mode==Session.HOSTING)for each(var peer:Object in session.peers)watch(peer.link);
            else if(session.mode==Session.CONNECTED)watch(session.link);
            if(!ready()){clear();uninstall();return;}
            var key:String=stamp();if(room!=key){clear();room=key;}
            install("replic");install("replic2");installImpact();
            for(var target:Object in throws) {
               var rec:Object=throws[target];
               if(target.loc!==game.loc || !rec.link.isOpen || !rooms.authority || target.t_throw<=0) {retireThrow(target);continue;}
               rec.before=int(target.t_throw);rec.pending=null;
               var p:Object=RConnectTextAccess.aggregate(target as Unit);
               rec.aggregate=p;rec.text=textOf(p,"numb");rec.life=p==null?0:int(p.liv);
            }
         } catch(error:Error){fault(error);}
      }
      public static function watchThrow(target:Object,link:TcpLink):void {
         if(instance!=null)instance.trackThrow(target as Unit,link);
      }
      private function trackThrow(target:Unit,link:TcpLink):void {
         if(target==null||link==null||!link.isOpen||!ready()||!rooms.authority)return;
         // This can be called before our first ready frame. Establish the same
         // room marker used by observe/receive before creating any state.
         var key:String=stamp();if(room!=key){clear();room=key;}
         retireThrow(target);
         var self:NativeTextVisuals=this,original:Emitter=RConnectTextAccess.emitter(target);
         if(original==null)return;
         var rec:Object={link:link,original:original,before:int(Object(target).t_throw),pending:null,aggregate:null,text:"",life:0};
         rec.aggregate=RConnectTextAccess.aggregate(target);
         rec.text=textOf(rec.aggregate,"numb");rec.life=rec.aggregate==null?0:int(rec.aggregate.liv);
         var tap:NativeTextEmitter=new NativeTextEmitter(original,function(p:Object):void {
            // Native damageWall clears t_throw immediately before native damage.
            // Ordinary projectile hits while the target is still flying do not.
            if(throws[target]===rec && int(Object(target).t_throw)==0 && int(rec.before)>0) {
               rec.pending=p;
            }
         });rec.tap=tap;
         if(RConnectTextAccess.replace(target,original,tap))throws[target]=rec;
      }
      /** In native 1.02, damageWall is the only bum call with null options.
       * It occurs after native damage/aggregate display and before the bounce.
       * Unit-vs-unit impact passes {scale:...} and must not claim this throw. */
      private function impact(loc:Object,x:Number,y:Number,options:Object,part:Object):void {
         if(options!=null||!ready()||!rooms.authority||loc!==game.loc)return;
         var found:Object=null,match:Object=null;
         for(var target:Object in throws) {
            var rec:Object=throws[target];
            if(target.loc!==loc||int(target.t_throw)!=0||int(rec.before)<=0)continue;
            var tx:Number=Number(target.X),ty:Number=Number(target.Y),w:Number=Number(target.scX),h:Number=Number(target.scY);
            var side:Boolean=Math.abs(y-(ty-h/2))<.00001 && (Math.abs(x-(tx-w/2))<.00001||Math.abs(x-(tx+w/2))<.00001);
            var end:Boolean=Math.abs(x-tx)<.00001 && (Math.abs(y-ty)<.00001||Math.abs(y-(ty-h))<.00001);
            if(!side&&!end)continue;
            var aggregate:Object=RConnectTextAccess.aggregate(target as Unit);
            var changed:Boolean=aggregate!=null&&(aggregate!==rec.aggregate||textOf(aggregate,"numb")!=rec.text||int(aggregate.liv)>int(rec.life));
            if(rec.pending==null&&!changed)continue;
            if(found!=null)return; // No attribution by proximity when ambiguous.
            found=target;match={rec:rec,aggregate:changed?aggregate:null};
         }
         if(found==null)return;
         if(match.rec.pending!=null)observe(match.rec.pending,"numb",match.rec.link);
         if(match.aggregate!=null)observe(match.aggregate,"numb",match.rec.link);
         retireThrow(found);
      }
      private function retireThrow(target:Object):void {
         var rec:Object=throws[target];if(rec==null)return;
         RConnectTextAccess.replace(target as Unit,rec.tap,rec.original);delete throws[target];
      }
      private function observe(p:Object,kind:String,link:TcpLink):void {
         if(!ready()||!rooms.authority||p.loc!==game.loc||p.vis==null)return;
         if(room!=stamp()){clear();room=stamp();}
         if(sources[p]==null)sources[p]={id:++nextId,kind:kind,link:link,revision:0,signature:"",life:0};
      }
      private static function textOf(p:Object,kind:String):String {
         if(p==null||p.vis==null)return "";
         try{return kind=="numb"?String(p.vis.numb.text):String(p.vis.text.text.text);}catch(e:*){}
         return "";
      }
      private function capture(p:Object,rec:Object):Object {
         var v:Object=p.vis,scale:Number=Number(game.world.cam.scaleV);
         return {id:rec.id,revision:rec.revision,kind:rec.kind,txt:textOf(p,rec.kind),
            x:Number(p.X),y:Number(p.Y),dx:Number(p.dx),dy:Number(p.dy),ddy:Number(p.ddy),brake:Number(p.brake),
            life:int(p.liv),maxLife:int(p.mliv),move:p.isMove===true,alph:p.isAlph===true,prealph:p.isPreAlph===true,
            frame:int(v.currentFrame),sx:Number(v.scaleX)*scale,sy:Number(v.scaleY)*scale,alpha:Number(v.alpha),
            color:rec.kind=="numb"?uint(v.numb.textColor):uint(v.text.text.textColor)};
      }
      private function send(rec:Object,item:Object):void {
         var p:Object=rooms.stamp({type:"native-text",items:[item]});
         if(rec.link!=null){if(rec.link.isOpen)rec.link.send(p);}
         else if(session.mode==Session.HOSTING && session.server!=null)session.server.broadcast(p);
         else if(session.mode==Session.CONNECTED && session.link!=null)session.link.send(p);
      }
      private function after(e:Event):void {
         try {
            if(!ready())return;
            for(var target:Object in throws) {
               if(int(target.t_throw)==0)retireThrow(target);
            }
            for(var part:Object in sources) {
               var rec:Object=sources[part];
               if(part.loc!==game.loc||!part.in_chain||part.liv<=0||part.vis==null||!rooms.authority) {
                  send(rec,{id:rec.id,revision:++rec.revision,ended:true});delete sources[part];continue;
               }
               var s:Object=capture(part,rec);
               var signature:String=s.txt+":"+(rec.kind=="numb"?s.frame:0)+":"+s.color+":"+s.sx+":"+s.sy;
               if(rec.revision==0 || signature!=rec.signature || int(s.life)>int(rec.life)) {
                  s.revision=++rec.revision;send(rec,s);rec.signature=signature;
               }
               rec.life=s.life;
            }
            // Received Parts advance/expire in the native particle chain. No
            // per-frame walk of historical IDs; inspect a Part only on update.
         }catch(error:Error){fault(error);}
      }
      private function receive(e:NetMessageEvent):void {
         var p:Object=e.data;if(p==null||p.type!="native-text")return;
         try {
            if(!ready()||rooms.authority||!rooms.accepts(p)||!(p.items is Array))return;
            var link:TcpLink=e.target as TcpLink,known:Boolean=link===session.link;
            if(session.mode==Session.HOSTING)for each(var peer:Object in session.peers)if(peer.link===link)known=true;
            if(!known||p.items.length>64)return;
            if(room!=stamp()){clear();room=stamp();}
            for each(var s:Object in p.items)apply(s);
         }catch(error:Error){fault(error);}
      }
      private function apply(s:Object):void {
         var key:String=String(int(s.id)),rev:int=int(s.revision);
         if(int(s.id)<=0||rev<=0)return;
         var rec:Object=received[key];if(rec!=null&&rev<=int(rec.revision))return;
         if(s.ended===true) {
            if(rec!=null)removePart(rec.part);
            received[key]={revision:rev,part:null,ended:true};return;
         }
         if(s.kind!="replic"&&s.kind!="replic2"&&s.kind!="numb")return;
         if(s.kind=="numb"&&game.world.showHit<1)return;
         for each(var field:String in ["x","y","dx","dy","ddy","brake","life","maxLife","frame","sx","sy","alpha","color"])
            if(s[field]===undefined||!isFinite(Number(s[field])))return;
         if(s.life<=0||s.life>1800||s.maxLife<1||String(s.txt).length>2048)return;
         if(rec!=null&&rec.ended===true){rec.revision=rev;return;}
         var part:Object=rec==null?null:rec.part;
         if(part!=null&&(!part.in_chain||part.liv<=0)) {removePart(part);part=null;}
         if(part==null) {
            var emitter:Emitter=Emitter.arr[s.kind] as Emitter;
            if(emitter is NativeTextEmitter)emitter=NativeTextEmitter(emitter).source;
            if(emitter==null)return;
            part=emitter.cast(game.loc,Number(s.x),Number(s.y),{txt:String(s.txt),frame:int(s.frame)});
            if(part==null)return;
            rec=received[key]={revision:rev,part:part,ended:false};
         }
         rec.revision=rev;
         part.X=s.x;part.Y=s.y;part.dx=s.dx;part.dy=s.dy;part.ddy=s.ddy;part.brake=s.brake;
         part.liv=int(s.life);part.mliv=int(s.maxLife);part.isMove=s.move===true;part.isAlph=s.alph===true;part.isPreAlph=s.prealph===true;
         part.vis.x=s.x;part.vis.y=s.y;part.vis.alpha=s.alpha;
         part.vis.scaleX=s.sx/Number(game.world.cam.scaleV);part.vis.scaleY=s.sy/Number(game.world.cam.scaleV);
         var text:Object=s.kind=="numb"?part.vis.numb:part.vis.text.text;
         text.text=String(s.txt);text.textColor=uint(s.color);
      }
      private function removePart(p:Object):void {
         if(p==null)return;try{p.remVisual();if(p.in_chain)p.setNull();}catch(e:*){}
      }
      private function clear():void {
         // All state-producing paths first establish a nonempty room marker.
         // During offline/menu/loading frames an already empty bridge is idle.
         if(room=="")return;
         for(var target:Object in throws)retireThrow(target);
         for each(var rec:Object in received)removePart(rec.part);
         received={};sources=new Dictionary();room="";
      }
      private function fault(e:Error):void {if(faults++<3)Log.d("RConnectText: "+e+" "+e.getStackTrace());}
   }
}
