package lad {
    import flash.display.DisplayObject;
    import flash.display.Sprite;
    import flash.events.Event;
    import flash.events.DataEvent;
    import flash.events.KeyboardEvent;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.system.ApplicationDomain;
    import flash.text.TextField;
    import flash.text.TextFieldType;
    import flash.utils.getDefinitionByName;
    import flash.utils.getTimer;
    import flash.utils.Dictionary;

    public final class LadRuntime {
        public var enabled:Boolean=true;
        public var ambient:Number=0.14;
        public var detection:Boolean=true;
        public var world:*;
        public var location:*;
        public var lamps:Array=[];
        public var field:LadLightField=new LadLightField();
        public var store:LadStore=new LadStore();
        public var atmosphere:LadAtmosphere=new LadAtmosphere();
        public var keys:LadKeys=new LadKeys();
        public var projectiles:LadProjectiles=new LadProjectiles();
        public var machines:LadMachineLights=new LadMachineLights();
        public var landmarks:LadLandmarkLights=new LadLandmarkLights();
        public var environment:LadEnvironment=new LadEnvironment();
        public var lighting:LadLightingPreferences=new LadLightingPreferences();
        public var darkZones:Array=[];
        public var atmosphereTime:Number=0;
        public var lastExposure:Number=1;
        public var lastBaseVisibility:Number=0;
        public var repairProgress:Number=0;
        public var hits:int=0;
        public var repairs:int=0;
        public var steps:int=0;
        public var renders:int=0;
        public var lateRenders:int=0;
        public var preparedScenes:int=0;
        private var main:*;
        private var game:*;
        private var player:*;
        private var adapter:LadPlayerTick;
        private var lampLayer:Sprite=new Sprite();
        private var hud:LadHud=new LadHud();
        private var settings:*;
        private var targetClass:Class;
        private var repairHeld:Boolean=false;
        private var lightHeld:Boolean=false;
        private var repairLamp:Object;
        private var repairX:Number=0;
        private var repairY:Number=0;
        private var repairHp:Number=0;
        private var lastRender:int=0;
        private var lastProjectileSignature:String="";
        private var simulatedSinceFrame:Boolean=false;
        private var lastLog:int=0;
        private var notice:String="";
        private var noticeUntil:int=0;
        private var failedLocation:*=null;
        private var environmentKey:String="";
        private var ordinaryRaster:Object;
        public function LadRuntime(value:*) {
            main=value;lampLayer.name="LightAndDarknessFixtures";lampLayer.mouseEnabled=false;lampLayer.mouseChildren=false;
            atmosphere.load();
            lighting.load();ambient=0.14*lighting.multiplier;environment.brightness=lighting;
            main.addChild(new LadCarrier({version:"0.7.0",runtime:this}));
            main.addChild(hud);hud.visible=false;
            main.stage.addEventListener(Event.ENTER_FRAME,onFrame,false,-80);
            main.addEventListener(Event.ADDED,objectAdded,true);
            main.addEventListener("continuousSceneBeforeRaster",beforeSceneRaster);
            main.addEventListener("continuousSceneResetGeneration",resetSceneGeneration);
            main.stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDown,true,900);
            main.stage.addEventListener(KeyboardEvent.KEY_UP,keyUp,true,900);
            main.stage.addEventListener(Event.DEACTIVATE,deactivate);
            LadLog.write("v0.7.0 loaded");
        }
        /** First-pass omission only. Native BackObj fields stay unchanged until normal attach. */
        public function beginOrdinaryRaster(w:*,g:*,loc:*,firstRaster:Boolean):Object {
            try {
                if(!firstRaster || !enabled || !w || int(w.t_exit)!=19 || !loc || !loc.land || !loc.land.act
                    || !loc.land.act.rnd || loc.spaceX>48 || loc.spaceY>25 || loc.spaceX<=0 || loc.spaceY<=0
                    || !g || g.sceneLarge || loc===location || loc===failedLocation) return null;
                var ticket:Object={world:w,game:w.game,player:w.gg,loc:loc,grafon:g,lamps:[],omit:new Dictionary(true),
                    complete:false,cancelled:false,redrawBefore:int(g.sceneRedraws),redrawComplete:-1};
                if(!ordinaryRasterIdentity(ticket)) return null;
                cancelOrdinaryRaster(true);
                if(ordinaryRaster) return null; // A native draw still owns the pending ticket.
                for each(var bo:* in loc.backobjs) {
                    if(!LadLampCatalog.isLamp(String(bo.id)) || bo.vis==null) continue;
                    if(ticket.omit[bo]) return null;
                    ticket.lamps.push(bo);ticket.omit[bo]=true;
                }
                if(!ticket.lamps.length) return null;
                ordinaryRaster=ticket;return ticket;
            } catch(error:*) {LadLog.write("INITIAL_RASTER_PREPARE_FAILED "+error);}
            return null;
        }
        public function completeOrdinaryRaster(ticket:Object,success:Boolean):void {
            if(ticket==null || ticket!==ordinaryRaster) return;
            if(!success || int(ticket.grafon.sceneRedraws)!=int(ticket.redrawBefore)+1) {
                // No native references changed; leave the original draw/error outcome intact.
                ordinaryRaster=null;return;
            }
            ticket.redrawComplete=int(ticket.grafon.sceneRedraws);ticket.complete=true;
            if(ticket.cancelled || !enabled || !ordinaryRasterIdentity(ticket)) cancelOrdinaryRaster(true);
        }
        private function ordinaryRasterIdentity(ticket:Object):Boolean {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                var w:*=WorldClass["w"],loc:*=ticket.loc,g:*=ticket.grafon;
                return w===ticket.world && Number(WorldClass["boxDamage"])==0.2 && w.game===ticket.game
                    && w.game!=null && w.gg===ticket.player && w.gg!=null && w.gg.loc===loc
                    && loc.gg===w.gg && loc.active && w.loc===loc && w.land===loc.land && w.land.loc===loc
                    && w.grafon===g && g.loc===loc && loc.grafon===g && !g.sceneLarge && int(w.allStat)==1
                    && (!w.verror || !w.verror.visible);
            } catch(ignored:*) {}
            return false;
        }
        private function ordinaryRasterOwnsPixels(ticket:Object):Boolean {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                var w:*=WorldClass["w"],g:*=ticket.grafon;
                return ticket.complete && w===ticket.world && w.grafon===g && w.loc===ticket.loc
                    && g.loc===ticket.loc && !g.sceneLarge && int(g.sceneRedraws)==int(ticket.redrawComplete);
            } catch(ignored:*) {}
            return false;
        }
        private function restoreOrdinaryRefs(refs:Array):void {
            for each(var item:Object in refs) {
                if(item.bo.vis===null) item.bo.vis=item.vis;
                if(item.bo.light===null) item.bo.light=item.light;
                if(item.bo.erase===null) item.bo.erase=item.erase;
            }
        }
        private function cancelOrdinaryRaster(redraw:Boolean):void {
            var ticket:Object=ordinaryRaster;if(ticket==null) return;
            if(!ticket.complete) {ticket.cancelled=true;return;}
            ordinaryRaster=null;
            if(!redraw || !ordinaryRasterOwnsPixels(ticket)) return;
            var refs:Array=[];
            for each(var bo:* in ticket.lamps) refs.push({bo:bo,vis:bo.vis,light:bo.light,erase:bo.erase});
            try {
                // Strip BEFORE BAKE's clean comparison; restore INSIDE its mutation.
                for each(var item:Object in refs) {item.bo.vis=null;item.bo.light=null;item.bo.erase=null;}
                LadSceneBake.change(ticket.grafon,ticket.loc,
                    function():void {restoreOrdinaryRefs(refs);},ticket.world.cam);
            } finally {restoreOrdinaryRefs(refs);}
        }
        private function canUseOrdinaryRaster(loc:*,found:Array):Boolean {
            var ticket:Object=ordinaryRaster;if(ticket==null) return false;
            var same:Boolean=ticket.loc===loc && ordinaryRasterIdentity(ticket) && ordinaryRasterOwnsPixels(ticket)
                && found.length==ticket.lamps.length;
            var seen:Dictionary=new Dictionary(true);
            if(same) for each(var lamp:Object in found) {
                if(!ticket.omit[lamp.bo] || seen[lamp.bo]) {same=false;break;}
                seen[lamp.bo]=true;
            }
            if(!same) cancelOrdinaryRaster(true);
            return same;
        }
        private function objectAdded(event:Event):void {
            if(!enabled || !atmosphere.settings.projectiles || !location || !world || world.loc!==location) return;
            // addObj links the object before addVisual dispatches ADDED. Keep only
            // its identity here: Bullet construction/setBullet has not finished.
            var object:*=location.lastObj;
            if(object && object.vis===event.target) projectiles.observe(object);
        }
        private function resetSceneGeneration(event:DataEvent):void {
            if(game && store.writable && store.data) {
                var prefix:String=event.data+"|";
                for(var key:String in store.data.rooms)
                    if(key.indexOf(prefix)==0) delete store.data.rooms[key];
                store.flush();
            }
        }
        // The scene host has selected its new Location but has not rasterized
        // its backdrops yet. Strip converted artwork in that same first pass.
        private function beforeSceneRaster(event:Event):void {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                world=WorldClass["w"];
                if(!world || Number(WorldClass["boxDamage"])!=0.2) return;
                if(world.game!==game) {
                    detach(false);game=world.game;failedLocation=null;
                    if(game) {store.bind(game);atmosphere.bind(store.data.atmosphereSettings);}
                }
                if(!enabled || !game || !world.gg || world.loc!==world.grafon.loc || !world.grafon.sceneLarge
                    || world.loc===location || world.loc===failedLocation) return;
                cancelOrdinaryRaster(false);
                detach(false);
                try {attach(world.loc,true);preparedScenes++;}
                catch(error:*) {
                    failedLocation=world.loc;detach(false);
                    LadLog.write("PREPARE_FAILED "+error+" "+error.getStackTrace());
                }
            } catch(error:*) {LadLog.write("PREPARE_FAILED "+error+" "+error.getStackTrace());}
        }
        private function onFrame(event:Event):void {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                world=WorldClass["w"];
                if(ordinaryRaster && (!enabled || !ordinaryRasterIdentity(ordinaryRaster))) cancelOrdinaryRaster(true);
                if(world==null) return;
                if(Number(WorldClass["boxDamage"])!=0.2) {hud.visible=false;return;}
                registerSettings();
                if(keys.capturing()) {keys.clear();lightHeld=false;repairHeld=false;cancelRepair();}
                if(!keys.held("headlamp")) lightHeld=false;
                if(!keys.held("fixture")) {repairHeld=false;cancelRepair();}
                if(world.game!==game) {
                    detach(false);game=world.game;failedLocation=null;
                    if(game) {store.bind(game);atmosphere.bind(store.data.atmosphereSettings);}
                }
                if(!enabled || !game || !world.loc || !world.gg || !world.loc.active || world.allStat!=1) {hud.visible=false;return;}
                if(world.loc!==location && world.loc!==failedLocation) {
                    detach(false);
                    try {attach(world.loc);} catch(error:*) {
                        LadLog.write("ATTACH_FAILED "+error+" "+error.getStackTrace());
                        failedLocation=world.loc;detach(true);return;
                    }
                }
                if(location==null) return;
                ensureAdapter();placeLayers();
                if(player.sost>=3 || player.disabled) projectiles.clear();
                var transientChanged:Boolean=atmosphere.settings.projectiles && !world.onPause && projectiles.capture();
                if(transientChanged && simulatedSinceFrame) {
                    var currentView:Rectangle=viewport();
                    transientChanged=!field.bounds.containsRect(currentView) ||
                        LadProjectiles.signature(projectiles.lights(currentView,atmosphere.settings.projectileBrightness))!=lastProjectileSignature;
                }
                // Paused menus do not step gameplay; render only if it has not just been simulated.
                // A slow native frame must not trigger a second illumination pass
                // merely because its earlier simulation took longer than 60 ms.
                if(transientChanged || (!simulatedSinceFrame && getTimer()-lastRender>60)) {
                    if(simulatedSinceFrame)lateRenders++;
                    render();
                }
                simulatedSinceFrame=false;
                var near:Object=nearestLamp();
                var hint:String="";
                if(near) hint=needsRepair(near)?"灯具受损/故障 · 按住 "+keys.label("fixture")+" 维修（废金属 ×2）":keys.label("fixture")+" 切换附近灯具";
                if(near && !near.powered) hint+=" · 当前区域断电";
                if(getTimer()<noticeUntil) hint=notice;
                hud.visible=canAct();hud.show(main.stage.stageWidth,Boolean(store.data.headlamp),hint,repairProgress,keys.label("headlamp"));
                if(getTimer()-lastLog>10000) {
                    lastLog=getTimer();LadLog.write("heartbeat lamps="+lamps.length+" steps="+steps+" pulses="+projectiles.pulseCount+" renderMs="+field.elapsedMs);
                }
            } catch(error:*) {LadLog.write("FRAME_ERROR "+error+" "+error.getStackTrace());enabled=false;detach(true);}
        }
        private function attach(loc:*,beforeRaster:Boolean=false):void {
            location=loc;player=world.gg;
            if(atmosphere.settings.projectiles) projectiles.bind(world,loc);
            if(!store.writable) throw new Error("saved light state requires migration");
            var roomKey:String=LadStore.roomKey(loc);
            environment.bind(loc,world.grafon,roomKey);environmentKey=environment.contextSignature();
            lamps=LadLampCatalog.discover(loc,world.grafon,store.room(roomKey),atmosphere,roomKey,environment);
            darkZones=atmosphere.zones(loc,roomKey,environment);
            targetClass=ApplicationDomain.currentDomain.getDefinition("lad.native.LadLampTarget") as Class;
            var initialRaster:Boolean=!beforeRaster && canUseOrdinaryRaster(loc,lamps);
            if(lamps.length) {
                if(beforeRaster || initialRaster) LadLampCatalog.strip(lamps);
                else LadSceneBake.change(world.grafon,loc,function():void {LadLampCatalog.strip(lamps);},world.cam);
            }
            // Discover succeeded and the exact prepared set has now been stripped.
            // Original detach can handle later failures using this populated lamps array.
            if(initialRaster) ordinaryRaster=null;
            for each(var lamp:Object in lamps) {
                lampLayer.addChild(lamp.holder);
                lamp.proxy=new targetClass(this,lamp,loc);
                loc.units.push(lamp.proxy);
            }
            store.flush();syncLamps();ensureAdapter();
            if(!beforeRaster) {render();placeLayers();}
            LadLog.write("ATTACH room="+loc.id+" lamps="+lamps.length+" beforeRaster="+beforeRaster+" state="+LadStore.roomKey(loc));
        }
        private function detach(redraw:Boolean):void {
            if(ordinaryRaster && (redraw || ordinaryRaster.loc===location)) cancelOrdinaryRaster(redraw);
            cancelRepair();
            if(player && player.childObjs && player.childObjs["LightAndDarknessTick"]===adapter)
                delete player.childObjs["LightAndDarknessTick"];
            if(location) {
                for each(var lamp:Object in lamps) {
                    var at:int=location.units.indexOf(lamp.proxy);
                    if(at>=0) location.units.splice(at,1);
                    if(lamp.proxy) lamp.proxy.disabled=true;
                }
                if(redraw && world && world.loc===location && lamps.length) {
                    try {LadSceneBake.change(world.grafon,location,function():void {LadLampCatalog.restore(lamps);},world.cam);}
                    catch(error:*) {LadLampCatalog.restore(lamps);LadLog.write("RESTORE_FAILED "+error);}
                } else LadLampCatalog.restore(lamps);
            }
            while(lampLayer.numChildren) lampLayer.removeChildAt(0);
            if(lampLayer.parent) lampLayer.parent.removeChild(lampLayer);
            projectiles.clear();machines.clear();landmarks.clear();environment.clear();environmentKey="";field.clear();lamps=[];darkZones=[];location=null;player=null;adapter=null;hud.visible=false;simulatedSinceFrame=false;
        }
        private function ensureAdapter():void {
            var next:*=world.gg;
            if(next!==player || adapter==null) {player=next;adapter=new LadPlayerTick(this,player);}
            if(player.childObjs && player.sost<3 && !player.disabled)
                player.childObjs["LightAndDarknessTick"]=adapter;
        }
        private function syncLamps():void {
            for each(var lamp:Object in lamps) {
                lamp.powered=location.lightOn!=-1;
                if(lamp.nativeFrame!=lamp.bo.frame) {
                    lamp.nativeFrame=lamp.bo.frame;
                    lamp.state.on=lamp.bo.frame==lamp.onFrame;
                    store.flush();
                }
                lamp.power=atmosphere.power(lamp,atmosphereTime);LadLampCatalog.visual(lamp);
                if(lamp.proxy) {lamp.proxy.disabled=lamp.state.hp<=0;lamp.proxy.hp=lamp.state.hp;}
            }
        }
        private function placeLayers():void {
            var g:*=world.grafon,visual:*=g.visual;
            // Some scene hosts rasterize more chunks after the normal camera setup,
            // resetting native border scales to +2. Repair only that invalid state,
            // after the camera belongs to this location, without changing its zoom.
            if("sceneLarge" in g && g.sceneLarge && world.cam.maxsx==location.limX && world.cam.maxsy==location.limY
                && (g.ramT.scaleY>=0 || g.ramL.scaleX>=0)) world.cam.setZoom();
            if(lampLayer.parent!==visual) visual.addChild(lampLayer);
            var backIndex:int=visual.getChildIndex(g.visBack2);
            if(visual.getChildIndex(lampLayer)!=backIndex+1) visual.setChildIndex(lampLayer,backIndex+1);
            if(field.bitmap.parent!==visual) visual.addChild(field.bitmap);
            var index:int=visual.getChildIndex(g.visLight);
            var old:int=visual.getChildIndex(field.bitmap);
            var wanted:int=old<index?index-1:index;
            if(old!=wanted) visual.setChildIndex(field.bitmap,wanted);
        }
        public function lights(view:Rectangle=null):Array {
            var result:Array=location?environment.lights(view || field.bounds):[];
            for each(var lamp:Object in lamps) if(lamp.state.hp>0 && lamp.state.on && lamp.powered)
                result.push({id:lamp.key,x:lamp.x,y:lamp.y,radius:lamp.radius*lighting.lampRange,color:lamp.color,power:lamp.power,angle:0,cone:Math.PI*2,
                    staticScene:!atmosphere.settings.flicker || lamp.state.atmosphere.mode=="steady"});
            if(player && store.data.headlamp) {
                var x:Number=player.X+player.storona*12,y:Number=player.Y-player.scY*0.72;
                var angle:Number=Math.atan2(world.celY-y,world.celX-x);
                result.push({id:"headlamp",x:x,y:y,radius:440,color:0xfff0d6,power:1,angle:angle,cone:Math.PI*0.58});
                result.push({id:"headlamp-spill",x:x,y:y,radius:85,color:0xffedcf,power:0.8,angle:0,cone:Math.PI*2});
            }
            if(atmosphere.settings.projectiles) result=result.concat(projectiles.lights(view || field.bounds,atmosphere.settings.projectileBrightness));
            if(atmosphere.settings.machines && location && world) result=result.concat(machines.lights(location,world.grafon.visual,view || field.bounds));
            if(atmosphere.settings.landmarks && location && world) result=result.concat(landmarks.lights(location,world.grafon.visual,view || field.bounds));
            return result;
        }
        private function viewport():Rectangle {
            var visual:*=world.grafon.visual;
            var a:Point=visual.globalToLocal(new Point(0,0));
            var b:Point=visual.globalToLocal(new Point(main.stage.stageWidth,main.stage.stageHeight));
            return new Rectangle(a.x,a.y,b.x-a.x,b.y-a.y);
        }
        public function render():void {
            if(!location || !world) return;
            // Raster residency affects background light, not the authored dark-zone layout.
            var nextEnvironment:String=environment.contextSignature();
            if(nextEnvironment!=environmentKey) {environmentKey=nextEnvironment;darkZones=atmosphere.zones(location,LadStore.roomKey(location),environment);}
            syncLamps();
            var view:Rectangle=viewport();
            projectiles.setView(view);
            var artView:Rectangle=view.clone();artView.inflate(128,128);
            for each(var lamp:Object in lamps) {
                var show:Boolean=artView.intersects(lamp.bounds);
                if(lamp.holder.visible!=show) lamp.holder.visible=show;
            }
            var renderLights:Array=lights(view);
            field.render(location,view,renderLights,ambient,
                atmosphere.settings.darkZones?darkZones:null,atmosphere.settings.darkness,environment);
            lastProjectileSignature=LadProjectiles.signature(renderLights);
            lastRender=getTimer();renders++;
        }
        public function simulationStep(value:*):void {
            if(!enabled || value!==world.gg || world.loc!==location || !location || world.onPause) return;
            steps++;atmosphereTime+=1/30;
            if(atmosphere.settings.projectiles) {projectiles.bind(world,location);projectiles.advance();}
            render();
            simulatedSinceFrame=true;
            lastBaseVisibility=Number(value.visibility);
            lastExposure=field.sample(value.X,value.Y-value.scY/2);
            if(detection) value.visibility=lastBaseVisibility*(0.18+0.82*lastExposure);
            updateRepair();
        }
        public function hitLamp(lamp:Object,amount:Number,kind:int=0):Number {
            if(!enabled || !store.writable || lamps.indexOf(lamp)<0 || !isFinite(amount) || amount<=0 || lamp.state.hp<=0) return 0;
            var applied:Number=Math.min(Number(lamp.state.hp),amount);
            lamp.state.hp-=applied;hits++;store.flush();syncLamps();
            if(lamp.state.hp<=0) {message("灯具已损坏");LadLog.write("BROKEN "+lamp.key);}
            return applied;
        }
        public function setEnabled(value:Boolean):void {
            if(enabled==value) return;
            if(!value) detach(true);
            enabled=value;failedLocation=null;
        }
        public function toggleHeadlamp():void {
            if(!store.data) return;store.data.headlamp=!store.data.headlamp;store.flush();render();
        }
        private function canAct():Boolean {
            if(!world || !player || !location || world.onPause || world.allStat!=1 || player.sost>=3) return false;
            if(world.pip && world.pip.active || world.mm && world.mm.active || world.sats && world.sats.active) return false;
            if(world.onConsol || world.ctr && world.ctr.setkeyOn || world.stand && world.stand.active) return false;
            if(world.gui) {
                if(world.gui.guiPause) return false;
                // GUI.dial is internal in 1.02; use the public display tree.
                var dialog:DisplayObject=world.gui.vis?world.gui.vis.getChildByName("dial"):null;
                if(dialog && dialog.visible) return false;
            }
            var focus:*=main.stage.focus;
            if(focus is TextField && TextField(focus).type==TextFieldType.INPUT) {
                var visible:DisplayObject=focus as DisplayObject;
                while(visible) {if(!visible.visible) return true;visible=visible.parent;}
                return false;
            }
            return true;
        }
        private function keyDown(event:KeyboardEvent):void {
            if(keys.capturing()) {keys.clear();lightHeld=false;repairHeld=false;cancelRepair();return;}
            var fresh:Boolean=keys.observeDown(event);
            if(!canAct() || !enabled) return;
            if(keys.matches("headlamp",event)) {
                event.stopImmediatePropagation();
                if(fresh && !lightHeld){toggleHeadlamp();lightHeld=true;}
                return;
            }
            if(keys.matches("fixture",event)) {
                event.stopImmediatePropagation();if(!fresh || repairHeld) return;repairHeld=true;
                var lamp:Object=nearestLamp();if(!lamp) return;
                if(!needsRepair(lamp)) {lamp.state.on=!lamp.state.on;store.flush();syncLamps();return;}
                beginRepair(lamp);
            }
        }
        private function keyUp(event:KeyboardEvent):void {
            if(keys.capturing()) {keys.clear();lightHeld=false;repairHeld=false;cancelRepair();return;}
            keys.observeUp(event);
            if(!keys.held("headlamp")) lightHeld=false;
            if(repairHeld && !keys.held("fixture")) {repairHeld=false;cancelRepair();event.stopImmediatePropagation();}
        }
        private function deactivate(event:Event):void {keys.clear();repairHeld=false;lightHeld=false;cancelRepair();}
        public function nearestLamp():Object {
            if(!player) return null;
            var best:Object=null,distance:Number=160*160;
            for each(var lamp:Object in lamps) {
                var dx:Number=lamp.x-player.X,dy:Number=lamp.y-(player.Y-player.scY/2);
                var d:Number=dx*dx+dy*dy;
                if(d>=distance) continue;
                var length:Number=Math.sqrt(d);
                if(length>1 && field.traceRay(player.X,player.Y-player.scY/2,dx/length,dy/length,length)<length-3) continue;
                best=lamp;distance=d;
            }
            return best;
        }
        public function beginRepair(lamp:Object):Boolean {
            if(!canAct() || lamps.indexOf(lamp)<0 || lamp!==nearestLamp() || !needsRepair(lamp) || !store.writable) return false;
            if(!world.invent.items["scrap"] || world.invent.items["scrap"].kol<2) {message("维修需要废金属 ×2");return false;}
            repairLamp=lamp;repairX=player.X;repairY=player.Y;repairHp=player.hp;repairProgress=0;return true;
        }
        private function updateRepair():void {
            if(!repairLamp) return;
            if(!repairHeld || !keys.held("fixture") || !canAct() || player.hp<repairHp || Math.abs(player.X-repairX)>12 || Math.abs(player.Y-repairY)>12
                || nearestLamp()!==repairLamp || !needsRepair(repairLamp)) {cancelRepair();return;}
            repairProgress+=1/60; // Two seconds of native 30 Hz simulation, never wall-clock pause time.
            if(repairProgress>=1) {finishRepair(repairLamp);cancelRepair();}
        }
        public function finishRepair(lamp:Object):Boolean {
            if(!canAct() || !store.writable || lamp!==nearestLamp() || !needsRepair(lamp)) return false;
            var item:*=world.invent.items["scrap"];
            if(!item || item.kol<2) {message("废金属不足，维修未完成");return false;}
            var oldCount:int=item.kol,oldHp:Number=lamp.state.hp,oldOn:Boolean=lamp.state.on;
            var oldMode:String=lamp.state.atmosphere.mode,oldRepaired:Boolean=Boolean(lamp.state.atmosphere.repaired);
            try {
                world.invent.minusItem("scrap",2,false);
                if(item.kol!=oldCount-2) throw new Error("repair inventory mismatch");
                lamp.state.hp=40;lamp.state.on=true;lamp.state.atmosphere.mode="steady";lamp.state.atmosphere.repaired=true;store.flush();
                world.invent.calcMass();
            } catch(error:*) {
                item.kol=oldCount;lamp.state.hp=oldHp;lamp.state.on=oldOn;lamp.state.atmosphere.mode=oldMode;lamp.state.atmosphere.repaired=oldRepaired;store.flush();world.invent.calcMass();LadLog.write("REPAIR_ROLLBACK "+error);return false;
            }
            repairs++;syncLamps();render();message("灯具修复完成");LadLog.write("REPAIRED "+lamp.key);return true;
        }
        public function cancelRepair():void {repairLamp=null;repairProgress=0;}
        public function needsRepair(lamp:Object):Boolean {return lamp.state.hp<40 || lamp.state.atmosphere.mode!="steady";}
        public function setAtmospherePreference(key:String,value:*):void {
            if(!atmosphere.settings.hasOwnProperty(key)) return;
            var updated:Object=JSON.parse(JSON.stringify(atmosphere.settings));updated[key]=value;
            atmosphere.bind(updated);
            if(key=="projectiles") {projectiles.clear();if(atmosphere.settings.projectiles && location) projectiles.bind(world,location);}
            if(store.data) {store.data.atmosphereSettings=atmosphere.settings;store.flush();}
            render();
        }
        private function message(value:String):void {notice=value;noticeUntil=getTimer()+2400;}
        private function regionSetting(key:String,label:String):Object {
            var self:LadRuntime=this;
            return {key:"base_"+key,kind:"slider",label:label+"基础亮度 %",min:10,max:100,step:1,
                get:function():* {return Math.round(self.lighting.getLevel(key)*100);},
                set:function(v:*):void {self.lighting.setLevel(key,Number(v)/100);self.render();}};
        }
        private function registerSettings():void {
            var carrier:*=main.getChildByName("ModSettingsCarrier");
            keys.attach(carrier && "modAPI" in carrier?carrier.modAPI:null);
            if(!carrier || !("modAPI" in carrier) || carrier.modAPI===settings) return;
            var self:LadRuntime=this;
            carrier.modAPI.registerPage("light-and-darkness","光与暗",[
                {key:"enabled",kind:"check",label:"启用动态照明",get:function():* {return self.enabled;},set:function(v:*):void {self.setEnabled(Boolean(v));}},
                {key:"headlamp",kind:"check",label:"随身灯",get:function():* {return self.store.data?self.store.data.headlamp:true;},set:function(v:*):void {if(self.store.data){self.store.data.headlamp=Boolean(v);self.store.flush();}}},
                {key:"ambient",kind:"slider",label:"环境亮度总倍率",min:0.5,max:1.5,step:0.05,get:function():* {return self.ambient/0.14;},set:function(v:*):void {self.lighting.multiplier=LadAtmosphere.clamp(v,0.5,1.5,1);self.ambient=0.14*self.lighting.multiplier;self.render();}},
                {key:"detection",kind:"check",label:"明暗影响普通视觉发现",get:function():* {return self.detection;},set:function(v:*):void {self.detection=Boolean(v);}},
                {key:"flicker",kind:"check",label:"故障灯闪烁",get:function():* {return self.atmosphere.settings.flicker;},set:function(v:*):void {self.setAtmospherePreference("flicker",Boolean(v));}},
                {key:"lampBrightness",kind:"slider",label:"场景灯亮度倍率",min:0.25,max:1.5,step:0.05,get:function():* {return self.atmosphere.settings.brightness;},set:function(v:*):void {self.setAtmospherePreference("brightness",v);}},
                {key:"lampRange",kind:"slider",label:"场景灯照明范围倍率",min:0.5,max:1.5,step:0.05,get:function():* {return self.lighting.lampRange;},set:function(v:*):void {self.lighting.lampRange=LadAtmosphere.clamp(v,0.5,1.5,1.10);self.render();}},
                {key:"flickerSpeed",kind:"slider",label:"故障闪烁速度倍率",min:0.25,max:2,step:0.25,get:function():* {return self.atmosphere.settings.speed;},set:function(v:*):void {self.setAtmospherePreference("speed",v);}},
                {key:"darkZones",kind:"check",label:"局部黑暗区",get:function():* {return self.atmosphere.settings.darkZones;},set:function(v:*):void {self.setAtmospherePreference("darkZones",Boolean(v));}},
                {key:"darkness",kind:"slider",label:"黑暗区浓度",min:0,max:1,step:0.1,get:function():* {return self.atmosphere.settings.darkness;},set:function(v:*):void {self.setAtmospherePreference("darkness",v);}},
                {key:"projectiles",kind:"check",label:"弹丸与爆炸短暂照明",get:function():* {return self.atmosphere.settings.projectiles;},set:function(v:*):void {self.setAtmospherePreference("projectiles",Boolean(v));}},
                {key:"machines",kind:"check",label:"炮塔与蜘蛛地雷微光",get:function():* {return self.atmosphere.settings.machines;},set:function(v:*):void {self.setAtmospherePreference("machines",Boolean(v));}},
                {key:"landmarks",kind:"check",label:"存档点、出口、试炼入口与终端照明",get:function():* {return self.atmosphere.settings.landmarks;},set:function(v:*):void {self.setAtmospherePreference("landmarks",Boolean(v));}},
                {key:"projectileBrightness",kind:"slider",label:"弹丸照明亮度倍率",min:0.25,max:1.5,step:0.05,get:function():* {return self.atmosphere.settings.projectileBrightness;},set:function(v:*):void {self.setAtmospherePreference("projectileBrightness",v);}}
            ],function():void {self.lighting.save();},"附近灯具可开关；受损或故障时按住操作键维修，消耗废金属 ×2。改键见快捷键页。");
            var regionItems:Array=[];
            for(var i:int=0;i<LadLightingPreferences.KEYS.length;i++)regionItems.push(regionSetting(LadLightingPreferences.KEYS[i],LadLightingPreferences.LABELS[i]));
            carrier.modAPI.registerPage("light-and-darkness-regions","光与暗 · 地区亮度",regionItems,function():void {self.lighting.save();},
                "100% 保留原图亮度；室外天光默认100%，窗洞向室内渐弱。即时生效，关闭设置时跨存档保存；总倍率在光与暗页。灯光填补暗处，黑暗区仍可局部压暗。");
            settings=carrier.modAPI;
        }
    }
}
