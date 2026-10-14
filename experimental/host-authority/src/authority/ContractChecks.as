package authority {
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.display.Sprite;
   import flash.display.Shape;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.filters.GlowFilter;
   /** Executed in the native AIR probe, with controlled inputs and explicit failures. */
   public class ContractChecks {
      private static function input(seq:int,buttons:int=0,actions:Array=null):Object {
         return {session:"fixture",player:1,epoch:1,weaponEpoch:1,room:"one",roomEpoch:1,seq:seq,
            buttons:buttons,aimX:100,aimY:80,actions:actions==null?[]:actions};
      }
      public static function run(check:Function):void {
         TerrainChecks.run(check);
         presentation(check);
         motionRendering(check);
         grabOwnership(check);
         var named:Array=[];named["lmg"]={hold:11};named[3]="numeric";
         var copied:Object=JSON.parse(JSON.stringify(PlainData.copy({weapons:named})));
         check(copied.weapons.lmg.hold==11 && copied.weapons["3"]=="numeric","named native save entries survive JSON");
         var c:Commands=new Commands("fixture",1,"one"),bad:Object=input(1);
         bad.session="stale";check(c.accept(bad,10)=="identity" && c.accepted==0,"reject foreign session without mutating command state");
         bad=input(1);bad.epoch=2;check(c.accept(bad,10)=="identity","reject stale entity incarnation");
         bad=input(1);bad.room="two";check(c.accept(bad,10)=="identity","reject a different room");
         bad=input(1);bad.weaponEpoch=2;check(c.accept(bad,10)=="identity","reject wrong weapon incarnation");
         bad=input(1);bad.aimX=NaN;check(c.accept(bad,10)=="aim","reject nonfinite aim");
         check(c.accept(input(1,Commands.FIRE,[{id:1,type:"reload"}]),10)=="","accept valid input");
         check(c.accept(input(1),11)=="sequence","duplicate input is rejected");
         check(c.accept(input(2,0,[{id:1,type:"reload"}]),12)=="","accept release with repeated action id");
         var first:Object=c.consume(13),second:Object=c.consume(14);
         check((first.buttons&Commands.FIRE)!=0 && second.buttons==0,"short press survives a release before the simulation step");
         check(first.actions.length==1 && second.actions.length==0,"reliable action executes exactly once");
         c.accept(input(3,Commands.RIGHT,[{id:2,type:"reload"}]),20);
         var expired:Object=c.consume(521);
         check(expired.buttons==0 && expired.actions.length==0,"expired control lease cancels movement and pending actions");
         var held:Commands=new Commands("fixture",1,"one");
         held.accept(input(1,Commands.GRENADE|Commands.RIGHT),0);held.consume(1);
         var lost:Object=held.consume(501);
         held.accept(input(2,Commands.GRENADE|Commands.RIGHT),600);var resumed:Object=held.consume(601);
         check(lost.buttons==0 && lost.held==(Commands.GRENADE|Commands.RIGHT) && resumed.pressed==0 &&
            resumed.buttons==(Commands.GRENADE|Commands.RIGHT),
            "input silence stops movement without inventing another press when the same physical hold resumes");
         held.accept(input(3),602);held.consume(603);held.accept(input(4,Commands.GRENADE),604);
         check(held.consume(605).pressed==Commands.GRENADE,"a real release then press still permits the next throw");
         var prior:int=c.accepted;
         bad=input(4,Commands.LEFT,[{id:3,type:"reload"},{id:4,type:"invalid"}]);
         check(c.accept(bad,600)=="unsupported-action" && c.accepted==prior && c.consume(600).actions.length==0,"malformed batch cannot partially commit");
         c.retarget("two",2);c.retarget("one",3);
         check(c.accept(input(5,Commands.FIRE),610)=="identity" && c.consume(610).buttons==0,"returning to the same room rejects input from its previous visit");
         var owner:Object={name:"owner"},remote:Object={name:"remote"},room:Object={gg:owner};
         var world:Object={gg:owner,pers:owner,invent:owner,loc:room,celX:42};
         var scope:NativeScope=new NativeScope(world),threw:Boolean=false,nested:Boolean=false;
         try {
            scope.run({gg:remote,pers:remote,loc:room,celX:8},function():void {
               scope.run({gg:owner,loc:room},function():void {nested=world.gg===owner && room.gg===owner && scope.depth==2;});
               if(world.gg!==remote || room.gg!==remote)throw new Error("nested scope did not restore outer context");
               throw new Error("deliberate callback exception");
            });
         }catch(error:Error){threw=error.message=="deliberate callback exception";}
         check(nested && threw && scope.depth==0 && world.gg===owner && world.pers===owner && world.loc===room && room.gg===owner && world.celX==42,
            "nested native invocation restores references after an exception");
         world.calcMass=false;world.calcMassW=true;world.checkLoot=false;
         var home:Object={gg:owner,calcMass:false,calcMassW:true,checkLoot:false};
         var away:Object={gg:remote,calcMass:true,calcMassW:false,checkLoot:false};
         scope.register(home);scope.register(away);
         var separate:Boolean=false;
         scope.run(away,function():void {
            separate=world.calcMass && !world.calcMassW;
            world.calcMass=false;world.checkLoot=true;
            scope.run(home,function():void {world.calcMass=true;});
            separate=separate && !world.calcMass && !world.calcMassW && world.checkLoot;
         });
         check(separate && world.calcMass && world.calcMassW && !world.checkLoot && !away.calcMass && away.checkLoot,
            "pending inventory work survives nested calls without changing its owner");
         world.calcMass=false;world.calcMassW=false;
         scope.run(away,function():void {});
         check(!world.calcMass && !world.calcMassW && !home.calcMass && !home.calcMassW,
            "native host consumption of pending work is not replayed by a later remote call");
         var appearance:Object={trFur:new ColorTransform(),trHair:new ColorTransform(),trHair1:new ColorTransform(),
            trEye:new ColorTransform(),trMagic:new ColorTransform(),trBlack:new ColorTransform(),visHair1:false,fEye:1,fHair:1,
            ggArmorId:"power",hideMane:0,transp:false};
         var originalColor:ColorTransform=appearance.trFur;
         var context:Object={appearance:AppearanceState.capture(appearance,true)};
         scope=new NativeScope(world,appearance);
         scope.run(context,function():void {appearance.trFur.redMultiplier=.2;appearance.ggArmorId="assault";});
         check(appearance.trFur===originalColor && originalColor.redMultiplier==1 && appearance.ggArmorId=="power"
            && context.appearance.trFur.redMultiplier==.2 && context.appearance.ggArmorId=="assault",
            "mutable native appearance colors and armor remain actor-owned");
         var left:PlayerActor=new PlayerActor(null,0),right:PlayerActor=new PlayerActor(null,1);
         left.unit={id:0,X:0,Y:0,hp:100,disabled:false,loc:room};right.unit={id:1,X:100,Y:0,hp:100,disabled:false,loc:room};
         left.context={gg:left.unit,loc:room};right.context={gg:right.unit,loc:room};
         scope=new NativeScope(world);
         var counts:Array=[0,0],hidden:Boolean=false,breakFind:Boolean=false;
         var enemy:Object={loc:room,X:80,Y:0,celUnit:null,priorUnit:null,celX:20,celY:30,celDX:0,celDY:0};
         enemy.findCel=function(omni:Boolean):Boolean {
            ++counts[world.gg.id];
            if(breakFind && world.gg===right.unit)throw new Error("perception exception");
            if(hidden && world.gg===right.unit){enemy.celUnit=null;return false;}
            enemy.celUnit=world.gg;enemy.celX=world.gg.X;enemy.celY=world.gg.Y;return true;
         };
         var perception:NativePerception=new NativePerception(scope,[left,right]);
         check(perception.find(enemy,false) && counts[0]==1 && counts[1]==1 && enemy.celUnit===right.unit && world.gg===owner && room.gg===owner,
            "native target checks evaluate both player contexts once and restore the host");
         hidden=true;counts=[0,0];
         check(perception.find(enemy,false) && enemy.celUnit===left.unit && counts[1]==1,
            "an unobserved nearer player cannot win a native target check");
         var oldX:Number=enemy.celX;breakFind=true;threw=false;
         try{perception.find(enemy,false);}catch(perceptionError:Error){threw=perceptionError.message=="perception exception";}
         check(threw && enemy.celUnit===left.unit && enemy.celX==oldX && world.gg===owner && scope.depth==0,
            "failed multi-player perception restores native target fields and nested player scopes");
         enemy.priorUnit=left.unit;
         enemy.findCel=function(omni:Boolean):Boolean{return false;};
         check(!perception.find(enemy,false) && enemy.celUnit===left.unit && enemy.priorUnit===left.unit && enemy.celX==oldX,
            "a native early return preserves the existing enemy target during stun or ineligibility");
         enemy.findCel=function(omni:Boolean):Boolean {
            enemy.celUnit=null;enemy.priorUnit=null;
            if(world.gg===left.unit){enemy.celX=37;enemy.celY=49;enemy.celDX=-43;enemy.celDY=49;}
            return false;
         };
         check(!perception.find(enemy,false) && enemy.celUnit==null && enemy.priorUnit==null &&
            enemy.celX==37 && enemy.celY==49 && enemy.celDX==-43 && enemy.celDY==49,
            "native unsuccessful perception can clear a target while retaining its heard search position");
      }
      private static function grabOwnership(check:Function):void {
         var a:PlayerActor=new PlayerActor(null,0),b:PlayerActor=new PlayerActor(null,1);
         var target:Object={X:120,Y:80,X1:110,X2:130,Y1:40,Y2:80,scX:20,scY:40,prior:2,onCursor:3,
            levitPoss:true,levit:1,nobj:null},original:Object={name:"original-pointer"};
         var room:Object={units:[target],firstObj:target,celObj:original,celDist:99};
         a.unit={loc:room,X:0,Y:80,teleObj:target};b.unit={loc:room,X:40,Y:80,teleObj:null};
         a.grips=b.grips=new PeerGrabs([a,b]);
         var aim:Object={aimX:120,aimY:60,buttons:0},guarded:Boolean=false,threw:Boolean=false;
         try {PlayerPointer.run(b,aim,function():void {
            guarded=room.celObj==null && !target.levitPoss && target.onCursor==0;
            throw new Error("selection exception");
         });}catch(error:Error){threw=error.message=="selection exception";}
         check(guarded && threw && target.levitPoss && target.onCursor==3 && a.unit.teleObj===target &&
            room.celObj===original && room.celDist==99,
            "a second caster cannot select a held object through hover or native fallback; exception restores native eligibility");
         var ownerAllowed:Boolean=false;
         PlayerPointer.run(a,aim,function():void {ownerAllowed=room.celObj===target && target.levitPoss;});
         check(ownerAllowed,"the current caster retains the native release and throw target");
         a.unit.teleObj=null;
         PlayerPointer.run(b,aim,function():void {ownerAllowed=room.celObj===target && target.levitPoss;});
         check(ownerAllowed && target.levitPoss && target.onCursor==3,"released object is immediately eligible for the other caster");
      }
      private static function presentation(check:Function):void {
         var exactText:Boolean=true,textCases:Array=[];
         for each(var words:String in ["78","78\r","Alpha\rBeta"]) {
            var nativeText:TextField=new TextField(),replayedText:TextField=new TextField();
            nativeText.text=words;nativeText.textColor=0xFF6666;
            nativeText.setTextFormat(new TextFormat(null,18,null,true),0,1);
            VisualPose.apply(replayedText,wireCopy(VisualPose.capture(nativeText)));
            exactText=exactText && replayedText.text===nativeText.text && replayedText.textColor===nativeText.textColor &&
               replayedText.getTextFormat(0,1).bold===nativeText.getTextFormat(0,1).bold &&
               replayedText.getTextFormat(0,1).size===nativeText.getTextFormat(0,1).size;
            textCases.push({source:nativeText.text,actual:replayedText.text,sourceColor:nativeText.textColor,actualColor:replayedText.textColor,
               sourceBold:nativeText.getTextFormat(0,1).bold,actualBold:replayedText.getTextFormat(0,1).bold,
               sourceSize:nativeText.getTextFormat(0,1).size,actualSize:replayedText.getTextFormat(0,1).size,
               sourceHTML:nativeText.htmlText,actualHTML:replayedText.htmlText});
            VisualPose.dispose(nativeText);VisualPose.dispose(replayedText);
         }
         check(exactText,"native text retains exact digits, intentional newlines and character formatting after AIR HTML replay",textCases);
         var masks:DisplayMasks=new DisplayMasks(),detachedOwner:Sprite=new Sprite(),viewMask:Shape=new Shape(),ordinaryShape:Shape=new Shape();
         detachedOwner.mask=viewMask;masks.remember(detachedOwner);detachedOwner.mask=null;
         check(masks.contains(viewMask) && !masks.contains(ordinaryShape),
            "detached mask owners retain local mask identity without excluding ordinary runtime Shapes");
         masks.reset();check(!masks.contains(viewMask),"world reset releases remembered local mask identities");
         var music:RoomMusic=new RoomMusic("ambient"),other:RoomMusic=new RoomMusic("quiet");
         music.combat("combat",2,4);music.step();music.combat("combat",2,4);
         check(music.track=="combat" && music.priority==2 && music.remaining==4 && other.track=="quiet",
            "combat music keeps native priority semantics and belongs only to its room");
         music.request("combat",1);music.combat("lower",1,3);
         check(music.track=="combat" && music.loops==10000 && music.remaining==3,
            "same-track request does not restart repeats and a lower-priority enemy only refreshes the timer");
         for(var musicTick:int=0;musicTick<3;musicTick++)music.step();
         check(music.track=="ambient" && music.remaining==0 && other.track=="quiet" && other.remaining==0,
            "occupied-room music returns to its ambient track while an unstepped room stays unchanged");
         deltaSequence(check);
         nativeFieldSequence(check);
         movement(check);
         wire(check);
         var enc:FrameDelta=new FrameDelta(),dec:FrameDelta=new FrameDelta();
         var one:Object={players:[{x:1,native:{hp:10}}],scene:{tiles:[{x:1,v:[2,3]}]}};
         var first:Object=dec.decode(enc.encode(one));
         var two:Object={players:[{x:5,native:{hp:9}}],scene:{tiles:[{x:2,v:[4,3]}]}};
         var second:Object=dec.decode(enc.encode(two));
         check(first.players[0].x==1 && first.players[0].native.hp==10 && first.scene.tiles[0].v[0]==2 &&
            second.players[0].x==5 && second.scene.tiles[0].v[0]==4,"delta decoding preserves every buffered older confirmation");
         var timeline:PlaybackClock=new PlaybackClock();
         var a:Object={time:100,room:"one",pauseEpoch:0,players:[]},b:Object={time:150,room:"one",pauseEpoch:0,players:[]};
         timeline.push(a,1100);timeline.take(1100,true);timeline.push(b,1157);timeline.take(1190);
         check(timeline.current===a && timeline.next===b && Math.abs(timeline.fraction-.5)<.001,
            "one render timeline interpolates confirmed source time despite uneven arrivals");
         var frozen:Object={time:155,room:"one",pauseEpoch:1,paused:true,players:[]};
         var boundary:Boolean=timeline.push(frozen,1200),ready:Array=timeline.take(1200,boundary);
         check(boundary && ready.length==2 && timeline.current===frozen && timeline.fraction==0,
            "pause flush consumes pending deltas and stops exactly at the host boundary");
         playbackCadence(check);
         var p:Object={x:10,y:20,sx:1,sy:1,r:179,a:1,v:true,f:1,children:[]};
         var q:Object={x:20,y:40,sx:1,sy:1,r:-179,a:1,v:true,f:2,children:[]};
         var v:Object=PoseTween.pose(p,q,.5);
         check(v.x==15 && v.y==30 && Math.abs(v.r-180)<.001 && v.f==1 && p.x==10,
            "motion crosses animation frames while poses stay discrete and angles take the short arc");
         q.sx=-1;v=PoseTween.pose(p,q,.5);
         check(v.sx==1 && v.r==179 && v.x==15,"weapon reflection is a discrete native flip, never a shrinking interpolated sprite");
         var priorBody:Object={epoch:1,roomEpoch:1,positionEpoch:4,x:10,y:20,native:{X:10,Y:20},visual:p,weapon:null};
         var nextBody:Object={epoch:1,roomEpoch:1,positionEpoch:5,x:90,y:20,native:{X:90,Y:20},visual:q,weapon:null};
         var priorScene:Object={key:"one",units:[{key:1,positionEpoch:4,pose:p}],objects:[],effects:[]};
         var nextScene:Object={key:"one",units:[{key:1,positionEpoch:5,pose:q}],objects:[],effects:[]};
         var earlier:Object={room:"one",pauseEpoch:0,players:[priorBody],projectiles:[],scene:priorScene};
         var later:Object={room:"one",pauseEpoch:0,players:[nextBody],projectiles:[],scene:nextScene};
         v=PoseTween.frame(earlier,later,.5);
         check(v.players[0]===priorBody && v.scene.units[0]===priorScene.units[0],
            "even a short native teleport preserves the old player/enemy pose until its confirmed boundary");
         nextBody.positionEpoch=4;nextScene.units[0].positionEpoch=4;v=PoseTween.frame(earlier,later,.5);
         check(v.players[0].x==50 && v.scene.units[0].pose.x==15 && priorBody.x==10,
            "ordinary continuous movement still interpolates without mutating the prior confirmation");
         var source:Sprite=new Sprite(),replica:Sprite=new Sprite();
         source.transform.matrix=new Matrix(.992919921875,-.1126861572265625,.1496124267578125,.9264678955078125,10,-20);
         var captured:Object=VisualPose.capture(source);VisualPose.apply(replica,captured);
         check(PoseTween.pose(captured,captured,.37)===captured,
            "unchanged immutable native poses need no extra interpolation or allocation");
         var original:Matrix=source.transform.matrix,restored:Matrix=replica.transform.matrix;
         check(Math.abs(original.a-restored.a)<.00002 && Math.abs(original.b-restored.b)<.00002 &&
            Math.abs(original.c-restored.c)<.00002 && Math.abs(original.d-restored.d)<.00002,
            "authored skew and affine precision survive actual native display reconstruction");
         p=JSON.parse(JSON.stringify(captured));q=JSON.parse(JSON.stringify(captured));q.x+=20;q.y+=10;q.m[4]+=20;q.m[5]+=10;
         v=PoseTween.pose(p,q,.5);
         check(Math.abs(v.m[0]-p.m[0])<.000001 && Math.abs(v.m[2]-p.m[2])<.000001 &&
            v.m[4]==p.m[4]+10 && v.m[5]==p.m[5]+5 && p.m[4]==10,
            "display interpolation preserves skew and leaves confirmed transforms immutable");
         check(v.m[0]===p.m[0] && v.m[1]===p.m[1] && v.m[2]===p.m[2] && v.m[3]===p.m[3],
            "pure translations retain exact native affine bases without a trigonometric round trip");
         var child:Sprite=new Sprite();source.addChild(child);
         var before:Object=VisualPose.capture(source),unchanged:Object=VisualPose.capture(source);
         child.x=17;var changed:Object=VisualPose.capture(source);
         check(before===unchanged && before!==changed && before.children[0].s.x==0 && changed.children[0].s.x==17 &&
            before.m===changed.m && before.c===changed.c,
            "native pose capture reuses unchanged branches without mutating earlier child or parent confirmations");
         source.visible=false;var hidden:Object=VisualPose.capture(source);child.x=31;
         source.visible=true;var shown:Object=VisualPose.capture(source);
         check(hidden.children==null && !hidden.v && shown.children[0].s.x==31 && before.children[0].s.x==0,
            "hidden subtrees resume from current native state while retained confirmations stay unchanged");
         var image:BitmapData=new BitmapData(256,256,true,0);
         for(var alpha:int=0;alpha<256;alpha++)for(var channel:int=0;channel<256;channel++)
            image.setPixel32(channel,alpha,(alpha<<24)|(channel<<16)|((255-channel)<<8)|(channel^85));
         var recipe:Object=PixelSurface.capture(image),copy:BitmapData=PixelSurface.restore(wireCopy(recipe));
         check(image.compare(copy)===0,"native pixel surfaces preserve every alpha and color channel through the wire");
         var body:Sprite=new Sprite(),mirror:Sprite=new Sprite();body.addChild(new Bitmap(image));
         before=VisualPose.capture(body,0,true);VisualPose.apply(mirror,wireCopy(before));
         image.fillRect(image.rect,0x800020ff);changed=VisualPose.capture(body,0,true);VisualPose.apply(mirror,wireCopy(changed));
         var oldImage:BitmapData=PixelSurface.restore(before.children[0].s.pixels);
         check(Bitmap(mirror.getChildAt(0)).bitmapData.compare(image)===0 && oldImage.compare(copy)===0,
            "changing a native corpse surface updates its replica without mutating the prior confirmation");
         var enc:FrameDelta=new FrameDelta(),dec:FrameDelta=new FrameDelta();
         var retained:Object=dec.decode(wireCopy(enc.encode({type:"frame",session:"pixels",surface:recipe})));
         var latest:Object=dec.decode(wireCopy(enc.encode({type:"frame",session:"pixels",surface:PixelSurface.capture(image)})));
         var oldPayload:Object=wireCopy(retained.surface),newPayload:Object=wireCopy(latest.surface);
         var oldReplay:BitmapData=PixelSurface.restore(retained.surface),newReplay:BitmapData=PixelSurface.restore(latest.surface);
         check(oldReplay.compare(copy)===0 && newReplay.compare(image)===0 &&
            VisualPose.recipeEqual(oldPayload,retained.surface) && VisualPose.recipeEqual(newPayload,latest.surface),
            "binary pixel deltas retain old images and playback never mutates compressed confirmations");
         oldReplay.dispose();newReplay.dispose();
         VisualPose.dispose(mirror);image.dispose();copy.dispose();oldImage.dispose();
      }
      private static function motionRendering(check:Function):void {
         var nativeRoot:Sprite=new Sprite(),full:Sprite=new Sprite(),fast:Sprite=new Sprite();
         var limb:Sprite=new Sprite(),label:TextField=new TextField();limb.name="limb";label.name="label";
         nativeRoot.addChild(limb);limb.addChild(label);
         limb.graphics.beginFill(0x80ff20,.7);limb.graphics.drawCircle(18,18,12);limb.graphics.endFill();
         limb.filters=[new GlowFilter(0x25baff,.5,5,5)];
         label.defaultTextFormat=new TextFormat("_sans",14,0xff9220);label.text="108";label.y=32;
         var image:BitmapData=new BitmapData(9,9,true,0x908020ff),part:Bitmap=new Bitmap(image);part.name="part";part.x=37;limb.addChild(part);
         var left:Object=VisualPose.capture(nativeRoot,0,true);
         limb.x=36;limb.y=18;limb.rotation=28;limb.alpha=.5;part.x=43;label.text="new confirmation";
         var right:Object=VisualPose.capture(nativeRoot,0,true),wire:Object=wireCopy(left);
         VisualPose.apply(full,wire);VisualPose.apply(fast,wire);
         var equal:Boolean=true,textHeld:Boolean=true,surfaceHeld:Boolean=true,opacity:Boolean=true,firstDifference:Object;
         var fastLimb:Sprite=fast.getChildByName("limb") as Sprite,retained:BitmapData=Bitmap(fastLimb.getChildByName("part")).bitmapData;
         for each(var fraction:Number in [.1,.5,.9]) {
            var pose:Object=PoseTween.pose(wire,right,fraction);
            VisualPose.apply(full,pose);VisualPose.motion(fast,pose);
            var a:BitmapData=new BitmapData(160,120,true,0),b:BitmapData=new BitmapData(160,120,true,0);
            a.draw(full,new Matrix(1,0,0,1,40,20));b.draw(fast,new Matrix(1,0,0,1,40,20));
            var difference:*=a.compare(b);equal=equal && difference===0;
            opacity=opacity && Math.abs(fastLimb.alpha-(1-fraction*.5))<.004 &&
               Math.abs(full.getChildByName("limb").alpha-fastLimb.alpha)<.004;
            if(difference!==0 && firstDifference==null)firstDifference={fraction:fraction,fullAlpha:full.getChildByName("limb").alpha,fastAlpha:fastLimb.alpha};
            if(difference is BitmapData)BitmapData(difference).dispose();a.dispose();b.dispose();
            textHeld=textHeld && TextField(fastLimb.getChildByName("label")).text=="108";
            surfaceHeld=surfaceHeld && Bitmap(fastLimb.getChildByName("part")).bitmapData===retained;
         }
         check(equal && textHeld && surfaceHeld && opacity,
            "motion-only display matches full native pose pixels without rebuilding text, filters or bitmap surfaces",
            {pixels:equal,textHeld:textHeld,surfaceHeld:surfaceHeld,opacity:opacity,first:firstDifference});
         VisualPose.apply(fast,wireCopy(right));
         check(TextField(Sprite(fast.getChildByName("limb")).getChildByName("label")).text=="new confirmation",
            "the next confirmation still applies discrete text after motion-only playback");
         VisualPose.dispose(nativeRoot);VisualPose.dispose(full);VisualPose.dispose(fast);image.dispose();
      }
      private static function playbackCadence(check:Function):void {
         var clock:PlaybackClock=new PlaybackClock(),sent:int=0,empty:int=0,observed:int=0;
         var jitter:Array=[0,24,48,8,16,40],previous:Number=-1,ordered:Boolean=true,bounded:Boolean=true;
         for(var now:int=1000;now<8200;now+=16) {
            while(sent<60 && 1000+sent*120+jitter[sent%jitter.length]<=now) {
               var f:Object={time:sent*120,room:"dense",pauseEpoch:0,paused:false,players:[]};
               var boundary:Boolean=clock.push(f,1000+sent*120+jitter[sent%jitter.length]);
               if(boundary)clock.take(now,true);++sent;
            }
            clock.take(now);
            if(now>2400 && now<7800) {
               ++observed;if(clock.next==null)++empty;
               ordered=ordered && clock.position>=previous;previous=clock.position;
               bounded=bounded && clock.queued<8 && clock.current!=null && clock.position<=(sent-1)*120;
            }
         }
         check(observed>300 && empty<observed*.05 && ordered && bounded,
            "slow 120ms source frames with 48ms jitter play continuously without reversal or unconfirmed extrapolation",
            {samples:observed,empty:empty,delay:clock.delay,ordered:ordered,bounded:bounded});
         var stop:Object={time:7200,room:"dense",pauseEpoch:1,paused:true,players:[]};
         boundary=clock.push(stop,8300);clock.take(8300,boundary);
         check(boundary && clock.current===stop && clock.fraction==0 && clock.queued==0,
            "adaptive dense-scene buffer still freezes immediately at the exact shared pause boundary");
         for(var i:int=0;i<160;i++) {
            f={time:7233+i*33,room:"dense",pauseEpoch:2,paused:false,players:[]};
            boundary=clock.push(f,8233+i*33);clock.take(8233+i*33,boundary);
         }
         check(clock.delay==65,"recovered fast source cadence returns to the original low-latency buffer");
      }
      private static function wireCopy(value:Object):Object {return WireCodec.decode(WireCodec.encode({type:"contract-copy",value:value})).value;}
      private static function movement(check:Function):void {
         var p:MovementPrediction=new MovementPrediction(),input:Object={seq:1,room:"floor",roomEpoch:1,epoch:1,weaponEpoch:1,buttons:Commands.RIGHT,actions:[]};
         p.record(input,1000);
         var state:Object={id:1,ack:1,room:"floor",roomEpoch:1,epoch:1,weaponEpoch:1,x:100,y:400,native:{X:100,X1:90,X2:110,eyeX:100},
            motion:{x:100,dx:0,walk:0,max:5,speed:5,accel:1,brake:1,friction:.9,left:76,right:124},visual:{x:100,y:400,m:[1,0,0,1,100,400]},weapon:null};
         var frame:Object={tick:1,time:100,paused:false,pauseEpoch:0,room:"floor",scene:{terrainRevision:1},players:[null,state]};
         p.confirm(frame,1040);
         for(var i:int=2;i<50;i++){input=PoseTween.copy(input);input.seq=i;p.record(input,1040+i);}
         var sample:Object=p.sample(1120,frame,1,false);
         check(sample!=null && sample.x>100 && sample.x<=115 && state.x==100 && state.visual.m[4]==100,
            "many unacknowledged input packets cannot become extra physics steps or mutate confirmation");
         check(p.sample(1120,frame,2,false)==null && p.sample(1120,frame,1,true)==null && p.sample(1300,frame,1,false)==null,
            "changed terrain, local pause and stale confirmation cancel movement prediction");
         var moved:Object=PoseTween.copy(state);moved.positionEpoch=1;
         var discontinuous:Object=PoseTween.copy(frame);discontinuous.players=[null,moved];discontinuous.tick=2;discontinuous.time=133;
         var crossing:MovementPrediction=new MovementPrediction(),teleportInput:Object=PoseTween.copy(input);teleportInput.seq=1;
         crossing.record(teleportInput,1000);crossing.confirm(frame,1040);
         var wasPredicting:Boolean=crossing.sample(1100,frame,1,false)!=null;
         crossing.confirm(discontinuous,1121);
         check(wasPredicting && crossing.sample(1122,discontinuous,1,false)==null && crossing.sample(1122,frame,1,false)==null,
            "native teleport cancels unacknowledged movement and cannot predict across the old display boundary");
         input=PoseTween.copy(input);input.seq=50;input.buttons=Commands.FIRE;p.record(input,1121);
         check(p.sample(1122,frame,1,false)==null,"a new combat intent removes prediction before the host acknowledges it");
         input=PoseTween.copy(input);input.seq=51;input.buttons=Commands.RIGHT;input.epoch=2;p.record(input,1123);
         check(p.sample(1124,frame,1,false)==null,"new incarnation rejects previous life's movement anchor");
      }
      private static function wire(check:Function):void {
         var enc:FrameDelta=new FrameDelta(),dec:FrameDelta=new FrameDelta(),history:Array=[],truth:Array=[],ok:Boolean=true;
         for(var frame:int=0;frame<12;frame++) {
            var source:Object={type:"frame",session:"边界",tick:frame,units:[],text:frame%2?"念力🙂":"",optional:null};
            for(var i:int=0;i<80;i++)source.units.push({id:i,x:i*.125+frame,hp:100-frame%7,
               pose:{c:[1,1,1,1,0,0,0,0],f:frame%3},names:["visVzz","闪电"],enabled:frame%2==0});
            if(frame%2)delete source.optional;
            var restored:Object=dec.decode(WireCodec.decode(WireCodec.encode(enc.encode(source))));
            history.push(restored);truth.push(JSON.parse(JSON.stringify(source)));
            for(i=0;i<history.length;i++)ok=ok && same(history[i],truth[i]);
         }
         check(ok,"binary transport and ordered deltas preserve dense native data and every older confirmation");
         enc=new FrameDelta();dec=new FrameDelta();
         var shared:Object={f:1,child:{a:1}},aliased:Object={type:"frame",session:"shared",units:[{pose:shared},{pose:shared}]};
         var old:Object=dec.decode(WireCodec.decode(WireCodec.encode(enc.encode(aliased))));
         var split:Object={type:"frame",session:"shared",units:[{pose:{f:2,child:{a:.4}}},{pose:{f:3,child:{a:.7}}}]};
         var next:Object=dec.decode(WireCodec.decode(WireCodec.encode(enc.encode(split))));
         check(same(next,split) && same(old,aliased) && next.units[0].pose!==next.units[1].pose,
            "shared immutable wire branches can diverge per entity without cross-changing poses or older frames");
         var greeting:Object=Commands.greeting("hello","test"),copy:Object=WireCodec.decode(WireCodec.encode(greeting));
         check(Commands.greetingMatches(copy,"test"),"uncompressed binary greeting retains the exact build contract");
      }
      private static function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null || b==null || typeof a!="object" || typeof b!="object" || (a is Array)!=(b is Array))return false;
         if(a is Array && a.length!=b.length)return false;
         var count:int=0;
         for(var key:String in a){++count;if(!b.hasOwnProperty(key) || !same(a[key],b[key]))return false;}
         for(key in b)--count;return count==0;
      }
      private static function nativeFieldSequence(check:Function):void {
         var a:FieldProbeState=new FieldProbeState(),b:FieldProbeState=new FieldProbeState();
         var enc:FrameDelta=new FrameDelta(),dec:FrameDelta=new FrameDelta(),history:Array=[],truth:Array=[],ok:Boolean=true;
         var initial:Object=NativeFields.capture(a);
         check(initial===NativeFields.capture(a),"unchanged native public storage reuses the same immutable scalar record");
         for(var tick:int=0;tick<64;tick++) {
            a.X=tick*.125;a.hp=100-int(tick/7);a.label=tick%2?"队友":"";a.active=tick%3!=0;
            a.optional=tick%4==0?NaN:tick%4==1?"名":tick%4==2?12:{untransported:true};
            a.nativeReference=tick%3==0?{arbitrary:tick}:tick%3==1?tick:"标量";
            a.typedBody=b;a.typedList=[tick];
            b.X=-tick;b.optional=tick%2?null:false;
            // Diagnostics may capture an intermediate state that is never sent.
            if(tick%5==0){a.hp-=1;NativeFields.capture(a);a.hp+=1;}
            var source:Object={type:"frame",session:"native-fields",tick:tick,units:[NativeFields.capture(a),NativeFields.capture(b)]};
            var expected:Object={type:"frame",session:"native-fields",tick:tick,units:[
               {X:a.X,hp:a.hp,label:a.label,active:a.active},{X:b.X,hp:b.hp,label:b.label,active:b.active}]};
            if(tick%4==1 || tick%4==2)expected.units[0].optional=a.optional;
            if(tick%3!=0)expected.units[0].nativeReference=a.nativeReference;
            if(tick%2==0)expected.units[1].optional=false;
            var actual:Object=dec.decode(WireCodec.decode(WireCodec.encode(enc.encode(source))));
            ok=ok && same(expected,actual);history.push(actual);truth.push(expected);
            for(var i:int=0;i<history.length;i++)ok=ok && same(history[i],truth[i]);
         }
         check(ok && initial.X==0 && initial.hp==100,
            "native scalar transport preserves exact values, removals, unsent captures, separate owners and all buffered frames",
            {frames:history.length});
      }
      private static function deltaSequence(check:Function):void {
         var enc:FrameDelta=new FrameDelta(),dec:FrameDelta=new FrameDelta(),history:Array=[],expected:Array=[],valid:Boolean=true,stable:Boolean=true;
         for(var tick:int=0;tick<32;tick++) {
            var source:Object={players:[],named:{},units:[],time:tick*25};
            for(var i:int=0;i<40+tick%3;i++) {
               var u:Object={id:i,x:i*20+(tick%2==0?tick:0),hp:100-int(tick/3),visible:tick%4!=0,
                  visual:{frame:tick%6,color:[1,1,1,1,0,0,0,0]},weapons:tick%5==0?[]:[{id:"lmg",hold:100-tick}]};
               if(tick%3==0)u.optional={value:tick};source.units.push(u);
            }
            source.named["room-"+(tick%4)]={tiles:tick%2==0?[[1,2,3],null]:{x:1,y:tick}};
            var actual:Object=dec.decode(JSON.parse(JSON.stringify(enc.encode(source))));
            valid=valid && same(source,actual);history.push(actual);expected.push(JSON.parse(JSON.stringify(source)));
            for(i=0;i<history.length;i++)stable=stable && same(history[i],expected[i]);
         }
         check(valid && stable,"ordered deltas survive wire serialization, additions, removals and type changes without changing buffered frames",
            {frames:history.length,current:valid,history:stable});
      }
   }
}
