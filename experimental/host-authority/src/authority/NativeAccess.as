package authority {
   import flash.display.MovieClip;
   import flash.system.ApplicationDomain;
   public class NativeAccess {
      public var domain:ApplicationDomain,world:Object,scope:NativeScope;
      public function NativeAccess(main:Object) {
         domain=main.loaderInfo.applicationDomain;
         world=definition("fe.World")["w"];
         scope=new NativeScope(world,definition("fe.inter.Appear"));
      }
      public function definition(name:String):Class{return domain.getDefinition(name) as Class;}
      public function visualClass(name:String):Class {
         name=name.replace("::",".");
         if(domain.hasDefinition(name))return domain.getDefinition(name) as Class;
         for each(var loader:Object in world.grafon.grLoaders) {
            var child:ApplicationDomain=loader.loader.contentLoaderInfo.applicationDomain;
            if(child.hasDefinition(name))return child.getDefinition(name) as Class;
         }
         throw new Error("Native visual asset unavailable: "+name);
      }
      public function ready():Boolean{return world!=null && world.gg!=null && world.loc!=null && world.land!=null && world.ng_wait==0;}
      public function checkHooks():void {
         for each(var name:String in ["fe.inter.Ctr","fe.loc.Location","fe.loc.Land","fe.unit.Unit","fe.unit.UnitPlayer","fe.graph.Grafon"])
            if(definition(name)["RCONNECT_AUTHORITY_HOOKS"]!==BuildInfo.NATIVE)throw new Error("Native hooks unavailable: "+name);
      }
      public function profile():Object {
         return PlainData.copy({pers:world.pers.save(),inventory:world.invent.save(),
            hp:world.gg.hp,mana:world.gg.mana,appearance:world.app.save(),alicorn:world.alicorn,hardInv:world.hardInv});
      }
      public function createPlayer(profile:Object,room:Object,x:Number,y:Number,id:int=1):PlayerActor {
         if(profile==null || profile.pers==null || profile.inventory==null)throw new Error("Missing character profile");
         var actor:PlayerActor=new PlayerActor(this,id),ctx:Object=actor.context;
         actor.owned=true;
         ctx.calcMass=ctx.calcMassW=true;ctx.checkLoot=false;ctx.t_battle=0;
         ctx.appearance=AppearanceState.capture(definition("fe.inter.Appear"),true);
         scope.run(ctx,function():void {
            ctx.loc=room;ctx.land=room.land;ctx.alicorn=Boolean(profile.alicorn);ctx.hardInv=Boolean(profile.hardInv);
            world.loc=room;world.land=room.land;world.alicorn=ctx.alicorn;world.hardInv=ctx.hardInv;
            var Pers:Class=definition("fe.unit.Pers"),Invent:Class=definition("fe.unit.Invent");
            var Ctr:Class=definition("fe.inter.Ctr"),Sats:Class=definition("fe.inter.Sats"),GUI:Class=definition("fe.inter.GUI");
            var Appear:Class=definition("fe.inter.Appear");ctx.app=new Appear();ctx.app.load(profile.appearance);world.app=ctx.app;
            ctx.pers=new Pers(profile.pers,null);world.pers=ctx.pers;
            var unit:AuthorityPlayer=new AuthorityPlayer();actor.unit=unit;world.gg=ctx.gg=unit;
            world.ctr=ctx.ctr=new Ctr(null,false);
            world.sats=ctx.sats=new Sats(new MovieClip());
            var visualClass:Class=world.vgui.constructor as Class;
            world.gui=ctx.gui=new GUI(new visualClass());
            ctx.gui.gg=unit;ctx.sats.gg=unit;
            world.invent=ctx.invent=new Invent(unit,profile.inventory,null);
            var g:Object=unit;g.ctr=ctx.ctr;g.sats=ctx.sats;
            g.attach();g.putLoc(room,x,y);g.setNull();
            // attach() schedules an equip animation. Complete that native equip
            // during construction, before exposing an actor to the session.
            if(ctx.invent.cWeaponId!=null && ctx.invent.cWeaponId!="" && g.currentWeapon==null) {
               g.changeWeapon(ctx.invent.cWeaponId,true);g.work="";g.t_work=0;
            }
            g.hp=Math.min(g.maxhp,Math.max(1,Number(profile.hp)));g.mana=Number(profile.mana);
            g.id="authority-player-"+id;g.disabled=false;g.invulner=false;
            unit.scope=scope;unit.context=ctx;
            if(room.units.indexOf(unit)<0)room.units.push(unit);
            // Players are advanced explicitly. Do not also insert in firstObj.
            g.addVisual();
         });
         scope.register(ctx);
         return actor;
      }
      public function roomKey():String {
         return keyFor(world.loc);
      }
      public function keyFor(l:Object):String {return String(l.land.act.id)+":"+get(l.land,"rconnectLayoutSeed",0)+":"+l.landX+":"+l.landY+":"+l.landZ+":"+l.landProb;}
      public static function get(object:Object,key:String,fallback:*=null):* {
         try{return object==null?fallback:object[key];}catch(error:*){return fallback;}
      }
   }
}
