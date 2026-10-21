      private function gateExpected():Boolean{return SeedGateCaseMode.EXPECTED;}
      private var seedSemantics:Array=[];
      private function recordSeed(label:String):void {
         seedSemantics.push({label:label,starts:mod.game.startCalls,restores:mod.game.restores,
            x:mod.game.gg.X,y:mod.game.gg.Y,epoch:mod.session.rooms.epoch,term:mod.session.rooms.term,
            ready:mod.session.rooms.ready,busy:mod.session.rooms.busy,hold:mod.game.roomHold,
            room:mod.game.roomKey(),readyMessages:count("ready"),acks:count("ack")});
      }
      private function finishSeed(t:Object):void {
         if(t!=null){mod.game.world.grafon.ready=true;t.unpainted=false;frame();render();}
      }
      private function seedCases():void {
         caseName="seed on/off complete lifecycle";seedPrepare();
         check(mod.game.startCalls==1 && mod.game.transition,"native travel starts once");
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo(67890)});
         check(mod.game.startCalls==1,"duplicate and different-seed prepare cannot replace active identity");
         var t:Object=seedComplete();
         check((t!=null)==gateExpected(),"ticket presence exactly matches explicit on/off case");
         check(t==null || (t.waiting && t.unpainted),"existing ticket initially waits for actual pixels");
         check(!mod.game.roomHold && !mod.game.world.onPause && mod.game.world.t_exit==19,"original native exit remains runnable");
         seedSeal(1);grant(2,1,"");
         check(mod.session.rooms.epoch==1 && count("ready")==0 && mod.game.restores==1,"old empty-id epoch cannot restore new destination");
         seedSeal(2,67890);
         check(mod.session.rooms.epoch==1 && count("ready")==0,"wrong seed cannot bind the barrier");
         seedArrive();check(count("ready")==1 && last("ready").travelId=="","one ready preserves the empty wire travel id");
         seedSeal();check(count("ready")==1,"repeated seal cannot duplicate ready");
         var moved:Object=seedInfo();moved.x=1400;moved.y=100;mod.session.rooms.observeHost(moved);
         var before:int=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1,"full checkpoint restore happens exactly once");
         check(mod.game.gg.X==800 && mod.game.gg.Y==40,"fixed first-seal entrance survives moving host snapshot");
         check(count("ack")== (gateExpected()?0:1) && mod.game.roomHold==gateExpected(),"only raster scheduling changes ACK timing");
         grant(2,2,"");check(mod.game.restores==before+1,"duplicate grant cannot restore twice");
         finishSeed(t);
         check(count("ack")==1 && last("ack").travelId=="" && !mod.game.roomHold,"both routes end with exactly one original empty-id ACK");
         check(mod.game.rasterFinishes==(gateExpected()?1:0),"only delayed route needs post-raster wall completion");
         render();check(count("ack")==1,"subsequent render cannot duplicate ACK");
         seedSeal(1);grant(2,1,"");
         check(mod.game.restores==before+1 && mod.session.rooms.epoch==2 && count("ack")==1,"old epoch stays rejected after successful restore");
         recordSeed("normal-complete");

         caseName="seed early seal";seedPrepare();seedSeal();
         check(count("ready")==0 && !mod.game.world.onPause,"early seal does not pause native generation");
         t=seedComplete();mod.game.transition=false;mod.game.world.t_exit=0;frame();
         check((t!=null)==gateExpected() && count("ready")==1,"same destination identity binds after construction in both modes");

         caseName="wrong actual seed";seedPrepare();t=seedComplete(67890);
         check(t==null,"wrong actual seed never receives a ticket");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before && count("ack")==0,"wrong actual Land cannot accept grant in either mode");
         recordSeed("wrong-constructed-seed");

         caseName="seed death before grant";seedPrepare();t=seedComplete();mod.game.dead=true;frame();render();
         check((t==null || (!t.waiting && t.unpainted)) && count("ack")==0,"death never claims unconfirmed pixels or ACK");
         recordSeed("death");

         caseName="same World replacement Game before grant";seedPrepare();t=seedComplete();seedArrive();before=mod.game.restores;
         mod.game.world.game={curLandId:"seedway",lands:{seedway:{id:"seedway",rnd:true}}};grant(2,2,"");frame();render();
         check((t==null || !t.waiting) && mod.game.restores==before && count("ack")==0,"new Game rejects previous empty-id grant before frame callback");
         recordSeed("replacement-game");

         caseName="seed disconnect";seedPrepare();t=seedComplete();mod.session.mode=Session.OFFLINE;frame();render();
         check((t==null || (!t.waiting && t.unpainted)) && count("ack")==0 && !mod.game.roomHold,"disconnect releases local scheduling without successful ACK");
         recordSeed("disconnect");

         caseName="seed config fallback";seedPrepare();t=seedComplete();mod.game.world.grafon.sceneCullRender=false;
         check(mod.session.rooms.openFirstRaster(mod.game.world,mod.game.loc,mod.game.world.grafon)==null && (t==null || !t.waiting),"unsupported configuration always falls back to original rendering");
         seedArrive();before=mod.game.restores;grant(2,2,"");
         check(mod.game.restores==before+1 && count("ack")==1 && last("ack").travelId=="" && mod.game.rasterFinishes==0,"fallback preserves full restore and one empty-id ACK");
         recordSeed("configuration-fallback");

         caseName="seed failed checkpoint";seedPrepare();t=seedComplete();seedArrive();before=Log.errors.length;
         mod.session.rooms.handle({type:"room",op:"grant",barrier:2,epoch:2,term:2,owner:false,travelId:"",key:mod.game.roomKey(),state:"invalid-checkpoint"});
         check(Log.errors.length==before+1 && (t==null || !t.waiting) && mod.game.roomHold && count("ack")==0,"restore failure keeps unconfirmed world blocked");
         before=mod.game.restores;grant(2,2,"");check(mod.game.restores==before && count("ack")==0,"late grant cannot revive a failed barrier");
         recordSeed("failed-restore");

         caseName="old pending barrier";settled();
         mod.session.rooms.handle({type:"room",op:"seal",barrier:2,epoch:1,info:mod.game.readWorldInfo()});
         mod.game.world.game.lands.seedway={id:"seedway",rnd:true};
         mod.session.rooms.handle({type:"room",op:"prepare",info:seedInfo()});t=seedComplete();
         check(t==null,"unfinished old barrier never takes over renderer");
         caseName="ordinary room";settled();mod.game.world.game.lands.seedway={id:"seedway",rnd:true};t=seedComplete();
         check(t==null,"ordinary room without successful seed prepare has no ticket");
      }
