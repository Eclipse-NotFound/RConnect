package authority {
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.MovieClip;
   import flash.display.BitmapData;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileStream;
   import flash.filesystem.FileMode;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;
   import flash.utils.getQualifiedClassName;
   import flash.utils.getTimer;
   /** Real player inputs, native fuse/impact execution, independent display
    * samples taken before serialization and checked after discrete playback. */
   public final class WeaponProbe extends Probe {
      private var kind:String,cases:Array,phase:int=-1,begin:int=-1,peerReady:int=-1,ending:int=-1;
      private var fy:Number=0,aimX:Number=0,aimY:Number=0,ready:Boolean=false,waiting:Boolean=false;
      private var gun:Object,shooter:PlayerActor,initialAmmo:Number=0,initialMana:Number=0,initialShots:uint=0;
      private var nativeEffects:Object={},references:Object={},counts:Object={},report:Object;
      private var nativeSamples:int=0,nativeQuick:int=0,sourcePixels:int=0,readySent:int=-1;
      private var samplePictures:Object={};
      private var target:Object,targetHP:Number=0;
      private var observedMasks:Dictionary=new Dictionary(true);
      private var inkArea:Rectangle,inkBefore:Vector.<uint>,inkChanges:int=0,inkHoles:int=0;
      private var inkRebuild:Boolean=false,inkRedraw:Boolean=false;
      private var friendly:Boolean=false,friendlyOpened:Boolean=false;
      private var friendlyStats:Object;
      private var firstHit:Object;
      private function observeFriendlyHits(session:HostSession):void {
         var Unit:Class=access.definition("fe.unit.Unit"),Player:Class=access.definition("fe.unit.UnitPlayer");
         var policy:Function=Unit["rconnectHitPolicy"],damage:Function=Player["rconnectDamage"];
         Unit["rconnectHitPolicy"]=function(source:Object,victim:Object,nativeAllowed:Boolean,category:String):Boolean {
            var allowed:Boolean=policy(source,victim,nativeAllowed,category);
            if(shooter!=null && source===shooter.unit && victim===target && begin>=0 && !waiting) {
               var key:String=friendlyOpened?"on":"off";if(allowed)friendlyStats[key]++;
            }
            return allowed;
         };
         Player["rconnectDamage"]=function(victim:Object,amount:Number,type:int,bullet:Object,periodic:Boolean):Number {
            var record:Boolean=victim===target && begin>=0 && !waiting;
            var before:Number=victim.hp,result:Number=damage(victim,amount,type,bullet,periodic);
            if(record) {
               ++friendlyStats.damage;friendlyStats.paid+=before-victim.hp;
               if(firstHit==null)firstHit={elapsed:session.runtime.tick-begin,enabled:session.combat.enabled,amount:amount,type:type,
                  before:before,after:victim.hp,result:result,weapon:bullet==null || bullet.weap==null?null:bullet.weap.id,
                  invulner:victim.invulner,armor:victim.armor,magicArmor:victim.marmor,skin:victim.skin,shield:victim.shithp,
                  base:victim.loc.base,train:victim.loc.train,regen:victim.pers.regenFew,heal:victim.healhp,
                  pos:[victim.X,victim.Y],shooter:[shooter.unit.X,shooter.unit.Y]};
            }
            return result;
         };
      }
      public function WeaponProbe(a:NativeAccess,h:Boolean,kind:String,friendly:Boolean=false,only:Array=null) {
         super(a,h);this.kind=kind;this.friendly=friendly;
         cases=kind=="explosives"?["acidgr","plagr","impgr","cryogr","gasgr","molotov","hgren","grenade","dinamit","spgren"]:
            kind=="magic"?["telebul","ice","lightning","mray","fireball","eclipse"]:
            kind=="guns"?["shotgun","lasr","plar","bfg","flamer","cflamer","gatl","sawgun","mlau","bel","glau","aglau"]:
            kind=="melee"?["bat","spear","ripper","lsword","bsaw"]:[0,85,95,160,180,-95,-160];
         if(kind=="terrain")cases=["lmg","plam","prism"];
         if(kind=="explosives")Timing.enabled=true;
         if(only!=null){cases=only.concat();Timing.enabled=true;}
      }
      override public function message(value:Object):void {
         if(host && value.type=="weapon-ready")peerReady=value.phase;
         if(host && value.type=="weapon-report")report=value;
         if(!host && value.type=="weapon-phase") {
            phase=value.phase;begin=-1;ending=-1;aimX=value.x;aimY=value.y;
            counts={samples:0,missing:0,pose:0,pixels:0,quick:0,projectile:0,effect:0,body:0,weapon:0,inkSamples:0,inkWrong:0,hpRedrawBase:-1,hpRedraws:0,first:[]};
         }
         if(!host && value.type=="weapon-go")begin=value.tick;
         if(!host && value.type=="weapon-reference")references[value.tick]=value;
         if(!host && value.type=="weapon-phase-end")ending=value.tick;
         if(!host && value.type=="weapon-finish")finish();
      }
      override public function input(frame:Object,session:HostSession):Object {
         frame.buttons=0;frame.actions=[];frame.aimX=aimX;frame.aimY=aimY;
         var tick:int=host?session==null?0:session.runtime.tick:RConnectMod.instance.replica==null?0:RConnectMod.instance.replica.lastTick;
         // Force one real host-side lease lapse while the joining player still
         // physically holds the acid grenade key. It must not start a second
         // throw when fresh input resumes; the 500ms policy itself is unchanged.
         if(host && session!=null && kind=="explosives" && phase==1 && begin>=0 && tick-begin>=35 && tick-begin<40)
            session.inputs[1].lastAt=getTimer()-600;
         var elapsed:int=tick-begin;
         if(friendly && begin>=0 && phase>=0) {
            var other:Object=host?session.actors[1-phase%2].unit:RConnectMod.instance.replica.lastFrame.players[1-phase%2];
            frame.aimX=host?other.X:other.x;frame.aimY=(host?other.Y:other.y)-35;
            if(cases[int(phase/2)]=="spear")frame.aimX-=host?gun.dlina:aimX;
         }
         if(begin>=0 && !waiting && phase>=0 && (host?0:1)==phase%2 &&
            (friendly?(elapsed>=8 && elapsed<65 || elapsed>=105 && elapsed<160):elapsed>=8 && elapsed<65))
            frame.buttons=kind=="explosives"?Commands.GRENADE:kind=="magic"?Commands.MAGIC:Commands.FIRE;
         return frame;
      }
      private function start(session:HostSession,index:int):void {
         phase=index;begin=-1;peerReady=-1;waiting=false;report=null;nativeEffects={};nativeSamples=nativeQuick=sourcePixels=0;
         inkBefore=null;inkChanges=inkHoles=0;inkRebuild=inkRedraw=false;
         friendlyOpened=false;firstHit=null;
         friendlyStats={off:0,on:0,minOff:Number.POSITIVE_INFINITY,minOn:Number.POSITIVE_INFINITY,damage:0,paid:0,shots:0};
         if(friendly)session.combat.enabled=false;
         fy=ProbeArena.floor(access.world.loc,25);shooter=session.actors[phase%2];
         for each(var actor:PlayerActor in session.actors)access.scope.run(actor.context,function():void {
            var g:Object=actor.unit;
            if(g.throwWeapon!=null)g.throwWeapon.remVisual();if(g.magicWeapon!=null)g.magicWeapon.remVisual();
            g.throwWeapon=g.magicWeapon=null;
            g.setLocPos(400+actor.id*180,fy);g.dx=g.dy=0;g.invulner=true;
            g.pers.setForcLevel(60);
            for(var key:String in g.pers.skills)g.pers.skills[key]=!friendly || ["melee","smallguns","repair","energy","explosives","magic","tele"].indexOf(key)>=0?100:0;
            g.pers.setParameters();
            g.mana=g.maxmana=10000;g.pers.manaHP=10000;g.pers.spellsPoss=1;
            g.currentWeapon.hold=300;g.invent.items[g.currentWeapon.ammo].kol=1000;
         });
         access.scope.run(shooter.context,function():void {
            var g:Object=shooter.unit,Weapon:Class=access.definition("fe.weapon.Weapon");
            if(kind=="angles")gun=g.currentWeapon;
            else {
               var id:String=cases[int(phase/2)];gun=Weapon["create"](g,id,0);gun.setPers(g,g.pers);
               gun.hp=gun.maxhp;gun.respect=0;gun.loc=g.loc;gun.setNull();gun.addVisual2();
               g.invent.weapons[id]=gun;
               if(kind=="explosives"){g.throwWeapon=gun;g.invent.items[gun.ammo].kol=20;g.invent.fav[29]=id;}
               else if(kind=="magic"){g.magicWeapon=gun;g.invent.fav[30]=id;}
               else {
                  g.currentWeapon.remVisual();g.currentWeapon=gun;g.childObjs[0]=gun;g.invent.cWeaponId=id;gun.addVisual();
                  gun.hold=gun.holder;if(gun.ammo!="")g.invent.items[gun.ammo].kol=1000;
               }
               if(kind=="explosives" || kind=="magic")check(g.currentWeapon!==gun && g.childObjs.indexOf(gun)<0,"native quick slot remains outside equipped weapon "+id+" owner "+shooter.id);
            }
            initialAmmo=gun.ammo==""?0:g.invent.items[gun.ammo].kol+gun.hold;
            initialMana=g.mana;initialShots=session.runtime.spawnsByPlayer[shooter.id];
         });
         var angle:Number=kind=="angles"?Number(cases[int(phase/2)])*Math.PI/180:0;
         aimX=shooter.unit.X+Math.cos(angle)*300;aimY=fy-45+Math.sin(angle)*300;
         if(friendly) {
            target=session.actors[1-shooter.id].unit;
            for each(actor in session.actors)access.scope.run(actor.context,function():void {
               actor.unit.pers.healAll();actor.unit.pers.setParameters();actor.unit.hp=actor.unit.maxhp;
               actor.unit.remEffect("freezing");actor.unit.remEffect("burning");actor.unit.remEffect("poison");
               // Native bleeding is a scalar, not an Effect named "cut".
               // Do not carry the preceding weapon's wound into the next
               // independent off/on pair.
               actor.unit.cut=actor.unit.poison=actor.unit.healhp=0;
            });
            shooter.unit.setLocPos(400,fy);target.setLocPos(400+(kind=="melee"?95:280),fy);
            shooter.unit.dx=shooter.unit.dy=target.dx=target.dy=0;
            target.invulner=false;target.skin=0;targetHP=target.hp;
            // These pairs verify teammate eligibility, native collision and
            // damage ownership, not a random dodge roll. Two single shots
            // can both legitimately miss a character with 20% evasion. Use
            // the same stationary, non-dodging target as the enemy cases;
            // leave the real collision, bullet and damage code untouched.
            target.dexter=target.dexterPlus=target.dodge=target.dodgePlus=0;
            check(target.allVulnerMult>0,"friendly fixture uses a damageable native character without survival-100 immunity "+gun.id+" owner "+shooter.id,
               {multiplier:target.allVulnerMult});
            // Keep real damage/eligibility code, but use low fixture damage so
            // each negative/positive pair can finish without respawn effects.
            gun.damage=Math.min(5,gun.damage);gun.damageExpl=Math.min(5,gun.damageExpl);gun.damMult=1;gun.critCh=0;
            aimX=gun.id=="spear"?gun.dlina:target.X;aimY=target.Y-35;
         }
         if(kind=="terrain") {
            var room:Object=shooter.unit.loc,row:int=int((fy+1)/40);
            room.destroyOn=true;room.tileSpawn=0;
            for(var wy:int=row-5;wy<row;wy++) {
               var tile:Object=room.space[25][wy];tile.front="A";tile.opac=1;tile.hp=20000;
               tile.mat=gun.id=="lmg"?3:2;tile.indestruct=gun.id!="plam";tile.thre=0;tile.fake=false;
            }
            gun.destroy=30;gun.damageExpl=0;gun.critCh=0;gun.dopCh=0;gun.precision=gun.deviation=gun.recoil=gun.recoilUp=0;
            aimX=1080;inkArea=new Rectangle(960,Math.floor(fy-120),128,128);
            // Location.isRebuild only recalculates water/collision. The fixture
            // replaced tiles directly, so draw its new native wall before the
            // baseline; otherwise phase zero compares an old random room bitmap
            // against the correctly reconstructed client wall until tick 125.
            access.world.grafon.drawLoc(room);
         }
         if(!friendly && (kind=="melee" || kind=="guns")) {
            var Enemy:Class=access.definition("fe.unit.UnitZombie");target=new Enemy("1",10,<unit tr="1" dig="0"/>,null);
            target.putLoc(access.world.loc,shooter.unit.X+(kind=="melee"?95:280),fy);access.world.loc.units.push(target);
            // Native target/collision/damage, held still by omitting its AI step.
            target.hp=target.maxhp=100000;target.skin=target.armor=target.dexter=target.dodge=0;
            target.invulner=target.disabled=false;target.doop=true;target.lootIsDrop=true;target.xp=0;
            target.addVisual();target.setVisPos();target.animate();targetHP=target.hp;aimX=target.X;aimY=target.Y-target.scY*.5;
            // A spear's cursor positions its handle; the damaging tip extends
            // a further dlina pixels. Centre the real thrust on the target,
            // rather than putting the entire stab beyond its collision box.
            if(gun.id=="spear")aimX-=gun.dlina;
         }
         session.link.send({type:"weapon-phase",phase:phase,x:aimX,y:aimY});
         Log.write("weapon-phase",{phase:phase,id:gun.id,owner:shooter.id,kind:kind});
         if(Timing.enabled)Timing.reset();
      }
      private function fingerprint(clip:DisplayObject,bounds:Array):uint {
         var measured:int=Timing.start();
         var bitmap:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);
         bitmap.draw(clip,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));
         var digest:uint=2166136261;
         for each(var pixel:uint in bitmap.getVector(bitmap.rect))digest=uint((digest^pixel)*16777619);
         bitmap.dispose();Timing.end("probe.weaponPixels",measured);
         if(Timing.enabled && getTimer()-measured>=100)Log.write("slow-weapon-pixels",{clip:getQualifiedClassName(clip),ms:getTimer()-measured,bounds:bounds});
         return digest;
      }
      private function picture(clip:DisplayObject,bounds:Array,name:String):void {
         var bitmap:BitmapData=new BitmapData(bounds[2],bounds[3],true,0);
         bitmap.draw(clip,new Matrix(1,0,0,1,-bounds[0],-bounds[1]));
         var file:File=File.applicationStorageDirectory.resolvePath(name),stream:FileStream=new FileStream();
         stream.open(file,FileMode.WRITE);stream.writeBytes(bitmap.encode(bitmap.rect,new PNGEncoderOptions()));stream.close();bitmap.dispose();
         Log.write("weapon-picture",{path:file.nativePath});
      }
      private function structure(clip:DisplayObject,path:String="",out:Object=null,depth:int=0):Object {
         if(out==null)out={};var c:Object=clip.transform.colorTransform,m:Matrix=clip.transform.matrix;
         out[path]={cls:getQualifiedClassName(clip),name:clip.name,f:clip is MovieClip?MovieClip(clip).currentFrame:0,
            v:clip.visible,a:clip.alpha,m:[m.a,m.b,m.c,m.d,m.tx,m.ty],
            c:[c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset]};
         var container:DisplayObjectContainer=clip as DisplayObjectContainer;
         if(container!=null && depth<12)for(var i:int=0;i<container.numChildren;i++)structure(container.getChildAt(i),path+"/"+i,out,depth+1);
         return out;
      }
      private function sample(clip:DisplayObject,category:String,layer:int):Object {
         if(clip==null || clip.parent==null || !clip.visible || clip.alpha<=0)return null;
         var bounds:Rectangle=clip.getBounds(clip);
         if(category=="body")bounds=new Rectangle(-65,-130,130,150);
         if(bounds.width<=0 || bounds.height<=0)return null;
         // Large explosions have native surfaces bigger than a character. Take
         // a bounded central crop instead of excluding the effect altogether.
         if(bounds.width>256 || bounds.height>256)bounds=new Rectangle(bounds.x+bounds.width/2-64,bounds.y+bounds.height/2-64,128,128);
         var r:Array=[Math.floor(bounds.x),Math.floor(bounds.y),Math.max(1,Math.ceil(bounds.right)-Math.floor(bounds.x)),Math.max(1,Math.ceil(bounds.bottom)-Math.floor(bounds.y))];
         var m:Matrix=clip.transform.matrix;
         return {kind:category,layer:layer,clip:getQualifiedClassName(clip),x:clip.x,y:clip.y,
            matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],frame:clip is MovieClip?MovieClip(clip).currentFrame:0,
            bounds:r,hash:fingerprint(clip,r)};
      }
      private function source(session:HostSession):void {
         if(friendly && begin>=0 && !waiting) {
            var field:String=friendlyOpened?"minOn":"minOff";
            friendlyStats[field]=Math.min(friendlyStats[field],target.hp);
         }
         if(begin<0 || waiting || (session.runtime.tick-begin)%3!=0)return;
         var samples:Array=[],seen:Dictionary=new Dictionary(true),s:Object;
         for each(var actor:PlayerActor in session.actors) {
            seen[actor.unit.vis]=true;
            // Compare the character artwork, separately from local selection,
            // reload UI and the recipient's independently calculated RV mask.
            s=sample(actor.unit.vis.osn,"body",actor.unit.sloy);
            if(s!=null){
               s.player=actor.id;s.parentClip=getQualifiedClassName(actor.unit.vis);s.parentX=actor.unit.vis.x;s.parentY=actor.unit.vis.y;s.child="osn";
               if(!samplePictures[actor.id]) {
                  samplePictures[actor.id]=true;s.tree=structure(actor.unit.vis.osn);s.pictureId=actor.id;
                  picture(actor.unit.vis.osn,s.bounds,"weapon-native-body-"+actor.id+".png");
               }
               samples.push(s);
            }
            for each(var weapon:Object in [actor.unit.currentWeapon,actor.unit.throwWeapon,actor.unit.magicWeapon])if(weapon!=null && !seen[weapon]) {
               seen[weapon]=true;if(weapon.vis!=null)seen[weapon.vis]=true;s=sample(weapon.vis,weapon===actor.unit.currentWeapon?"weapon":"quick",weapon.sloy);
               if(s!=null){if(s.kind=="weapon")s.player=actor.id;else s.id=session.sceneId(weapon);samples.push(s);if(s.kind=="quick")++nativeQuick;}
            }
         }
         var perClip:Object={},o:Object=shooter.unit.loc.firstObj;
         while(o!=null) {
            if(o.vis!=null)seen[o.vis]=true;
            var projectile:Boolean=NativeAccess.get(o,"begx")!=null;
            s=sample(o.vis,projectile?"projectile":"effect",o.sloy);
            if(s!=null) {
               s.id=projectile?session.runtime.projectileId(o):session.sceneId(o);
               if(projectile)s.object={type:getQualifiedClassName(o),inChain:o.in_chain,weapon:NativeAccess.get(o,"weap")==null?null:o.weap.id,life:o.liv,x:o.X,y:o.Y};
               if(!projectile)nativeEffects[s.clip]=true;
               if(uint(perClip[s.clip])<2){samples.push(s);perClip[s.clip]=uint(perClip[s.clip])+1;}
            }
            o=o.nobj;
         }
         // Independently inspect native parts outside the object chain, the
         // historical missing path for melee arcs and other loose symbols.
         for each(var unit:Object in shooter.unit.loc.units) {
            if(unit.vis!=null)seen[unit.vis]=true;if(unit.hpbar!=null)seen[unit.hpbar]=true;
            for each(weapon in unit.childObjs)if(weapon!=null && weapon.vis!=null)seen[weapon.vis]=true;
         }
         for each(var list:Array in [shooter.unit.loc.objs,shooter.unit.loc.acts,shooter.unit.loc.bonuses])
            for each(o in list)if(o.vis!=null)seen[o.vis]=true;
         for each(var layer:DisplayObjectContainer in access.world.grafon.visObjs)
            for(var mi:int=0;mi<layer.numChildren;mi++)if(layer.getChildAt(mi).mask!=null)observedMasks[layer.getChildAt(mi).mask]=true;
         // Native RV can leave a mask attached while its actual owner is
         // temporarily outside the display tree; it is not a weapon effect.
         for(var owner:Object in seen)if(owner is DisplayObject && DisplayObject(owner).mask!=null)
            observedMasks[DisplayObject(owner).mask]=true;
         for(var li:int=0;li<access.world.grafon.visObjs.length;li++) {
            layer=access.world.grafon.visObjs[li];
            for(var ci:int=0;ci<layer.numChildren;ci++) {
               var extra:DisplayObject=layer.getChildAt(ci);if(seen[extra] || observedMasks[extra])continue;
               s=sample(extra,"effect",li);if(s!=null){s.id=session.sceneId(extra);samples.push(s);nativeEffects[s.clip]=true;}
            }
         }
         nativeSamples+=samples.length;
         var reference:Object={type:"weapon-reference",phase:phase,tick:session.runtime.tick,samples:samples};
         if(kind=="terrain") {
            var pixels:Vector.<uint>=access.world.grafon.frontBmp.getVector(inkArea);
            if(inkBefore==null)inkBefore=pixels;
            var changed:int=0,holes:int=0;
            for(var pi:int=0;pi<pixels.length;pi++)if(pixels[pi]!=inkBefore[pi]) {
               ++changed;if((pixels[pi]>>>24)<(inkBefore[pi]>>>24))++holes;
            }
            inkChanges=Math.max(inkChanges,changed);inkHoles=Math.max(inkHoles,holes);
            reference.ink={rect:[inkArea.x,inkArea.y,inkArea.width,inkArea.height],hash:inkHash(pixels)};
         }
         session.link.send(reference);
      }
      private function inkHash(pixels:Vector.<uint>):uint {
         var digest:uint=2166136261;for each(var pixel:uint in pixels){digest^=pixel;digest*=16777619;}return digest;
      }
      private function applied(frame:Object):void {
         var ref:Object=references[frame.tick];if(ref==null || ref.phase!=phase)return;
         delete references[frame.tick];
         if(ref.ink!=null) {
            var elapsed:int=int(frame.tick)-begin;
            if(elapsed>=81 && elapsed<90 && counts.hpRedrawBase<0)counts.hpRedrawBase=RConnectMod.instance.replica.scene.terrainRedraws;
            if(elapsed>=96 && elapsed<=120 && counts.hpRedrawBase>=0)
               counts.hpRedraws=Math.max(counts.hpRedraws,RConnectMod.instance.replica.scene.terrainRedraws-counts.hpRedrawBase);
            var area:Array=ref.ink.rect;++counts.inkSamples;
            if(inkHash(access.world.grafon.frontBmp.getVector(new Rectangle(area[0],area[1],area[2],area[3])))!=uint(ref.ink.hash))++counts.inkWrong;
         }
         for each(var s:Object in ref.samples) {
            ++counts.samples;counts[s.kind]=int(counts[s.kind])+1;
            var container:DisplayObjectContainer=access.world.grafon.visObjs[s.layer],found:DisplayObject=null;
            var client:ClientReplica=RConnectMod.instance.replica;
            if(s.kind=="weapon")found=client.weaponDisplay(s.player);
            else if(s.kind=="body") {var player:Object=displayedPlayer(s.player);if(player!=null)found=player.vis.osn;}
            else if(s.kind=="projectile")found=client.projectileDisplay(s.id);
            else if((s.kind=="effect" || s.kind=="quick") && client.scene.effects.records[s.id]!=null)found=client.scene.effects.records[s.id].clip;
            // Several impact particles and consecutive beam samples may have
            // the same class and position. Use their lifetime identity, then
            // independently assert attachment, geometry, frame and pixels.
            for(var i:int=0;found==null && s.id==null && s.player==null && i<container.numChildren;i++) {
               var candidate:DisplayObject=container.getChildAt(i);
               if(s.child!=null) {
                  if(getQualifiedClassName(candidate)==s.parentClip && Math.abs(candidate.x-s.parentX)<.06 && Math.abs(candidate.y-s.parentY)<.06)
                     {found=DisplayObjectContainer(candidate).getChildByName(s.child);break;}
               }else if(getQualifiedClassName(candidate)==s.clip && Math.abs(candidate.x-s.x)<.06 && Math.abs(candidate.y-s.y)<.06){found=candidate;break;}
            }
            if(found==null || found.parent!==container && s.child==null){++counts.missing;detail(s,"missing");continue;}
            if(s.tree!=null){Log.write("weapon-body-tree",{player:s.pictureId,source:s.tree,replica:structure(found)});picture(found,s.bounds,"weapon-replica-body-"+s.pictureId+".png");}
            var m:Matrix=found.transform.matrix,actual:Array=[m.a,m.b,m.c,m.d,m.tx,m.ty],wrong:Boolean=false;
            for(i=0;i<6;i++)if(Math.abs(actual[i]-s.matrix[i])>.002)wrong=true;
            if(wrong || found is MovieClip && MovieClip(found).currentFrame!=s.frame){
               ++counts.pose;s.actual={m:actual,frame:found is MovieClip?MovieClip(found).currentFrame:0};detail(s,"pose");
            }
            if(fingerprint(found,s.bounds)!=uint(s.hash)){++counts.pixels;detail(s,"pixels");}
         }
      }
      private function detail(s:Object,issue:String):void {
         var category:String=s.kind+":"+issue;
         for each(var earlier:Object in counts.first)if(earlier.category==category)return;
         var candidates:Array=[];
         for(var layer:int=0;layer<access.world.grafon.visObjs.length;layer++) {
            var container:DisplayObjectContainer=access.world.grafon.visObjs[layer];
            for(var i:int=0;i<container.numChildren;i++) {
               var child:DisplayObject=container.getChildAt(i);
               if(getQualifiedClassName(child)==s.clip)candidates.push({layer:layer,x:child.x,y:child.y});
            }
         }
         var encoded:Array=[],f:Object=RConnectMod.instance.replica.displayFrame;
         if(s.kind=="projectile")for each(var p:Object in f.projectiles.concat(f.projectileEvents))if(p.clip==s.clip) {
            var actual:DisplayObject=RConnectMod.instance.replica.projectileDisplay(p.id);
            encoded.push({id:p.id,room:p.room,frame:p.frame,x:p.x,y:p.y,ended:p.ended,visual:p.visual,
               displayed:actual==null?null:{attached:actual.parent!=null,currentLayer:actual.parent===access.world.grafon.visObjs[int(p.layer)],clip:getQualifiedClassName(actual),x:actual.x,y:actual.y}});
         }
         counts.first.push({category:category,kind:s.kind,clip:s.clip,issue:issue,x:s.x,y:s.y,layer:s.layer,candidates:candidates,object:s.object,
            expected:{m:s.matrix,frame:s.frame},actual:s.actual,encoded:encoded});
      }
      override public function observe(session:HostSession,replica:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(replica==null || replica.lastFrame==null)return;
            if(!ready){ready=true;replica.confirmed=applied;}
            if(phase>=0 && readySent!=phase && replica.displayFrame!=null) {
               readySent=phase;RConnectMod.instance.link.send({type:"weapon-ready",phase:phase});
            }
            if(ending>=0 && replica.displayFrame.tick>=ending) {
               check(counts.samples>20 && counts.body>0 && (counts.projectile>0 || kind=="melee" && counts.weapon>0 || kind=="magic" && cases[int(phase/2)]=="mray" && counts.quick>0),
                  "actual native projectile or continuous beam and player displays observed phase "+phase,counts);
               check(counts.missing==0 && counts.pose==0,"native visual attachments, flips and timeline match phase "+phase,counts);
               check(counts.pixels==0 && counts.samples>counts.missing,"transported authored visuals match independent native pixels phase "+phase,counts);
               if(kind=="explosives" || ["fireball","eclipse"].indexOf(cases[int(phase/2)])>=0)
                  check(counts.effect>0,"native impact or sustained particles reach display phase "+phase,counts);
               if(kind=="terrain")check(counts.inkSamples>40 && counts.inkWrong==0,
                  "native bullet holes and scorch pixels remain exact across local and authoritative redraws phase "+phase,counts);
               if(kind=="terrain")check(counts.hpRedrawBase>=0 && counts.hpRedraws==0,
                  "wall durability changes retain native ink without redrawing the entire room phase "+phase,counts);
               RConnectMod.instance.link.send({type:"weapon-report",phase:phase,counts:counts});ending=-1;
            }
            return;
         }
         if(session==null || !session.active)return;
         if(!ready) {
            ready=true;var publish:Function=session.runtime.afterStep;
            if(friendly)observeFriendlyHits(session);
            session.runtime.afterStep=function():void {source(session);publish();};start(session,0);return;
         }
         if(begin<0 && peerReady==phase){begin=session.runtime.tick;session.link.send({type:"weapon-go",tick:begin});}
         if(friendly && begin>=0 && session.runtime.tick-begin>=90 && !friendlyOpened) {
            friendlyOpened=true;
            check(target.hp==targetHP && friendlyStats.minOff==targetHP,"disabled friendly fire blocks native "+gun.id+" owner "+shooter.id,{before:targetHP,after:target.hp,minimum:friendlyStats.minOff});
            session.combat.enabled=true;friendlyStats.shots=session.runtime.spawnsByPlayer[shooter.id];
         }
         if(kind=="melee" && gun.id=="spear" && begin>=0 && (session.runtime.tick-begin==35 || session.runtime.tick-begin==60))
            Log.write("spear-native-state",{phase:phase,gun:NativeFields.capture(gun),player:{stam:shooter.unit.stam,work:shooter.unit.work,
               control:shooter.unit.ggControl,aim:[shooter.unit.celX,shooter.unit.celY],x:shooter.unit.X,y:shooter.unit.Y,
               meleeR:shooter.unit.pers.meleeR,meleeS:shooter.unit.pers.meleeS},status:gun.status()});
         if(kind=="terrain" && begin>=0) {
            if(!inkRebuild && session.runtime.tick-begin>=90) {
               inkRebuild=true;
               // This scalar-only hit must update durability without redrawing
               // the room or losing any existing native bullet-hole pixels.
               shooter.unit.loc.space[25][int((fy+1)/40)-2].hp-=1;
            }
            if(!inkRedraw && session.runtime.tick-begin>=125) {
               inkRedraw=true;access.world.grafon.drawLoc(shooter.unit.loc);
            }
         }
         // Dynamite has the original 150-step fuse, starting at release rather
         // than button-down. Observe its real explosion instead of ending the
         // case before its fuse can expire.
         var duration:int=friendly?250:gun!=null && gun.id=="dinamit"?260:180;
         if(begin>=0 && !waiting && session.runtime.tick-begin>=duration) {
            waiting=true;
            if(kind!="melee")check(session.runtime.spawnsByPlayer[shooter.id]>initialShots,"real input creates native projectile "+gun.id+" owner "+shooter.id,
               {shots:session.runtime.spawnsByPlayer[shooter.id]-initialShots,ammoBefore:initialAmmo,manaBefore:initialMana,manaAfter:shooter.unit.mana});
            if(kind=="explosives")check(shooter.unit.invent.items[gun.ammo].kol==19,"one native quick throw consumes one item "+gun.id+" owner "+shooter.id,
               {before:initialAmmo,remaining:shooter.unit.invent.items[gun.ammo].kol,shots:session.runtime.spawnsByPlayer[shooter.id]-initialShots});
            if(friendly || kind=="melee" || kind=="guns")check(target.hp<targetHP,
               (friendly?"enabled friendly fire damages the real teammate with ":"native equipped weapon damages a real target ")+gun.id+" owner "+shooter.id,{before:targetHP,after:target.hp,diagnostic:friendly?friendlyStats:null,
                  firstHit:firstHit,weapon:friendly?NativeFields.capture(gun):null,target:friendly?NativeFields.capture(target):null});
            // Native stabbing spears do not enable the sweeping visVzz arc.
            if(kind=="melee" && gun.id=="bat")check(nativeEffects["visVzz"]===true,"native melee swing arc is included "+gun.id+" owner "+shooter.id);
            if(kind=="terrain") {
               check(inkChanges>10 && (gun.id=="prism" || inkHoles>0),"native wall hit produces real marks and expected alpha holes "+gun.id,
                  {changed:inkChanges,holes:inkHoles});
               check(shooter.unit.loc.space[25][int((fy+1)/40)-2].phis==1,"small cosmetic holes do not open wall collision");
            }
            var clips:Array=[];for(var key:String in nativeEffects)clips.push(key);
            Log.write("weapon-native-summary",{phase:phase,id:gun.id,owner:shooter.id,samples:nativeSamples,quick:nativeQuick,effects:clips});
            if(Timing.enabled)Log.write("weapon-phase-timings",{phase:phase,id:gun.id,owner:shooter.id,timings:Timing.snapshot()});
            session.link.send({type:"weapon-phase-end",phase:phase,tick:session.runtime.tick});
         }
         if(waiting && report!=null && report.phase==phase) {
            if(phase+1<cases.length*2)start(session,phase+1);
            else {session.link.send({type:"weapon-finish"});finish();}
         }
      }
   }
}
