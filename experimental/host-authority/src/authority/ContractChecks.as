package authority {
   import flash.geom.ColorTransform;
   /** Executed in the native AIR probe, with controlled inputs and explicit failures. */
   public class ContractChecks {
      private static function input(seq:int,buttons:int=0,actions:Array=null):Object {
         return {session:"fixture",player:1,epoch:1,weaponEpoch:1,room:"one",roomEpoch:1,seq:seq,
            buttons:buttons,aimX:100,aimY:80,actions:actions==null?[]:actions};
      }
      public static function run(check:Function):void {
         presentation(check);
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
      }
      private static function presentation(check:Function):void {
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
         var p:Object={x:10,y:20,sx:1,sy:1,r:179,a:1,v:true,f:1,children:[]};
         var q:Object={x:20,y:40,sx:1,sy:1,r:-179,a:1,v:true,f:2,children:[]};
         var v:Object=PoseTween.pose(p,q,.5);
         check(v.x==15 && v.y==30 && Math.abs(v.r-180)<.001 && v.f==1 && p.x==10,
            "motion crosses animation frames while poses stay discrete and angles take the short arc");
         q.sx=-1;v=PoseTween.pose(p,q,.5);
         check(v.sx==1 && v.r==179 && v.x==15,"weapon reflection is a discrete native flip, never a shrinking interpolated sprite");
      }
   }
}
