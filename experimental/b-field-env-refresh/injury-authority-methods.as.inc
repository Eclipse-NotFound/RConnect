  public static function attachAuthority(owner:Object):Object {
   if(!owner||owner.version!==1||(owner.role!="host"&&owner.role!="client")||!owner.session)
    throw new Error("Invalid PermanentInjury authority request");
   if(authorityOwner!=null)throw new Error("PermanentInjury authority already attached");
   if(!world)world=getDefinitionByName("fe.World")["w"];
   if(!world||!world.pers||!("piEvent" in world.pers))throw new Error("PermanentInjury native hooks missing");
   authorityOwner=owner;authorityRole=owner.role;
   return {version:1,beforePlayer:beforeAuthorityPlayer,afterPlayer:afterAuthorityPlayer,
    snapshot:snapshotAuthority,present:presentAuthority,detach:function():void {
     if(authorityOwner!==owner)throw new Error("Stale PermanentInjury authority lease");
     authorityOwner=null;authorityRole="";
     // Confirmed join state remains on Pers and is saved by the ordinary game.
     if(world&&world.pers)delete records[world.pers];
    }};
  }
  private static function beforeAuthorityPlayer(p:*,seconds:Number):void {
   if(authorityRole!="host"||p!==world.pers||!isFinite(seconds)||seconds<0||seconds>1)
    throw new Error("PermanentInjury player context mismatch");
   dispatch(p,"tick",seconds);
  }
  private static function afterAuthorityPlayer(p:*):void {
   if(authorityRole!="host"||p!==world.pers)throw new Error("PermanentInjury player context mismatch");
   dispatch(p,"flush");
  }
  private static function snapshotAuthority(p:*):Object {
   if(authorityRole!="host"||p!==world.pers)throw new Error("PermanentInjury snapshot context mismatch");
   var r:Object=rec(p);flush(r);
   return {state:JSON.parse(JSON.stringify(r.s)),factors:JSON.parse(JSON.stringify(r.factor)),config:JSON.parse(JSON.stringify(config))};
  }
  public static function presentAuthority(value:Object):void {
   if(authorityRole!="client")throw new Error("PermanentInjury presentation requires client lease");
   if(!value||!value.state||!value.factors||!value.config)throw new Error("Missing confirmed PermanentInjury state");
   var s:Object=JSON.parse(JSON.stringify(value.state));InjuryCore.validate(s);
   var p:*=world.pers;p["piPermanent"]=s;
   config=JSON.parse(JSON.stringify(value.config));
   records[p]={s:s,queue:[],groups:{},stack:[],factor:JSON.parse(JSON.stringify(value.factors)),p:p};
   lastPers=p;ready=true;
   if(panel&&panel.visible)renderPanel();
  }
