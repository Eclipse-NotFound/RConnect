package authority {
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.display.DisplayObjectContainer;
   import flash.display.Bitmap;
   import flash.display.PNGEncoderOptions;
   import flash.text.TextField;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.getQualifiedClassName;
   /** Historical enemy cases: actual native AI, real LMG input, then native
    * death. The display oracle reads native pixels before serialization. */
   public final class EnemyVisualProbe extends Probe {
      private var cases:Array=[{cls:"UnitBat",id:"1",tr:1},{cls:"UnitBat",id:"2",tr:2},
         {cls:"UnitVortex",id:"",tr:1},{cls:"UnitMerc",id:"1",tr:1},{cls:"UnitMerc",id:"3",tr:3},
         {cls:"UnitAlicorn",id:"1",tr:1},{cls:"UnitAlicorn",id:"2",tr:2},{cls:"UnitAlicorn",id:"3",tr:3},
         {cls:"UnitZebra",id:"1",tr:1},{cls:"UnitTurret",id:"land",tr:4},{cls:"UnitZombie",id:"1",tr:1},
         {cls:"UnitZombie",id:"1",tr:1},{cls:"UnitTurret",id:"land",tr:4},{cls:"UnitVortex",id:"",tr:1}];
      private var phase:int=-1,begin:int=-1,peerReady:int=-1,ending:int=-1,readySent:int=-1;
      private var ready:Boolean=false,waiting:Boolean=false,killed:Boolean=false,controlled:Boolean=false,report:Object;
      private var enemy:Object,target:PlayerActor,initialHP:Number,initialShield:Number,lowestHP:Number,lowestShield:Number;
      private var targetHP:Number,lowestTargetHP:Number,acquired:Boolean=false,shots:uint=0,playerShots:uint=0;
      private var refs:Object={},counts:Object={},stances:Object={},alphas:Object={},shields:int=0;
      private var enemyKey:uint=0,lastAimLog:int=-1;
      private var nextBurstAt:int=190,burstUntil:int=-1;
      public function EnemyVisualProbe(a:NativeAccess,h:Boolean){super(a,h);}
      override public function prepare():void{super.prepare();Timing.enabled=true;}
      override public function message(v:Object):void {
         if(host && v.type=="enemy-ready")peerReady=v.phase;
         if(host && v.type=="enemy-report")report=v;
         if(!host && v.type=="enemy-phase") {
            phase=v.phase;enemyKey=v.key;begin=-1;ending=-1;lastAimLog=-1;nextBurstAt=190;burstUntil=-1;
            Timing.reset();Log.write("enemy-protocol",{phase:phase,event:v.type,tick:RConnectMod.instance.replica.lastTick});
            counts={samples:0,missing:0,pose:0,pixels:0,viewMasks:0,body:0,weapon:0,hpbar:0,projectile:0,effect:0,first:[]};
         }
         if(!host && v.type=="enemy-go"){begin=v.tick;Log.write("enemy-protocol",{phase:phase,event:v.type,begin:begin,tick:RConnectMod.instance.replica.lastTick});}
         if(!host && v.type=="enemy-ref")refs[v.tick]=v;
         if(!host && v.type=="enemy-end")ending=v.tick;
         if(!host && v.type=="enemy-finish")finish();
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];
         var tick:int=host?session==null?0:session.runtime.tick:RConnectMod.instance.replica==null?0:RConnectMod.instance.replica.lastTick;
         var elapsed:int=tick-begin;
         if(phase<0 || begin<0 || (host?0:1)!=phase%2 || elapsed<70 || elapsed>=250)return frame;
         var x:Number,y:Number;
         if(host){x=enemy.X;y=enemy.Y-enemy.scY*.6;}
         else {
            var f:Object=RConnectMod.instance.replica.lastFrame;
            if(f==null)return frame;
            for each(var u:Object in f.scene.units)if(u.key==enemyKey){x=u.fields.X;y=u.fields.Y-u.fields.scY*.6;break;}
         }
         if(isFinite(x) && isFinite(y)) {
            frame.aimX=x;frame.aimY=y;
            // Native LMG recoil raises sustained fire above a small airborne
            // target. Keep real full-auto in the AI window; let recoil settle
            // between aimed bursts in the separate collision/damage check.
            if(elapsed>=190 && elapsed<245 && elapsed>=nextBurstAt){burstUntil=elapsed+2;nextBurstAt=elapsed+20;}
            // Generate a real press/release even if multiple confirmations
            // arrive between local frames. A two-host-tick modulo window
            // could be skipped completely without ever issuing a shot.
            if(elapsed>=80 && elapsed<155 || elapsed>=190 && elapsed<245 && elapsed<burstUntil)frame.buttons=Commands.FIRE;
         }
         if(elapsed>=180 && elapsed<245 && int(elapsed/10)!=lastAimLog) {
            lastAimLog=int(elapsed/10);
            Log.write("enemy-aim-input",{phase:phase,elapsed:elapsed,tick:tick,begin:begin,seq:frame.seq,
               key:enemyKey,aim:[frame.aimX,frame.aimY],buttons:frame.buttons,
               selected:host || u==null?null:{key:u.key,id:u.fields.id,x:u.fields.X,y:u.fields.Y,hp:u.fields.hp,sost:u.fields.sost,player:u.fields.player},
               found:isFinite(x)&&isFinite(y)});
         }return frame;
      }
      private function start(session:HostSession,index:int):void {
         phase=index;begin=-1;peerReady=-1;waiting=false;killed=false;controlled=false;report=null;acquired=false;stances={};alphas={};shields=0;
         nextBurstAt=190;burstUntil=-1;
         Timing.reset();
         // A native enemy may legitimately keep its first visible target.
         // Separate the non-target pony with an opaque wall, so this scenario
         // tests recognition of the intended player rather than AI preference.
         var fy:Number=ProbeArena.floor(access.world.loc,10),spec:Object=cases[index];target=session.actors[index%2];
         for each(var actor:PlayerActor in session.actors) {
            actor.unit.setLocPos(actor===target?650:180,fy);actor.unit.dx=actor.unit.dy=0;
            actor.unit.obs=actor.unit.maxObs;
            access.scope.run(actor.context,function():void {
               actor.unit.pers.healAll();actor.unit.pers.setParameters();
               actor.unit.invulner=false;actor.unit.hp=actor.unit.maxhp;
            });
            actor.unit.currentWeapon.hold=300;actor.unit.invent.items[actor.unit.currentWeapon.ammo].kol=1000;
            actor.unit.currentWeapon.hp=actor.unit.currentWeapon.maxhp;
         }
         var Type:Class=access.definition("fe.unit."+spec.cls),placement:XML=<unit turn="-1" dig="0"/>;placement.@tr=spec.tr;
         enemy=new Type(spec.id,10,placement,null);
         enemy.putLoc(access.world.loc,900,fy-(enemy.isFly?95:0));access.world.loc.units.push(enemy);access.world.loc.addObj(enemy);
         enemy.disabled=true;enemy.hp=10000;enemy.maxhp=11000;enemy.lootIsDrop=true;enemy.xp=0;
         enemy.storona=-1;
         initialHP=lowestHP=enemy.hp;initialShield=lowestShield=enemy.shithp;targetHP=lowestTargetHP=target.unit.hp;
         shots=session.runtime.spawnsFor(enemy);
         playerShots=session.runtime.spawnsFor(target.unit);
         enemyKey=session.sceneId(enemy);
         if(index==0)nativePerceptionBoundary(session);
         session.link.send({type:"enemy-phase",phase:phase,key:enemyKey});Log.write("enemy-case",{phase:phase,cls:spec.cls,tr:spec.tr,player:target.id});
      }
      private function nativePerceptionBoundary(session:HostSession):void {
         var Unit:Class=access.definition("fe.unit.Unit"),hook:Function=Unit["rconnectFindTarget"];
         var fields:Array=["celUnit","priorUnit","celX","celY","celDX","celDY","oduplenie"],saved:Object={},expected:Object={};
         for each(var key:String in fields)saved[key]=enemy[key];
         try {
            enemy.celUnit=enemy.priorUnit=target.unit;enemy.celX=314;enemy.celY=271;enemy.celDX=-586;enemy.celDY=-100;enemy.oduplenie=60;
            var initial:Object={};for each(key in fields)initial[key]=enemy[key];
            Unit["rconnectFindTarget"]=null;
            var nativeResult:Boolean=Boolean(enemy.findCel(true));
            for each(key in fields)expected[key]=enemy[key];
            for each(key in fields)enemy[key]=initial[key];
            Unit["rconnectFindTarget"]=hook;
            var actualResult:Boolean=Boolean(enemy.findCel(true)),equal:Boolean=nativeResult==actualResult;
            for each(key in fields)equal=equal && enemy[key]===expected[key];
            check(equal,"real native stunned enemy retains identical target state with the B perception bridge",{nativeResult:nativeResult,actualResult:actualResult});
         }finally {
            Unit["rconnectFindTarget"]=hook;
            for each(key in fields)enemy[key]=saved[key];
         }
      }
      private function digest(bmp:BitmapData):uint {
         var h:uint=2166136261;for each(var pixel:uint in bmp.getVector(bmp.rect))h=uint((h^pixel)*16777619);return h;
      }
      private function hash(clip:DisplayObject,bounds:Array,unmasked:Boolean=false):uint {
         var bmp:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);
         var mask:DisplayObject=clip.mask;
         try {if(unmasked)clip.mask=null;bmp.draw(clip,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));}
         finally {if(unmasked)clip.mask=mask;}
         var h:uint=digest(bmp);
         bmp.dispose();return h;
      }
      private function picture(clip:DisplayObject,bounds:Array,name:String):void {
         var bmp:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);bmp.draw(clip,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));
         var stream:FileStream=new FileStream();stream.open(File.applicationStorageDirectory.resolvePath(name),FileMode.WRITE);
         stream.writeBytes(bmp.encode(bmp.rect,new PNGEncoderOptions()));stream.close();bmp.dispose();
      }
      private function sample(clip:DisplayObject,kind:String,key:uint,slot:int=-1):Object {
         if(clip==null || clip.parent==null || !clip.visible || clip.alpha<=0)return null;
         var r:Rectangle=clip.getBounds(clip);if(r.width<=0 || r.height<=0)return null;
         if(r.width>256 || r.height>256)r=new Rectangle(r.x+r.width/2-128,r.y+r.height/2-128,256,256);
         var bounds:Array=[Math.floor(r.x),Math.floor(r.y),Math.max(1,Math.ceil(r.right)-Math.floor(r.x)),Math.max(1,Math.ceil(r.bottom)-Math.floor(r.y))];
         var m:Matrix=clip.transform.matrix,s:Object={kind:kind,key:key,slot:slot,clip:getQualifiedClassName(clip),bounds:bounds,hash:hash(clip,bounds),
            tree:kind=="body" || kind=="hpbar" || getQualifiedClassName(clip)=="visualNumb"?structure(clip):null,
            m:[m.a,m.b,m.c,m.d,m.tx,m.ty],alpha:clip.alpha,visible:clip.visible,frame:clip is MovieClip?MovieClip(clip).currentFrame:0};
         s.masked=clip.mask!=null;s.artHash=s.masked?hash(clip,bounds,true):s.hash;
         if(kind=="body" && (phase==2 || killed) || kind=="hpbar" && killed) {
            s.picture="enemy-"+phase+"-"+RConnectMod.instance.host.runtime.tick+"-"+kind+".png";picture(clip,bounds,s.picture);
         }return s;
      }
      private function structure(clip:DisplayObject,depth:int=0):Object {
         if(clip==null)return {removed:true};
         var s:Object={cls:getQualifiedClassName(clip),name:clip.name,frame:clip is MovieClip?MovieClip(clip).currentFrame:0,
            alpha:clip.alpha,visible:clip.visible,children:[]},c:DisplayObjectContainer=clip as DisplayObjectContainer;
         var m:Matrix=clip.transform.matrix,color:Object=clip.transform.colorTransform;
         s.m=[m.a,m.b,m.c,m.d,m.tx,m.ty];s.c=[color.redMultiplier,color.greenMultiplier,color.blueMultiplier,color.alphaMultiplier,color.redOffset,color.greenOffset,color.blueOffset,color.alphaOffset];
         s.filters=clip.filters;s.cache=clip.cacheAsBitmap;
         if(clip is TextField)s.text=NativeTextChecks.describe(clip as TextField);
         if(clip is Bitmap && Bitmap(clip).bitmapData!=null){s.pixels=digest(Bitmap(clip).bitmapData);s.w=Bitmap(clip).bitmapData.width;s.h=Bitmap(clip).bitmapData.height;}
         if(c!=null && depth<12)for(var i:int=0;i<c.numChildren;i++)s.children.push(structure(c.getChildAt(i),depth+1));
         return s;
      }
      private function source(session:HostSession):void {
         var elapsed:int=session.runtime.tick-begin;
         if(controlled && (elapsed==205 || elapsed==228)) {
            var bullets:Array=[],bullet:Object=enemy.loc.firstObj;
            while(bullet!=null) {
               if(NativeAccess.get(bullet,"owner")===target.unit && NativeAccess.get(bullet,"begx")!=null && bullets.length<12)
                  bullets.push({id:session.runtime.projectileId(bullet),x:bullet.X,y:bullet.Y,dx:bullet.dx,dy:bullet.dy,
                     begin:[bullet.begx,bullet.begy],damage:NativeAccess.get(bullet,"damage"),active:bullet.in_chain});
               bullet=bullet.nobj;
            }
            var gun:Object=target.unit.currentWeapon;
            Log.write("enemy-impact-window",{phase:phase,elapsed:elapsed,player:target.id,
               aim:[target.unit.celX,target.unit.celY],position:[target.unit.X,target.unit.Y],
               input:{aim:[session.inputs[target.id].aimX,session.inputs[target.id].aimY],buttons:session.inputs[target.id].buttons,
                  seq:session.inputs[target.id].consumed,lastAt:session.inputs[target.id].lastAt},
               gun:{x:gun.X,y:gun.Y,rot:gun.rot,muzzle:[gun.bulX,gun.bulY],hold:gun.hold,shoot:gun.is_shoot},
               enemy:{box:[enemy.X1,enemy.Y1,enemy.X2,enemy.Y2],hp:enemy.hp,shield:enemy.shithp,skin:enemy.skin,
                  invulner:enemy.invulner,stun:enemy.stun},bullets:bullets});
         }
         if(begin<0 || waiting || (session.runtime.tick-begin)%3!=0)return;
         var samples:Array=[],key:uint=session.sceneId(enemy),s:Object;
         for each(var kind:String in ["body","hpbar"]) {
            s=sample(kind=="body"?enemy.vis:enemy.hpbar,kind,key);if(s!=null)samples.push(s);
         }
         var slot:int=0;
         for each(var gun:Object in enemy.childObjs)if(gun!=null && NativeAccess.get(gun,"kol_shoot")!=null) {
            s=sample(gun.vis,"weapon",key,slot++);if(s!=null)samples.push(s);
         }
         var o:Object=enemy.loc.firstObj,perKind:Object={};
         while(o!=null) {
            if(o!==enemy && !NativeAccess.get(o,"player",false) && enemy.loc.units.indexOf(o)<0) {
               kind=NativeAccess.get(o,"begx")!=null?"projectile":"effect";
               if(uint(perKind[kind])<4) {
                  s=sample(o.vis,kind,kind=="projectile"?session.runtime.projectileId(o):session.sceneId(o));
                  if(s!=null){samples.push(s);perKind[kind]=uint(perKind[kind])+1;}
               }
            }
            o=o.nobj;
         }
         session.link.send({type:"enemy-ref",phase:phase,tick:session.runtime.tick,samples:samples});
      }
      private function applied(frame:Object):void {
         var ref:Object=refs[frame.tick];if(ref==null || ref.phase!=phase)return;delete refs[frame.tick];
         var client:ClientReplica=RConnectMod.instance.replica;
         for each(var s:Object in ref.samples) {
            ++counts.samples;counts[s.kind]=uint(counts[s.kind])+1;
            var d:DisplayObject,rec:Object=client.scene.units[s.key];
            if(s.kind=="body")d=rec==null?null:rec.unit.vis;
            else if(s.kind=="hpbar")d=rec==null?null:rec.unit.hpbar;
            else if(s.kind=="weapon")d=rec==null || rec.weapons[s.slot]==null?null:rec.weapons[s.slot].vis;
            else if(s.kind=="projectile")d=client.projectileDisplay(s.key);
            else d=client.scene.effects.records[s.key]==null?null:client.scene.effects.records[s.key].clip;
            var issue:String="";
            if(d==null || d.parent==null || d.stage==null){++counts.missing;issue="missing";}
            else {
               var m:Matrix=d.transform.matrix,actual:Array=[m.a,m.b,m.c,m.d,m.tx,m.ty],wrong:Boolean=false;
               for(var i:int=0;i<6;i++)if(Math.abs(actual[i]-s.m[i])>.002)wrong=true;
               if(wrong || Math.abs(d.alpha-s.alpha)>.001 || d.visible!=s.visible || d is MovieClip && MovieClip(d).currentFrame!=s.frame){++counts.pose;issue="pose";}
               if(hash(d,s.bounds)!=uint(s.hash)) {
                  // RV deliberately clips the two listeners' bodies/bars with
                  // different view masks. Compare artwork with only that mask
                  // temporarily removed; preserve the masked difference too.
                  if((s.masked || d.mask!=null) && hash(d,s.bounds,true)==uint(s.artHash))++counts.viewMasks;
                  else {++counts.pixels;issue="pixels";}
               }
            }
            if(issue!="" && counts.first.length<4){
               if(d!=null && s.picture!=null)picture(d,s.bounds,s.picture);
               counts.first.push({kind:s.kind,key:s.key,issue:issue,source:s,actual:d==null?null:structure(d)});
            }
         }
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.displayFrame==null)return;
            if(!ready){ready=true;replica.confirmed=applied;}
            if(phase>=0 && readySent!=phase){readySent=phase;RConnectMod.instance.link.send({type:"enemy-ready",phase:phase});}
            if(ending>=0 && replica.displayFrame.tick>=ending) {
               Log.write("enemy-timings",{phase:phase,timings:Timing.snapshot()});
               check(counts.body>10,"native enemy body visible through state transitions phase "+phase,counts);
               check(counts.missing==0 && counts.pose==0,"enemy attachment, healthbar, cloak and weapon poses match phase "+phase,counts);
               check(counts.pixels==0,"enemy artwork, shields and attack effects match native pixels phase "+phase,counts);
               RConnectMod.instance.link.send({type:"enemy-report",phase:phase});ending=-1;
            }return;
         }
         if(session==null || !session.active)return;
         if(!ready){ready=true;var publish:Function=session.runtime.afterStep;session.runtime.afterStep=function():void{source(session);publish();};start(session,0);return;}
         if(begin<0 && peerReady==phase){begin=session.runtime.tick;enemy.disabled=false;enemy.addVisual();enemy.visDetails();session.link.send({type:"enemy-go",tick:begin});}
         if(begin<0)return;
         if(!killed){lowestHP=Math.min(lowestHP,enemy.hp);lowestShield=Math.min(lowestShield,enemy.shithp);lowestTargetHP=Math.min(lowestTargetHP,target.unit.hp);acquired=acquired || enemy.celUnit===target.unit;}
         if(!controlled && target.unit.hp>0 && target.unit.hp<target.unit.maxhp*.5)
            access.scope.run(target.context,function():void {target.unit.heal(target.unit.maxhp-target.unit.hp);});
         stances[enemy.animState]=true;alphas[String(enemy.vis.alpha)]=true;if(enemy.shithp>0)++shields;
         if(!controlled && session.runtime.tick-begin>=180) {
            controlled=true;
            check(acquired,"native enemy detects intended player phase "+phase,{player:target.id,cls:cases[phase].cls});
            Log.write("enemy-native-summary",{phase:phase,targetHP:[targetHP,lowestTargetHP],shots:session.runtime.spawnsFor(enemy)-shots,
               playerShots:session.runtime.spawnsFor(target.unit)-playerShots,gun:NativeFields.capture(target.unit.currentWeapon),
               enemy:NativeFields.capture(enemy),player:NativeFields.capture(target.unit),stances:stances,alphas:alphas,shieldFrames:shields,
               tactics:session.tactics==null?null:session.tactics.inspect(enemy.loc)});
            // Natural evasive motion can correctly dodge every shot, and an
            // alicorn may raise a shield after the initial zero-shield sample.
            // Separately prove native impact damage in a controlled firing
            // lane; the preceding live AI/attack window remains independent.
            var fy:Number=Math.floor((enemy.loc.limY-120)/40)*40-1;
            enemy.stun=120;enemy.dx=enemy.dy=0;enemy.shithp=0;enemy.setPos(900,fy-(enemy.isFly?70:0));
            enemy.fixed=true;
            target.unit.setLocPos(650,fy);target.unit.dx=target.unit.dy=0;target.unit.stun=0;target.unit.levit=0;
            target.unit.controlOn();target.unit.invulner=true;initialHP=enemy.hp;lowestHP=enemy.hp;
         }
         if(!killed && session.runtime.tick-begin>=260) {
            killed=true;
            Log.write("enemy-impact-summary",{phase:phase,enemy:NativeFields.capture(enemy),player:NativeFields.capture(target.unit),
               gun:NativeFields.capture(target.unit.currentWeapon),input:{buttons:session.inputs[target.id].buttons,ack:session.inputs[target.id].consumed},
               playerShots:session.runtime.spawnsFor(target.unit)-playerShots});
            check(lowestHP<initialHP,"native player LMG causes real impact damage on the controlled enemy phase "+phase,{hp:[initialHP,lowestHP]});
            enemy.fixed=false;
            access.scope.run(target.context,function():void{
               enemy.invulner=false;enemy.shithp=0;
               if(phase%2==0)enemy.damage(1000000,1,null,false);
               else enemy.die(0);
            });
         }
         if(!waiting && session.runtime.tick-begin>=320){waiting=true;check(enemy.hp<=0 || enemy.sost>=3,"native enemy death occurs phase "+phase);Log.write("enemy-timings",{phase:phase,timings:Timing.snapshot()});session.link.send({type:"enemy-end",phase:phase,tick:session.runtime.tick});}
         if(waiting && report!=null){if(phase+1<cases.length)start(session,phase+1);else {session.link.send({type:"enemy-finish"});finish();}}
      }
   }
}
