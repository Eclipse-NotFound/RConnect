package fa {
    import flash.display.*;
    import flash.events.*;
    import flash.filesystem.*;
    import flash.utils.*;
    import flash.geom.Point;
    import flash.text.TextField;
    public class Runtime {
        public const version:String="0.3.5-b1";
        public var main:*, w:*, catalog:Catalog=new Catalog(), ui:Workbench, carrier:Carrier;
        public var states:Object={}, snapshots:Dictionary=new Dictionary(true), game:*, ticks:int=0;
        public var support:BipodSupport=new BipodSupport(), settings:AttachmentSettings;
        public var steady:int=0, modeWait:int=0;
        public function get deployed():Boolean {return support.deployed;}
        public function set deployed(v:Boolean):void {support.deployed=v;}
        public function get deploying():int {return support.remaining;}
        public function set deploying(v:int):void {support.remaining=v;}
        public var activeMelee:int=0, lastBullet:*, shotsFired:int=0, hits:int=0, lastMessage:String="";
        public var bayonetCombat:BayonetCombat=new BayonetCombat();
        public var bladeSweep:BladeSweep=new BladeSweep();
        public var grenadeMode:Boolean=false;
        private var WorldClass:Class, WeaponClass:Class, BulletClass:Class, bridge:Class, worldBridge:Class, playerBridge:Class;
        private var held:*, heldId:String="", prevX:Number=NaN, prevY:Number=NaN;
        private var entrance:Dictionary=new Dictionary(true), contacts:Dictionary=new Dictionary(true), swings:Dictionary=new Dictionary(true), slows:Dictionary=new Dictionary(true);
        private var overlay:Sprite=new Sprite(), visualGun:*, attachmentDrawing:Sprite;
        private var keys:Object={}, tickMark:int=-1, wasPlaying:Boolean=false, errors:int=0, heartbeat:int=0;
        private const SAVE_KEY:String="firearmattachments.v1";
        public const FIELDS:Array=["damage","precision","antiprec","drot","drot2","holder","rashod","reload","recharg","noise","shine","speed","prep","deviation"];
        public var authorityManaged:Boolean=false,authorityHeadless:Boolean=false,authoritySubmit:Function,authorityAllowHarm:Function;
        private var authorityStepping:Boolean=false,authorityRemoteView:Boolean=false,authorityRevision:uint=0,authorityCachedRevision:int=-1,authorityCachedAssemblies:Object,authorityPresentedRevision:int=-1;
        public function Runtime(host:*,headless:Boolean=false) {
            main=host;authorityHeadless=headless;settings=new AttachmentSettings(this,!headless);
            WorldClass=getDefinitionByName("fe.World") as Class;
            WeaponClass=getDefinitionByName("fe.weapon.Weapon") as Class;
            BulletClass=getDefinitionByName("fe.weapon.Bullet") as Class;
            if(headless)return;
            carrier=new Carrier(); carrier.name="FirearmAttachmentsCarrier";carrier.api=this;main.addChild(carrier);
            overlay.name="FirearmAttachmentsEffects";overlay.mouseEnabled=false;overlay.mouseChildren=false;
            main.stage.addEventListener(Event.ENTER_FRAME,before,false,100);
            main.stage.addEventListener(Event.ENTER_FRAME,after,false,-100);
            main.stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDown,false,1000);
            main.stage.addEventListener(KeyboardEvent.KEY_UP,keyUp,false,1000);
            for each(var down:String in [MouseEvent.MOUSE_DOWN,MouseEvent.RIGHT_MOUSE_DOWN,MouseEvent.MIDDLE_MOUSE_DOWN])main.stage.addEventListener(down,pointerDown,false,1000);
            for each(var up:String in [MouseEvent.MOUSE_UP,MouseEvent.RIGHT_MOUSE_UP,MouseEvent.MIDDLE_MOUSE_UP]) {
                main.stage.addEventListener(up,pointerUp,false,1000);
                // HUD/menus stop bubbling. Still release our latch when the mouse is released over them.
                main.stage.addEventListener(up,pointerUp,true,1000);
            }
            main.stage.addEventListener(Event.DEACTIVATE,deactivate);
            log("v"+version+" loaded; "+catalog.data.weapons.length+" guns / "+catalog.data.components.length+" parts / native 1.02");
        }
        public function log(s:String):void {
            try {var fs:FileStream=new FileStream();fs.open(File.applicationStorageDirectory.resolvePath("FirearmAttachments.log"),FileMode.APPEND);fs.writeUTFBytes("[FirearmAttachments] "+s+"\n");fs.close();}catch(e:Error){}
        }
        public function message(s:String):void {
            lastMessage=s;if(ui)ui.message(s);
            // Feedback survives removal of the custom gameplay bar; use the native short notice.
            if(playing()&&(!ui||!ui.opened))try{w.gui.messText("",s,false,false,45);}catch(ignored:Error){}
        }
        private function fail(e:Error):void { if(errors++<12)log("ERROR "+e.getStackTrace());message("改装异常已记入日志："+e.message); }
        public function ready():Boolean {return w&&w.gg&&w.invent&&w.game&&w.loc&&w.allStat>0;}
        public function playing():Boolean {return ready()&&!w.mm.active&&(!w.onPause||authorityRemoteView&&!authorityStepping)&&!w.pip.active&&!w.sats.active&&!w.stand.active&&!w.gui.guiPause&&!w.catPause&&!w.onConsol&&w.allStat==1&&w.t_exit==0&&w.gg.sost<3;}
        public function owned():Array {
            var a:Array=[]; if(!ready())return a;
            for each(var p:Object in catalog.data.weapons)if(w.invent.weapons[p.id])a.push(p.id);
            return a;
        }
        public function state(id:String):Object {if(!states[id])states[id]=Catalog.blank();return states[id];}
        public function persist():void {if(!authorityManaged&&game)game.triggers[SAVE_KEY]=JSON.stringify({version:1,weapons:states});}
        private function loadGame():void {
            bladeSweep.reset();
            if(ui&&ui.opened)ui.close();
            game=w.game;states={};snapshots=new Dictionary(true);held=null;heldId="";
            entrance=new Dictionary(true);contacts=new Dictionary(true);slows=new Dictionary(true);swings=new Dictionary(true);
            support.reset();activeMelee=0;modeWait=0;steady=0;prevX=prevY=NaN;grenadeMode=false;
            try {
                var raw:*=game.triggers[SAVE_KEY];
                if(raw is String&&raw.length<64000) {
                    var d:Object=JSON.parse(raw);
                    if(d.version==1&&d.weapons)for(var id:String in d.weapons) {
                        if(catalog.guns[id]&&!catalog.validate(id,d.weapons[id])) {
                            states[id]=d.weapons[id];
                            states[id].grenadeWait=Math.max(0,Math.min(60,int(states[id].grenadeWait)));
                            if(states[id].mode!="far")states[id].mode="near";
                        }
                    }
                }
            }catch(e:Error){log("save record rejected "+e.message);}
            persist();log("world bound; saved assemblies="+count(states));
        }
        private function count(o:Object):int {var n:int=0;for(var k:String in o)n++;return n;}
        public function capture(gun:*):Object {
            var a:Object=snapshots[gun];
            if(!a) {
                a={base:{},last:{},dev:Number(gun.devMult),lastDev:Number(gun.devMult),shots:int(gun.kol_shoot),variant:int(gun.variant),factor:1};
                for each(var k:String in FIELDS)a.base[k]=Number(gun[k]);
                snapshots[gun]=a;
            }
            return a;
        }
        public function apply(id:String):void {
            if(!ready())return;
            var gun:*=w.invent.weapons[id];if(!gun||!catalog.guns[id])return;
            var a:Object=capture(gun), k:String, s:Object=state(id);
            if(a.variant!=gun.variant) {
                var fresh:*=WeaponClass["create"](w.gg,id,gun.variant);
                if(fresh)for each(k in FIELDS)a.base[k]=Number(fresh[k]);
                a.variant=gun.variant;a.last={};
            } else {
                for each(k in FIELDS)if(a.last.hasOwnProperty(k)&&Number(gun[k])!=Number(a.last[k]))a.base[k]=Number(gun[k]);
            }
            if(Number(gun.devMult)!=Number(a.lastDev))a.dev=Number(gun.devMult);
            var current:Boolean=gun===w.gg.currentWeapon;
            var r:Object=catalog.numbers(id,a.base,s,current&&steady>=12,current&&deployed);
            if(current&&Catalog.has(s,"dot")&&!(Catalog.has(s,"magnifier")&&s.mode=="far")&&a.base.antiprec==0&&w.sats.que.length==0&&!playerBridge["hidden"](w.gg)) {
                var p:Number=Number(w.pers.runPenalty);
                if(p>0&&p<1&&(Math.abs(w.gg.dx)>10||Math.abs(w.gg.dy)>10))r.precision*=(1-p*.8)/(1-p);
            }
            for each(k in FIELDS){gun[k]=r[k];a.last[k]=Number(gun[k]);}
            gun.devMult=a.dev*r.jitter;a.lastDev=Number(gun.devMult);a.factor=r.recoilFactor;
            if(gun.hold>gun.holder) {
                var excess:int=gun.hold-gun.holder;gun.hold=gun.holder;
                if(gun.ammo!="recharg"&&gun.ammo!="not"&&w.invent.items[gun.ammo]) {w.invent.plusItem(gun.ammo,excess);w.calcMass=true;}
                log("capacity refund "+id+" "+excess+" "+gun.ammo);
            }
        }
        public function modify(id:String,result:Object):Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping) {
                if(result==null||result.error||catalog.validate(id,result.state))return false;
                authoritySubmit("modify",[id,Catalog.clone(result.state)]);message("改装请求已提交，等待宿主确认");return false;
            }
            if(result.error){message(result.error);return false;}
            if(!ready()||!w.invent.weapons[id]){message("背包中没有这把枪");return false;}
            var gun:*=w.invent.weapons[id];
            if(gun.t_reload>0||gun.t_attack>0){message("请等待射击或装填结束后改装");return false;}
            var e:String=catalog.validate(id,result.state);if(e){message(e);return false;}
            states[id]=result.state;++authorityRevision;support.reset();bladeSweep.reset();apply(id);persist();activeMelee=0;steady=0;grenadeMode=false;
            drawAttachments(true);try{w.gui.setWeapon();}catch(ignored:Error){}
            log("assembly "+id+" "+JSON.stringify(states[id]));message("装配已生效 · 随游戏存档保存");
            if(authorityManaged&&ui!=null)ui.authorityAcknowledged();return true;
        }
        public function reset(id:String):Boolean {var n:Object=Catalog.blank();n.grenadeWait=state(id).grenadeWait;return modify(id,{state:n});}
        private function before(e:Event):void {
            if(authorityManaged&&!authorityStepping){authorityView();return;}
            try {
                w=WorldClass.w;if(!authorityManaged)settings.tick();if(!authorityHeadless&&settings.isCapturingKey())keys={};if(!ready()){bladeSweep.reset();return;}
                if(game!==w.game){if(authorityManaged)game=w.game;else loadGame();}
                if(!ui&&!authorityHeadless)ui=new Workbench(this);
                if(!bridge)bridge=getDefinitionByName("fe.weapon.FAWeaponBridge") as Class;
                if(!worldBridge)worldBridge=getDefinitionByName("fe.FAWorldBridge") as Class;
                if(!playerBridge)playerBridge=getDefinitionByName("fe.unit.FAPlayerBridge") as Class;
                var gun:*=w.gg.currentWeapon;
                if(gun!==held) {held=gun;heldId=gun&&catalog.guns[gun.id]?gun.id:"";steady=0;support.reset();bladeSweep.reset();activeMelee=0;modeWait=0;grenadeMode=false;entrance=new Dictionary(true);swings=new Dictionary(true);drawAttachments(true);}
                wasPlaying=playing();tickMark=worldBridge["stamp"](w);
                if(!wasPlaying)bladeSweep.reset();
                if(wasPlaying) {
                    if(grenadeMode&&hasLauncher()){w.ctr.keyAttack=false;held.t_attack=Math.max(held.t_attack,2);}
                    var stationary:Boolean=w.gg.stay&&Math.abs(w.gg.dx)<1&&Math.abs(w.gg.dy)<1;
                    steady=stationary?steady+1:0;
                    support.update(bipodSample(),settings.values,false);
                    if(modeWait>0&&held)held.t_attack=Math.max(held.t_attack,2);
                    if(activeMelee>0&&held)held.t_attack=Math.max(held.t_attack,2);
                }
                for each(var id:String in owned())apply(id);
                if(held&&snapshots[held])snapshots[held].shots=int(held.kol_shoot);
                if(ui&&!authorityManaged)ui.tick();
            }catch(err:Error){if(authorityManaged)throw err;fail(err);}
        }
        private function after(e:Event):void {
            if(authorityManaged&&!authorityStepping)return;
            try {
                if(!ready())return;
                if(w.verror.visible){if(errors++<12)log("game error dialog: "+w.verror.txt.text);return;}
                if(wasPlaying&&(authorityStepping||worldBridge["stamp"](w)!=tickMark)) {
                    ticks++;
                    support.update(bipodSample(),settings.values,true);
                    if(modeWait>0)--modeWait;
                    for(var sid:String in states)if(states[sid].grenadeWait>0)--states[sid].grenadeWait;
                    if(held&&heldId) {
                        var a:Object=snapshots[held], delta:int=Math.max(0,int(held.kol_shoot)-int(a.shots));
                        if(delta&&a.factor<1)bridge["recoil"](held,a.factor,delta);
                        meleeStep();
                    }
                    slowStep();persist();
                }
                drawAttachments();
                if(getTimer()-heartbeat>10000){heartbeat=getTimer();log("tick "+ticks+" gun="+heldId);}
            }catch(err:Error){if(authorityManaged)throw err;fail(err);}
        }
        public function grenade():Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping)return authoritySubmit("grenade",[]);
            if(!playing()||!hasLauncher()){message("先在当前枪上安装下挂榴弹");return false;}
            var s:Object=state(heldId);
            if(s.grenadeWait>0||modeWait>0||activeMelee>0||held.t_reload>0){message("下挂尚未准备好");return false;}
            if(!w.invent.items.gren40||w.invent.items.gren40.kol<1){message("背包中需要普通40mm榴弹");return false;}
            var t:*=WeaponClass["create"](w.gg,"glau1",0);t.setPers(w.gg,w.pers);
            held.getBulXY();
            var b:*=new BulletClass(w.gg,held.bulX,held.bulY+3,t.vBullet);
            b.weap=t;b.weapId=heldId;b.rot=held.rot;b.vel=28;
            b.dx=Math.cos(b.rot)*28;b.dy=Math.sin(b.rot)*28;b.ddy=Number(WorldClass.ddy)*.85;b.vRot=true;
            b.knockx=Math.cos(b.rot);b.knocky=Math.sin(b.rot);b.damage=0;
            b.damageExpl=t.resultDamage(90,t.weaponSkill);b.tipDamage=4;b.explTip=1;b.explRadius=120*t.explRadMult;
            b.destroy=400;b.otbros=35*t.otbrosMult;b.precision=0;b.miss=0;b.critCh=0;b.spring=0;b.tipDecal=9;b.liv=100;
            var tile:*=w.loc.getAbsTile(b.X,b.Y);if(tile&&tile.phis)b.inWall=true;
            w.invent.minusItem("gren40",1,false);w.calcMass=true;held.t_attack=Math.max(held.t_attack,8);
            w.gg.makeNoise(800,true);w.gg.demask=Math.max(w.gg.demask,500);s.grenadeWait=60;
            try{var snd:Class=getDefinitionByName("fe.Snd") as Class;snd["ps"]("glau_s",held.X,held.Y);}catch(soundError:Error){}
            shotsFired++;lastBullet=b;persist();message("榴弹已发射 · 装填中");log("grenade fired ammo="+w.invent.items.gren40.kol+" v=28 g="+b.ddy+" damage="+b.damageExpl);return true;
        }
        public function bayonet():Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping)return authoritySubmit("bayonet",[]);
            if(!playing()||!heldId||activeMelee>0||held.t_reload>0||modeWait>0)return false;
            var spec:Object=meleeSpec();if(!spec){message("当前枪未安装刺刀");return false;}
            deployed=false;deploying=0;activeMelee=spec.period;swings=new Dictionary(true);
            held.t_attack=Math.max(held.t_attack,2);message(spec.motion=="swing"?"短刃挥击":"长刃突刺");return true;
        }
        public function bipod():Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping)return authoritySubmit("bipod",[]);
            if(!playing()||!heldId||!Catalog.has(state(heldId),"bipod"))return false;
            if(!support.toggle(bipodSample(),settings.values)){message("接地且移动速度低于设置阈值时才能展开");return false;}
            message(deployed?"两脚架已展开":deploying?"正在展开两脚架":"已收起；本次伏低不再自动展开");return true;
        }
        public function bipodSample():Object {
            if(!ready())return {available:false,ground:false,low:false,speed:0,angle:0,blocked:true};
            var low:Boolean=Boolean(settings.values.crouchBipod)&&w.gg.isSit||playerBridge&&playerBridge["hidden"](w.gg);
            return {available:heldId!=""&&Catalog.has(state(heldId),"bipod"),ground:Boolean(w.gg.stay),low:low,
                speed:Math.abs(Number(w.gg.dx)),angle:held?held.rot:0,
                blocked:activeMelee>0||w.gg.work=="unlurk"||w.gg.work=="lurk"&&w.gg.t_work>0};
        }
        public function optic():Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping)return authoritySubmit("optic",[]);
            if(!playing()||!heldId||!Catalog.has(state(heldId),"magnifier")||modeWait>0)return false;
            var s:Object=state(heldId);s.mode=s.mode=="far"?"near":"far";++authorityRevision;modeWait=8;persist();message(s.mode=="far"?"切换增倍瞄准":"切回快瞄红点");return true;
        }
        private function meleeSpec():Object {
            if(!heldId)return null;var s:Object=state(heldId);
            if(Catalog.has(s,"bayonet_short"))return catalog.parts.bayonet_short.melee;
            if(Catalog.has(s,"bayonet_long"))return catalog.parts.bayonet_long.melee;
            return null;
        }
        private function meleeStep():void {
            var m:Object=meleeSpec();if(!m){bladeSweep.reset();return;}
            held.getBulXY();var x:Number=held.bulX,y:Number=held.bulY,ang:Number=held.rot;
            var sweep:Array=bladeSweep.advance({gun:held,loc:w.loc,tick:ticks,x:x,y:y,px:held.X,py:held.Y,angle:ang,length:m.bladeLength,
                blocked:activeMelee>0||held.t_reload>0||modeWait>0});
            var age:int=m.period-activeMelee, striking:Boolean=activeMelee>0&&age>=m.phases[0]&&age<m.phases[0]+m.phases[1];
            if(striking&&m.motion=="swing")ang+=(age-m.phases[0]-.5)*m.arc*Math.PI/180;
            var reach:Number=m.bladeLength+(striking&&m.motion=="thrust"?30:0);
            var ex:Number=x+Math.cos(ang)*reach,ey:Number=y+Math.sin(ang)*reach;
            for each(var u:* in w.loc.units) {
                if(!u||u===w.gg||u.sost>=3||u.fraction<=0||u.disabled||getQualifiedClassName(u)=="fe.unit::UnitTrigger")continue;
                if((u.fraction>=100||u.fraction==w.gg.fraction)&&!(authorityManaged&&authorityAllowHarm!=null&&authorityAllowHarm(w.gg,u)))continue;
                var touch:Boolean=segmentBox(x,y,ex,ey,u.X1-4,u.Y1-4,u.X2+4,u.Y2+4)&&clearBlade(x,y,ex,ey);
                var cut:Boolean=sweep.length>0&&bladeSweep.intersects(sweep,u.X1-4,u.Y1-4,u.X2+4,u.Y2+4,clearBlade);
                var entered:Boolean=touch&&!entrance[u];
                if((touch&&striking&&!swings[u])||(!activeMelee&&(entered||cut))) {
                    if(!contacts[u]||ticks-int(contacts[u])>=(striking?1:m.contactCooldown)) {
                        var hit:Object=bayonetCombat.hit(w,held,m,u,striking,x,y,BulletClass);
                        contacts[u]=ticks;swings[u]=true;hits++;
                        slows[u]={until:ticks+Math.max(m.slowSteps,hit.push.steps),pushUntil:ticks+hit.push.steps,push:hit.push,factor:Number(u.maxhp)>1000?.9:.8};
                        log("bayonet "+(striking?"active":cut?"cut":"contact")+" target="+u.id+" damage="+hit.damage+" hpLoss="+hit.loss+" pier="+hit.pier+" relativeSpeed="+hit.relativeSpeed+" speedMult="+hit.speedMultiplier+" kick="+hit.push.kick+" recovery="+hit.push.steps);
                    }
                }
                entrance[u]=touch;
            }
            if(activeMelee>0)--activeMelee;
        }
        public static function segmentBox(x:Number,y:Number,ex:Number,ey:Number,x1:Number,y1:Number,x2:Number,y2:Number):Boolean {
            var lo:Number=0,hi:Number=1,dx:Number=ex-x,dy:Number=ey-y,p:Array=[-dx,dx,-dy,dy],q:Array=[x-x1,x2-x,y-y1,y2-y];
            for(var i:int=0;i<4;i++) {
                if(Math.abs(p[i])<.0001){if(q[i]<0)return false;}
                else {var t:Number=q[i]/p[i];if(p[i]<0)lo=Math.max(lo,t);else hi=Math.min(hi,t);if(lo>hi)return false;}
            }
            return true;
        }
        private function clearBlade(x:Number,y:Number,ex:Number,ey:Number):Boolean {
            var n:int=Math.ceil(Point.distance(new Point(x,y),new Point(ex,ey))/6);
            for(var i:int=0;i<=n;i++) {
                var px:Number=x+(ex-x)*i/Math.max(1,n),py:Number=y+(ey-y)*i/Math.max(1,n),t:*=w.loc.getAbsTile(px,py);
                if(t&&t.phis&&px>=t.phX1&&px<=t.phX2&&py>=t.phY1&&py<=t.phY2)return false;
            }
            return true;
        }
        private function slowStep():void {
            for(var u:* in slows) {
                if(!u||u.loc!==w.loc||u.sost>=3||ticks>=slows[u].until){delete slows[u];continue;}
                // Native telekinesis owns held and thrown velocity. The contact
                // slow still expires normally; it must not brake that impulse.
                if(Number(u.levit)>0||Number(u.t_throw)>0)continue;
                if(u.invulner||u.fixed||Number(u.knocked)<=0)continue;
                // Do not let the old speed cap erase the impulse we just supplied.
                if(slows[u].push.applied) {
                    if(ticks<slows[u].pushUntil)bayonetCombat.impulse.recover(u,slows[u].push);
                    continue;
                }
                // A speed cap, never repeated multiplication of the previous slowed velocity.
                var max:Number=Math.max(1,Number(u.maxSpeed))*slows[u].factor;
                u.dx=Math.max(-max,Math.min(max,Number(u.dx)));
                if(u.isFly)u.dy=Math.max(-max,Math.min(max,Number(u.dy)));
            }
        }
        private function drawAttachments(force:Boolean=false):void {
            if(!held||!heldId||!held.vis) {if(attachmentDrawing&&attachmentDrawing.parent)attachmentDrawing.parent.removeChild(attachmentDrawing);return;}
            if(force||visualGun!==held.vis) {
                if(attachmentDrawing&&attachmentDrawing.parent)attachmentDrawing.parent.removeChild(attachmentDrawing);
                visualGun=held.vis;attachmentDrawing=new Sprite();attachmentDrawing.mouseEnabled=false;held.vis.addChild(attachmentDrawing);
                var g:Graphics=attachmentDrawing.graphics,s:Object=state(heldId),len:Number=held.dlina;
                g.lineStyle(1,0x101c1c);g.beginFill(0x5a7770);
                if(Catalog.has(s,"grenade")){g.drawRoundRect(5,6,Math.max(18,len*.55),7,3);g.endFill();g.beginFill(0xd7b57a);g.drawRect(len*.55+3,7,3,5);}
                if(Catalog.has(s,"bayonet_short")||Catalog.has(s,"bayonet_long")){g.endFill();g.lineStyle(2,0xb8d4d0);g.moveTo(len*.6,6);g.lineTo(len+16,6);}
                if(Catalog.has(s,"dot")||Catalog.has(s,"scope")||Catalog.has(s,"scope_precision")){g.beginFill(0x2a4d46);g.drawRoundRect(4,-11,20,6,3);}
                g.endFill();
            }
            if(attachmentDrawing)attachmentDrawing.x=activeMelee>0?6:0;
        }
        public static function angleDelta(a:Number,b:Number):Number {var d:Number=Math.abs(a-b)%(Math.PI*2);return Math.min(d,Math.PI*2-d);}
        public function hasLauncher():Boolean {return ready()&&held===w.gg.currentWeapon&&heldId!=""&&Catalog.has(state(heldId),"grenade");}
        public function grenadeAmmo():int {return ready()&&w.invent.items.gren40?int(w.invent.items.gren40.kol):0;}
        public function grenadeKeyLabel():String {return settings.keyLabel();}
        public function handGrenadeKeyLabel():String {return ready()?String(w.ctr.retKey("keyGrenad")):"[G]";}
        public function toggleGrenadeMode():Boolean {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping)return authoritySubmit("grenadeMode",[]);
            if(!playing()||!hasLauncher()){message("先在当前枪上安装下挂榴弹");return false;}
            if(grenadeMode)leaveGrenadeMode();else {grenadeMode=true;w.ctr.keyAttack=false;held.t_attack=Math.max(held.t_attack,2);w.ctr.active=true;}
            message(grenadeMode?"下挂模式：左键发射40mm榴弹；再次点击下挂按钮返回主枪":"已切回主枪");return true;
        }
        public function leaveGrenadeMode():void {
            if(authorityManaged&&authoritySubmit!=null&&!authorityStepping){authoritySubmit("leaveGrenadeMode",[]);return;}
            // Release only our idle two-step lock, preserving a real shot's longer recovery.
            if(grenadeMode&&held&&held.t_attack<=2)held.t_attack=0;
            grenadeMode=false;
        }
        private function typing():Boolean {
            var f:TextField=main.stage.focus as TextField;
            var active:Boolean=f&&f.type=="input"&&f.stage!=null;
            if(active)for(var d:DisplayObject=f;d;d=d.parent)if(!d.visible){active=false;break;}
            return active;
        }
        private function inputReady():Boolean {
            // Ctr.active only suppresses the first left click after UI; native keyboard input ignores it.
            return playing()&&!w.ctr.setkeyOn&&!typing();
        }
        private function keyDown(e:KeyboardEvent):void {
            if(settings.isCapturingKey()){keys={};return;}
            // A consumed press stays ours until release, including OS repeat after a gun/menu switch.
            if(keys[e.keyCode]){e.stopImmediatePropagation();return;}
            if(ui&&ui.opened) {
                e.stopImmediatePropagation();keys[e.keyCode]=true;
                if(e.keyCode==27)ui.close();return;
            }
            if(!ready()||w.ctr.setkeyOn||typing())return;
            for each(var action:String in ["workbench","bayonet","bipod","optic","grenade"])if(settings.matchesAction(action,e)) {
                if(action=="workbench") {if(!playing())return;}
                else if(!inputReady())return;
                e.stopImmediatePropagation();keys[e.keyCode]=true;
                if(action=="workbench"&&ui)ui.open();else if(action=="bayonet")bayonet();else if(action=="bipod")bipod();else if(action=="optic")optic();else if(action=="grenade")grenade();
                return;
            }
        }
        private function pointerToken(e:MouseEvent):String {
            return e.type.indexOf("right")>=0?"rmb":e.type.indexOf("middle")>=0?"mmb":"lmb";
        }
        private function pointerDown(e:MouseEvent):void {
            var token:String=pointerToken(e),key:String="mouse:"+token;
            if(keys[key]){e.stopImmediatePropagation();return;}
            if(inputReady()&&hasLauncher()&&!e.altKey&&!e.ctrlKey&&grenadeMode&&token=="lmb") {
                if(token=="lmb"&&!w.ctr.active){w.ctr.active=true;e.stopImmediatePropagation();return;}
                e.stopImmediatePropagation();keys[key]=true;w.ctr.keyAttack=false;grenade();
            }
        }
        private function pointerUp(e:MouseEvent):void {delete keys["mouse:"+pointerToken(e)];}
        private function keyUp(e:KeyboardEvent):void {delete keys[e.keyCode];}
        private function deactivate(e:Event):void {keys={};leaveGrenadeMode();if(ui)ui.cancelDrag();}
        public function heldWeapon():* {return held;}
        public function bridgeClass():Class {return bridge;}
        /** B owns native stepping; these entrypoints must be called inside the
         * corresponding real player's World scope. No per-actor frame listener. */
        public function authorityBegin(remoteView:Boolean):void {
            authorityManaged=true;authorityRemoteView=remoteView;authorityPresentedRevision=-1;keys={};
        }
        public function authorityBind(profile:Object=null):void {
            w=WorldClass.w;game=w.game;authorityManaged=true;
            if(profile!=null) {
                if(profile.version!==1||profile.weapons==null)throw new Error("FA B profile version mismatch");
                states={};
                for(var id:String in profile.weapons)if(catalog.guns.hasOwnProperty(id)&&!catalog.validate(id,profile.weapons[id])) {
                    states[id]=Catalog.clone(profile.weapons[id]);states[id].grenadeWait=Math.max(0,Math.min(60,int(states[id].grenadeWait)));
                    if(states[id].mode!="far")states[id].mode="near";
                }
                if(profile.settings!=null)for(var key:String in AttachmentSettings.DEFAULTS)
                    if(profile.settings.hasOwnProperty(key))settings.values[key]=settings.sanitize(key,profile.settings[key]);
                settings.syncCatalog();
            }
            ++authorityRevision;authorityCachedRevision=-1;
            authorityPrime();
        }
        public function authorityProfile():Object {
            return {version:1,weapons:Catalog.clone(states),settings:Catalog.clone(settings.values)};
        }
        public function authorityResetActor():void {
            // Per-weapon snapshots are deliberately retained: native revival
            // keeps the same Weapon objects. Weak keys also permit replacement
            // characters to release their old weapons without importing bases.
            w=WorldClass.w;if(ui&&ui.opened)ui.close();
            if(attachmentDrawing&&attachmentDrawing.parent)attachmentDrawing.parent.removeChild(attachmentDrawing);
            attachmentDrawing=null;visualGun=null;held=null;heldId="";
            entrance=new Dictionary(true);contacts=new Dictionary(true);swings=new Dictionary(true);slows=new Dictionary(true);
            support.reset();bladeSweep.reset();activeMelee=modeWait=steady=0;grenadeMode=false;prevX=prevY=NaN;
            wasPlaying=false;tickMark=-1;
        }
        private function authorityView():void {
            if(authorityHeadless)return;
            w=WorldClass.w;settings.tick();
            if(!ready())return;
            if(!ui)ui=new Workbench(this);
            ui.tick();
        }
        public function authorityBefore():void {
            authorityStepping=true;try{before(null);}finally{authorityStepping=false;}
        }
        public function authorityAfter():void {
            authorityStepping=true;try{after(null);}finally{authorityStepping=false;}
        }
        public function authorityExecute(action:String,args:Array):Boolean {
            authorityStepping=true;
            try {
                authorityPrime();
                if(action=="modify") {
                    var candidate:Object=Catalog.clone(args[1]);candidate.grenadeWait=state(String(args[0])).grenadeWait;
                    if(candidate.mode!="far")candidate.mode="near";
                    return modify(String(args[0]),{state:candidate});
                }
                if(action=="grenade")return grenade();if(action=="bayonet")return bayonet();if(action=="bipod")return bipod();if(action=="optic")return optic();
                if(action=="grenadeMode")return toggleGrenadeMode();if(action=="leaveGrenadeMode"){leaveGrenadeMode();return true;}
            }finally{authorityStepping=false;}
            return false;
        }
        public function authoritySnapshot():Object {
            if(authorityCachedRevision!=int(authorityRevision)){authorityCachedAssemblies=Catalog.clone(states);authorityCachedRevision=int(authorityRevision);}
            var cooldowns:Object={};for(var id:String in states)if(states[id].grenadeWait>0)cooldowns[id]=int(states[id].grenadeWait);
            return {revision:authorityRevision,weapons:authorityCachedAssemblies,held:heldId,
                grenadeMode:grenadeMode,cooldowns:cooldowns,activeMelee:activeMelee,modeWait:modeWait,
                deployed:deployed,deploying:deploying,message:lastMessage};
        }
        public function authorityPresent(snapshot:Object):void {
            if(snapshot==null||authorityHeadless)return;
            w=WorldClass.w;if(!ready())return;
            if(authorityPresentedRevision!=int(snapshot.revision)){states=Catalog.clone(snapshot.weapons);authorityPresentedRevision=int(snapshot.revision);}
            held=w.gg.currentWeapon;heldId=held&&catalog.guns[held.id]?held.id:"";
            grenadeMode=snapshot.grenadeMode===true;activeMelee=int(snapshot.activeMelee);modeWait=int(snapshot.modeWait);
            deployed=snapshot.deployed===true;deploying=int(snapshot.deploying);
            for(var id:String in states)states[id].grenadeWait=snapshot.cooldowns==null?0:int(snapshot.cooldowns[id]);
            if(ui!=null)ui.authorityAcknowledged();
            if(snapshot.message && lastMessage!==snapshot.message)message(String(snapshot.message));
        }
        public function authorityStore(targetGame:Object):void {targetGame.triggers[SAVE_KEY]=JSON.stringify({version:1,weapons:states});}
        public function authorityPrime():void {
            w=WorldClass.w;if(!ready())return;
            if(!bridge)bridge=getDefinitionByName("fe.weapon.FAWeaponBridge") as Class;
            if(!worldBridge)worldBridge=getDefinitionByName("fe.FAWorldBridge") as Class;
            if(!playerBridge)playerBridge=getDefinitionByName("fe.unit.FAPlayerBridge") as Class;
            var gun:*=w.gg.currentWeapon;
            if(gun!==held){held=gun;heldId=gun&&catalog.guns[gun.id]?gun.id:"";steady=0;support.reset();bladeSweep.reset();activeMelee=0;modeWait=0;grenadeMode=false;entrance=new Dictionary(true);swings=new Dictionary(true);}
        }
        public function authoritySettings(value:Object):void {
            if(value==null)return;
            var changed:Boolean=false;
            for(var key:String in AttachmentSettings.DEFAULTS)if(value.hasOwnProperty(key)) {
                var next:*=settings.sanitize(key,value[key]);if(settings.values[key]!==next){settings.values[key]=next;changed=true;}
            }
            if(changed)settings.syncCatalog();
        }
        public function authorityDetach():void {
            authoritySubmit=null;authorityAllowHarm=null;
            if(authorityHeadless){if(attachmentDrawing&&attachmentDrawing.parent)attachmentDrawing.parent.removeChild(attachmentDrawing);return;}
            authorityManaged=false;authorityRemoteView=false;w=WorldClass.w;game=w.game;persist();keys={};bladeSweep.reset();
        }
    }
}
