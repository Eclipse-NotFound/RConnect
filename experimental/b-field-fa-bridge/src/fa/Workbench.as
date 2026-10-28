package fa {
    import flash.display.*;
    import flash.events.*;
    import flash.geom.*;
    import flash.text.*;
    import flash.utils.getDefinitionByName;
    public class Workbench {
        public var opened:Boolean=false, root:Sprite=new Sprite(), gunId:String="";
        public var targets:Array=[], buttons:Object={}, selected:String="", railTool:Boolean=false;
        public var menu:WeaponMenu;
        private var engine:Runtime, c:Catalog, content:Sprite=new Sprite(), status:TextField, detail:TextField;
        private var ghost:Sprite, drag:Object, railDrag:Object, priorPause:Boolean=false, pausedWorld:*, dirty:Boolean=true, fromMenu:Boolean=false;
        private var bezel:DisplayObject;
        public var session:AssemblySession, category:String="", compatibleOnly:Boolean=true;
        public var comparisonText:String="", candidateSummary:String="", lastPlacement:String="";
        private var marker:Sprite;
        private static const GROUPS:Object={optics:["dot","scope","scope_precision","magnifier"],handling:["light_stock","grip","bipod","starter"],muzzle:["suppressor","flash","brake","choke_tight","choke_wide","plasma_accel"],under:["bayonet_short","bayonet_long","grenade"],feed:["quick_mag","large_mag","recharge_cell","power_cell","economy_cell"]};
        private static const TITLES:Object={optics:"瞄准 / 观察",handling:"握持 / 控枪",muzzle:"枪口 / 弹道",under:"下挂 / 近战",feed:"供弹 / 续航"};
        private static const GREEN:uint=0x00ff99, DIM:uint=0x007e4b, YELLOW:uint=0xffff33;
        private static const SHORT_NAMES:Object={dot:"红点",scope:"中距镜",scope_precision:"精密镜",magnifier:"增倍镜",bayonet_short:"短刺刀",bayonet_long:"长刺刀",grenade:"榴弹筒",grip:"握把",starter:"启动器"};
        private var hint:String="拖动导轨格铺设，再把配件拖到绿色导轨；点选配件后点接口也可安装。";
        public function Workbench(e:Runtime) {
            engine=e;c=e.catalog;root.name="FirearmAttachmentsWorkbench";
            root.addChild(content);root.visible=false;engine.main.stage.addChild(root);
            menu=new WeaponMenu(engine,this);
            engine.main.stage.addEventListener(Event.RESIZE,resize);
            engine.main.stage.addEventListener(MouseEvent.MOUSE_MOVE,move,false,1000);
            engine.main.stage.addEventListener(MouseEvent.MOUSE_UP,up,false,1000);
            root.addEventListener(MouseEvent.MOUSE_DOWN,block);root.addEventListener(MouseEvent.CLICK,block);root.addEventListener(MouseEvent.MOUSE_WHEEL,block);
            resize(null);
        }
        private function block(e:Event):void {e.stopPropagation();}
        public function tick():void {
            if(opened&&(!engine.ready()||engine.w.game!==pausedWorld.game||engine.w.invent.weapons[gunId]!==pausedWorld.weapon)){close();return;}
            menu.tick();
            if(opened&&dirty)render();
        }
        public function open(id:String=""):void {
            if(opened||!engine.ready()||engine.w.mm.active)return;
            if(engine.w.t_exit>0||engine.w.sats.active||engine.w.gg.sost>=3){engine.message("请在正常游玩时打开改装台");return;}
            if(!id){menu.showWeapons();return;}
            if(!c.guns[id]||engine.owned().indexOf(id)<0){engine.message("所选武器尚未适配，或已不在背包中");return;}
            if(engine.w.pip.noAct||engine.w.gg.pipOff||engine.w.catPause){engine.message("当前状态不能改装武器");return;}
            gunId=id;fromMenu=menu.ownsCurrentPage();
            priorPause=engine.w.onPause;pausedWorld={world:engine.w,game:engine.w.game,weapon:engine.w.invent.weapons[id]};if(!engine.authorityManaged)engine.w.onPause=true;
            engine.leaveGrenadeMode();engine.w.ctr.clearAll();opened=true;root.visible=true;menu.root.visible=false;selected="";railTool=false;dirty=true;
            session=new AssemblySession(c);session.touch(gunId,engine.state(gunId));
            category="";hint="选择用途查看候选；所有改动先试装，应用后才改变实枪。";
            engine.main.stage.setChildIndex(root,engine.main.stage.numChildren-1);resize(null);render();
        }
        public function close():void {
            if(!opened)return;cancelDrag();opened=false;root.visible=false;
            var sameGame:Boolean=pausedWorld&&pausedWorld.world===engine.w&&pausedWorld.game===engine.w.game;
            if(sameGame&&!engine.authorityManaged)engine.w.onPause=priorPause;
            if(engine.w&&engine.w.ctr)engine.w.ctr.clearAll();
            if(sameGame&&fromMenu)menu.refresh();
            engine.persist();
        }
        public function message(s:String):void {hint=s;if(status)status.text=s;}
        public function authorityAcknowledged():void {
            if(opened&&session&&session.changed(gunId)&&AssemblySession.signature(assembly())==AssemblySession.signature(engine.state(gunId))) {
                session.commit(gunId,engine.state(gunId));dirty=true;message("宿主已确认改装");
            }
        }
        private function resize(e:Event):void {
            var st:Stage=engine.main.stage,sc:Number=Math.min(st.stageWidth/1280,st.stageHeight/800);
            root.graphics.clear();root.graphics.beginFill(0x000000);root.graphics.drawRect(0,0,st.stageWidth,st.stageHeight);root.graphics.endFill();
            content.scaleX=content.scaleY=sc;content.x=(st.stageWidth-1280*sc)/2;content.y=(st.stageHeight-800*sc)/2;
        }
        private function text(parent:Sprite,s:String,x:Number,y:Number,width:Number,height:Number,size:int=16,col:uint=0x00ff99,bold:Boolean=false):TextField {
            var t:TextField=new TextField();t.defaultTextFormat=new TextFormat("_sans",size,col,false);t.text=s;t.x=x;t.y=y;t.width=width;t.height=height;t.multiline=true;t.wordWrap=true;t.selectable=false;t.mouseEnabled=false;parent.addChild(t);return t;
        }
        private function panel(x:Number,y:Number,w:Number,h:Number,color:uint=0x000000):void {
            var p:Shape=new Shape(),g:Graphics=p.graphics;g.lineStyle(1,DIM);g.beginFill(color,.92);g.drawRect(x,y,w,h);g.endFill();
            g.lineStyle(1,GREEN,.08);for(var sy:int=y+3;sy<y+h;sy+=3){g.moveTo(x+1,sy);g.lineTo(x+w-1,sy);}content.addChild(p);
        }
        private function button(parent:Sprite,s:String,x:Number,y:Number,w:Number,h:Number,fn:Function,key:String,col:uint=0x003322):Sprite {
            var b:Sprite=new Sprite();b.name=key;b.x=x;b.y=y;b.buttonMode=true;b.mouseChildren=false;
            var mx:Matrix=new Matrix();mx.createGradientBox(w,h);
            b.graphics.lineStyle(1,GREEN);b.graphics.beginGradientFill(GradientType.LINEAR,[col,0x000000,col],[1,1,1],[0,127,255],mx);b.graphics.drawRect(0,0,w,h);b.graphics.endFill();
            text(b,s,7,3,w-14,h-3,15,GREEN);parent.addChild(b);buttons[key]=b;
            b.addEventListener(MouseEvent.ROLL_OVER,function(e:MouseEvent):void{b.graphics.lineStyle(1,GREEN);b.graphics.drawRect(2,2,w-4,h-4);});
            b.addEventListener(MouseEvent.ROLL_OUT,function(e:MouseEvent):void{b.graphics.lineStyle(1,col);b.graphics.drawRect(2,2,w-4,h-4);});
            if(fn!=null)b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void{e.stopPropagation();fn();});
            return b;
        }
        public function assembly():Object {return session.drafts[gunId];}
        private function groupFor(id:String):String {for(var g:String in GROUPS)if(GROUPS[g].indexOf(id)>=0)return g;return "";}
        private function chooseGroup(g:String):void {cancelDrag();category=g;selected="";railTool=false;dirty=true;message("选择候选比较，再拖到接口或使用试装按钮。");}
        private function groupButton(g:String,x:int,y:int,width:int):void {
            button(content,TITLES[g],x,y,width,30,function():void{chooseGroup(g);},"group:"+g,category==g?0x00663d:0x002116);
        }
        private function perform(result:Object):Boolean {
            var e:String=session.accept(gunId,result);
            message(e?e+"；配置未改变。":"已加入试装；可继续移动、拆卸，或应用到实枪。");dirty=true;return e=="";
        }
        private function restoreDraft():void {cancelDrag();session.restore(gunId);selected="";railTool=false;message("已恢复本轮原配置：导轨、部件、位置和镜组模式均已恢复。");dirty=true;}
        private function applyDraft():void {
            if(!session.changed(gunId)){message("没有待应用的改动。");return;}
            if(AssemblySession.signature(engine.state(gunId))!=AssemblySession.signature(session.originals[gunId])) {message("实枪配置已在别处改变，请关闭后重新打开；未覆盖实枪。");return;}
            var n:Object=Catalog.clone(assembly());n.grenadeWait=engine.state(gunId).grenadeWait;
            if(engine.modify(gunId,{state:n})) {session.commit(gunId,engine.state(gunId));message("已应用到实枪；本轮原配置已更新，随游戏存档保存。");}
            dirty=true;
        }
        private function plan(id:String):Object {
            var p:Object=c.parts[id],s:Object=assembly(),r:Object,first:Object;
            if(!p)return {error:"请选择一个配件",blockers:[]};
            var start:int=Catalog.FACES.indexOf(p.slot)>=0?int(s.railStarts[p.slot]):0;
            var end:int=Catalog.FACES.indexOf(p.slot)>=0?int(s.railStarts[p.slot])+int(s.rails[p.slot])-int(p.length):0;
            for(var i:int=start;i<=Math.max(start,end);i++) {
                r=c.install(gunId,s,id,p.slot,i);r.start=i;r.face=p.slot;r.blockers=[];
                if(!r.error)return r;if(!first)first=r;
            }
            for each(var other:String in s.items)if(other!=id&&c.parts[other].slot==p.slot&&Catalog.FACES.indexOf(p.slot)>=0) {
                if(int(s.positions[other])<start+p.length&&int(s.positions[other])+int(c.parts[other].length)>start)first.blockers.push(other);
            }
            return first;
        }
        private function replacementText(n:Object):String {
            var removed:Array=[];for each(var id:String in assembly().items)if(!Catalog.has(n,id))removed.push(c.parts[id].name);
            return removed.length?"将替换："+removed.join("、"):"不移除其他部件";
        }
        private function chooseInstalled(id:String):void {selected=id;category=groupFor(id);railTool=false;dirty=true;message("已选 "+c.parts[id].name+"；拖动枪上标签移动，或拆下。");}
        private function overview(s:Object):void {
            text(content,"装配总览",36,121,225,28,20);
            text(content,"点击枪旁用途选择配件",36,155,225,27,15,DIM);
            var y:int=194;
            if(!s.items.length)text(content,"尚未安装配件。\n先铺轨，或选择独立接口。",36,y,228,80,16);
            for each(var id:String in s.items) {
                installedRow(id,y);y+=45;
            }
            button(content,"清空试装配件与导轨",36,650,230,31,function():void {
                var blank:Object=Catalog.blank();blank.grenadeWait=assembly().grenadeWait;selected="";perform({state:blank});
            },"clear");
            text(content,"只清试装，可撤销或恢复原配置",36,686,230,23,13,DIM);
        }
        private function installedRow(id:String,y:int):void {
            var p:Object=c.parts[id],loc:String=Catalog.SLOTS[p.slot];
            if(p.length)loc+=" "+(int(assembly().positions[id])+1)+"—"+(int(assembly().positions[id])+int(p.length))+"格";
            var row:Sprite=button(content,"",36,y,230,39,function():void{chooseInstalled(id);},"row:"+id);
            text(row,p.name,7,1,216,22,15);text(row,loc,7,21,216,18,12,DIM);
        }
        private function explainPlan(p:Object):String {
            if(!p.error)return replacementText(p.state)+"；"+Catalog.SLOTS[p.face]+(c.parts[selected].length?" "+(p.start+1)+"—"+(p.start+int(c.parts[selected].length))+"格":"");
            var occupied:Array=[];
            for each(var id:String in p.blockers)occupied.push(c.parts[id].name+"占"+(int(assembly().positions[id])+1)+"—"+(int(assembly().positions[id])+int(c.parts[id].length))+"格");
            return p.error+(occupied.length?"："+occupied.join("、")+"。先移动或拆下占位件。":"");
        }
        public function render():void {
            if(!opened)return;
            dirty=false;while(content.numChildren)content.removeChildAt(0);content.graphics.clear();
            targets=[];buttons={};backdrop();
            var w:Object=c.guns[gunId],s:Object=assembly(),actual:*=engine.w.invent.weapons[gunId];
            text(content,"枪械改装",26,23,270,38,26,GREEN);
            text(content,"武器菜单 › 改装 · 免费试装",27,61,310,24,14,DIM);
            text(content,actual.nazv||w.name,350,22,650,40,24,GREEN);
            button(content,fromMenu?"返回武器菜单 Esc":"取消并关闭 Esc",1054,22,198,33,close,"close");
            text(content,session.changed(gunId)?"试装中 · 实枪尚未改变":"与本轮原配置相同",385,62,560,27,16,session.changed(gunId)?YELLOW:DIM);
            panel(22,108,260,610);panel(302,108,686,610);panel(1000,108,258,610);
            if(category) {
                text(content,TITLES[category],36,119,225,28,20);
                button(content,"‹ 装配总览",36,156,125,28,function():void{category="";selected="";dirty=true;},"overview");
                button(content,compatibleOnly?"仅适配":"全部",172,156,94,28,function():void{compatibleOnly=!compatibleOnly;dirty=true;},"filter");
                var row:int=0,hidden:int=0;
                for each(var pid:String in GROUPS[category]) {
                    if(compatibleOnly&&c.parts[pid].compat.indexOf(gunId)<0){hidden++;continue;}
                    card(pid,36,198+row*64,230,55);row++;
                }
                if(!row)text(content,"此枪没有适配的此类配件。\\n可切换用途或查看全部。",36,220,230,72,16);
                text(content,hidden?"已隐藏 "+hidden+" 件不适配配件":"已列出此用途全部配件",36,650,229,24,14,DIM);
                text(content,"点选比较 · 拖动试装",36,679,230,24,15,GREEN);
            } else overview(s);
            text(content,"枪体 / 导轨与接口",319,119,330,27,18);
            button(content,railTool?"铺轨中":"铺轨 / 调整",805,118,163,29,function():void{cancelDrag();railTool=!railTool;selected="";dirty=true;message("拖过同侧格子确定起点和长度；占位冲突会保留原配置。");},"rail-tool",railTool?0x00663d:0x003322);
            groupButton("optics",542,166,180);groupButton("handling",319,219,170);groupButton("muzzle",797,219,171);
            drawGun(actual);drawInstalled(s);
            rails("top",w.rails.top,railX("top"),292,s);rails("side",w.rails.side,railX("side"),356,s);rails("under",w.rails.under,railX("under"),446,s);
            socket("stock",320,402,116,w.stock);socket("muzzle",855,360,116,true);socket("mag",448,501,142,true);socket("bipod",692,501,142,w.bipod);
            groupButton("under",505,548,208);groupButton("feed",733,548,235);
            text(content,"枪尾",319,330,60,24,13,DIM);text(content,"枪口 →",903,330,74,24,13,DIM);
            detail=text(content,selected?describe(selected):"先选用途，再比较配件。导轨按连续多格占位；独立接口不占导轨。",320,591,648,72,16,GREEN);
            var proposed:Object=selected?plan(selected):null;
            candidateSummary=proposed?explainPlan(proposed):"";
            text(content,candidateSummary,320,666,648,42,15,proposed&&proposed.error?YELLOW:GREEN);
            drawComparison(actual,s,proposed);
            button(content,"撤销一步",26,734,120,32,function():void{cancelDrag();message(session.undo(gunId)?"已撤销上一步试装。":"没有可撤销的操作。");dirty=true;},"undo");
            button(content,"恢复本轮原配置",158,734,194,32,restoreDraft,"restore");
            var installed:Boolean=selected&&Catalog.has(s,selected);
            button(content,installed?"拆下所选":"拆下部件",367,734,155,32,function():void{if(selected&&Catalog.has(assembly(),selected))perform({state:c.remove(assembly(),selected)});else message("请先选中已装部件。");},"remove");
            buttons.remove.alpha=installed?1:.4;
            button(content,installed?"已在试装配置中":"试装所选配件",536,734,210,32,function():void{if(selected&&!Catalog.has(assembly(),selected))perform(plan(selected));else message("请先点选一个未安装的候选；已装部件可直接拖动。");},"install");
            buttons.install.alpha=proposed&&!proposed.error&&!installed?1:.4;
            if(proposed&&proposed.error&&proposed.blockers.length) {
                var blocked:String=proposed.blockers[0];
                button(content,"定位占位部件",758,734,178,32,function():void{chooseInstalled(blocked);},"resolve");
            }
            button(content,"应用当前枪配置",1000,734,258,32,applyDraft,"apply",session.changed(gunId)?0x00663d:0x002116);
            status=text(content,hint,28,774,1230,25,14,YELLOW);resize(null);
        }
        private function drawComparison(actual:*,s:Object,proposed:Object):void {
            var base:Object=engine.capture(actual).base;
            var a:Object=c.numbers(gunId,base,session.originals[gunId]),b:Object=c.numbers(gunId,base,s);
            var p:Object=proposed&&!proposed.error?c.numbers(gunId,base,proposed.state):null;
            text(content,"整枪比较",1015,121,220,28,20);
            text(content,"原配 → 试装 → 候选",1015,158,225,25,15,DIM);
            comparisonText="原配 → 试装 → 候选\n";
            var fields:Array=["damage","precision","drot","holder","reload","jitter","recoilFactor","noise"];
            var labels:Array=["单弹基础伤害","精度距离","追枪速度 °/步","弹仓容量","装填步数","随机偏角倍率","上跳倍率","枪声传播参数"];
            for(var i:int=0;i<fields.length;i++) {
                var f:String=fields[i],factor:Number=f=="drot"?180/Math.PI:1;
                var row:String=statValue(f,a[f]*factor)+" → "+statValue(f,b[f]*factor)+" → "+(p?statValue(f,p[f]*factor):"—");
                text(content,labels[i],1015,200+i*53,226,23,14,DIM);
                text(content,row,1015,222+i*53,226,27,17,p&&p[f]!=b[f]?YELLOW:GREEN);
                comparisonText+=labels[i]+" "+row+"\n";
            }
            text(content,"按移动、脚架收起计算。\n条件加成见配件说明。\n精度距离不等于命中率。",1015,642,225,69,14,DIM);
        }
        private function statValue(field:String,n:Number):String {return field=="drot"&&n==0?"即时":num(n);}
        private function num(n:Number):String {return String(Math.round(n*100)/100);}
        private function railX(face:String):Number {return c.guns[gunId].body=="短枪"?(face=="top"?554:face=="side"?584:640):(face=="top"?430:face=="side"?490:590);}
        private function cards(ids:Array,x:Number,y:Number,width:Number,height:Number,horiz:Boolean):void {
            for(var i:int=0;i<ids.length;i++)card(ids[i],x+(horiz?i*(width+7):0),y+(horiz?0:i*(height+9)),width,height);
        }
        private function card(id:String,x:Number,y:Number,width:Number,height:Number):void {
            var p:Object=c.parts[id],allowed:Boolean=p.compat.indexOf(gunId)>=0,installed:Boolean=Catalog.has(assembly(),id);
            var b:Sprite=button(content,"",x,y,width,height,null,"part:"+id,selected==id?0x00663d:installed?0x00472b:0x002116);
            icon(b,id,8,height/2,0.45);
            text(b,p.name,36,3,width-41,23,15,allowed?GREEN:DIM);
            if(height>30)text(b,allowed?(installed?"已装 / 可移动":p.length?p.length+" 格 / "+Catalog.SLOTS[p.slot]:Catalog.SLOTS[p.slot]+"接口"):"此枪不适配",36,24,width-41,height-23,12,allowed?GREEN:DIM);
            if(installed){b.graphics.lineStyle(1,GREEN);b.graphics.drawRect(2,2,width-4,height-4);}
            b.alpha=allowed?1:.6;


            b.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void {
                e.stopImmediatePropagation();selected=id;railTool=false;
                if(!allowed){message("此枪不支持 "+p.name);dirty=true;return;}
                beginDrag(id,e);
            });
        }
        private function describe(id:String):String {var p:Object=c.parts[id];return p?p.name+"："+p.benefit+" "+p.cost:"";}
        private function rails(face:String,n:int,x:Number,y:Number,s:Object):void {
            text(content,Catalog.SLOTS[face],x-90,y+2,88,22,14,GREEN);
            var pitch:int=43;
            for(var i:int=0;i<n;i++) {
                var installed:Boolean=i>=s.railStarts[face]&&i<s.railStarts[face]+s.rails[face];
                var cell:Sprite=new Sprite();cell.x=x+i*pitch;cell.y=y;cell.name="rail:"+face+":"+i;cell.buttonMode=true;
                cell.graphics.lineStyle(1,installed?GREEN:DIM);cell.graphics.beginFill(installed?0x005533:0x00190f,.93);cell.graphics.drawRect(0,0,39,25);cell.graphics.endFill();
                text(cell,String(i+1),13,2,26,22,13,installed?GREEN:DIM);content.addChild(cell);buttons[cell.name]=cell;
                var t:Object={face:face,start:i,rect:new Rectangle(cell.x,cell.y,39,25)};targets.push(t);cellDown(cell,t);
            }
            for each(var id:String in s.items)if(c.parts[id].slot==face) {
                var p:Object=c.parts[id],px:Number=x+int(s.positions[id])*pitch;
                var b:Sprite=button(content,SHORT_NAMES[id]||p.name,px,y-24,p.length*pitch-4,23,null,"installed:"+id,0x00663d);
                installedDown(b,id);
            }
        }
        private function cellDown(b:Sprite,t:Object):void {
            b.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void {
                e.stopImmediatePropagation();
                if(railTool||!selected){railDrag={face:t.face,start:t.start,last:t.start};message("向同一侧拖动以确定导轨长度");}
                else {var r:Object=c.install(gunId,assembly(),selected,t.face,t.start);perform(r);}
            });
        }
        private function installedDown(b:Sprite,id:String):void {b.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void{e.stopImmediatePropagation();selected=id;category=groupFor(id);railTool=false;beginDrag(id,e);});}
        private function socket(slot:String,x:Number,y:Number,width:Number,allowed:Boolean):void {
            var id:String="";for each(var pid:String in assembly().items)if(c.parts[pid].slot==slot)id=pid;
            var b:Sprite=button(content,id?c.parts[id].name:Catalog.SLOTS[slot]+(allowed?"接口":" / 无"),x,y,width,30,null,"socket:"+slot,allowed?0x003322:0x00140d);
            if(allowed)targets.push({face:slot,start:0,rect:new Rectangle(x,y,width,30)});else b.alpha=.5;
            b.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void {
                e.stopImmediatePropagation();if(!allowed)return;
                if(selected&&c.parts[selected].slot==slot&&selected!=id){perform(c.install(gunId,assembly(),selected,slot,0));}
                else if(id){selected=id;category=groupFor(id);beginDrag(id,e);}
                else {chooseGroup(slot=="mag"?"feed":slot=="muzzle"?"muzzle":"handling");}
            });
        }
        private function beginDrag(id:String,e:MouseEvent):void {
            cancelDrag();drag={id:id,x:e.stageX,y:e.stageY,moved:false};ghost=new Sprite();ghost.mouseEnabled=false;ghost.mouseChildren=false;
            ghost.graphics.lineStyle(2,GREEN);ghost.graphics.beginFill(0x003322,.95);ghost.graphics.drawRect(0,0,180,38);ghost.graphics.endFill();
            text(ghost,c.parts[id].name,9,8,164,27,14);content.addChild(ghost);positionGhost(e);if(detail)detail.text=describe(id);message(describe(id));
        }
        private function positionGhost(e:MouseEvent):Point {var pt:Point=content.globalToLocal(new Point(e.stageX,e.stageY));if(ghost){ghost.x=pt.x-35;ghost.y=pt.y-18;}return pt;}
        private function target(pt:Point):Object {for each(var t:Object in targets)if(t.rect.containsPoint(pt))return t;return null;}
        private function move(e:MouseEvent):void {
            if(!opened)return;
            if(drag) {
                if(Math.abs(e.stageX-drag.x)+Math.abs(e.stageY-drag.y)>5)drag.moved=true;
                var pt:Point=positionGhost(e),t:Object=target(pt);
                if(marker&&marker.parent)marker.parent.removeChild(marker);marker=null;
                if(t){var r:Object=c.install(gunId,assembly(),drag.id,t.face,t.start);ghost.alpha=r.error?.45:1;
                    marker=new Sprite();marker.mouseEnabled=false;marker.mouseChildren=false;marker.graphics.lineStyle(3,r.error?0xffaa55:YELLOW);
                    marker.graphics.drawRect(t.rect.x,t.rect.y,Math.min(Math.max(1,int(c.parts[drag.id].length))*43-4,980-t.rect.x),t.rect.height);content.addChildAt(marker,content.numChildren-1);
                    lastPlacement=r.error?r.error:"可放置 "+c.parts[drag.id].name+" / "+c.parts[drag.id].length+"格";
                    message(r.error?r.error+"；松开不会改变配置":"松开试装至 "+Catalog.SLOTS[t.face]);}
                e.stopImmediatePropagation();
            }
            if(railDrag){t=target(content.globalToLocal(new Point(e.stageX,e.stageY)));if(t&&t.face==railDrag.face){railDrag.last=t.start;message("铺设 "+Catalog.SLOTS[t.face]+" "+(Math.abs(t.start-railDrag.start)+1)+" 格");}e.stopImmediatePropagation();}
        }
        private function up(e:MouseEvent):void {
            if(!opened)return;
            if(drag) {
                var id:String=drag.id,moved:Boolean=drag.moved,t:Object=target(content.globalToLocal(new Point(e.stageX,e.stageY)));
                if(moved&&t)perform(c.install(gunId,assembly(),id,t.face,t.start));
                else if(moved)message("未落在接口上，装配保持原样");
                cancelDrag();dirty=true;e.stopImmediatePropagation();
            }
            if(railDrag) {
                var a:int=Math.min(railDrag.start,railDrag.last),len:int=Math.abs(railDrag.last-railDrag.start)+1;
                perform(c.paint(gunId,assembly(),railDrag.face,a,len));railDrag=null;railTool=false;dirty=true;e.stopImmediatePropagation();
            }
        }
        public function cancelDrag():void {if(marker&&marker.parent)marker.parent.removeChild(marker);marker=null;drag=null;railDrag=null;if(ghost&&ghost.parent)ghost.parent.removeChild(ghost);ghost=null;}
        private function drawGun(w:*):void {
            var body:Sprite=new Sprite();body.x=383;body.y=322;content.addChild(body);
            var g:Graphics=body.graphics;g.lineStyle(2,0x799585);g.beginFill(0x36473f);
            if(c.guns[gunId].body=="短枪") {
                g.drawRoundRect(115,0,220,40,9);g.endFill();g.beginFill(0x27352d);g.moveTo(150,34);g.lineTo(207,34);g.lineTo(187,111);g.lineTo(136,111);g.lineTo(150,34);
            } else {
                g.moveTo(0,15);g.lineTo(97,23);g.lineTo(110,5);g.lineTo(280,5);g.lineTo(300,16);g.lineTo(375,16);g.lineTo(375,41);g.lineTo(280,41);g.lineTo(245,56);g.lineTo(116,56);g.lineTo(83,51);g.lineTo(0,70);g.lineTo(0,15);
                g.endFill();g.beginFill(0x45594c);g.drawRoundRect(288,19,184,16,4);g.endFill();g.beginFill(0x26372e);g.drawRoundRect(130,50,29,60,5);g.drawRoundRect(220,51,46,65,5);
                if(gunId=="minigun"){g.drawRect(330,8,146,9);g.drawRect(330,39,146,9);g.drawRoundRect(444,3,29,53,8);}
                if(gunId=="lasr"||gunId=="rechr"){g.endFill();g.beginFill(0xb46045);g.drawRect(294,25,111,4);}
                if(gunId=="plar"){g.endFill();g.beginFill(0x86ba76);g.drawRoundRect(297,16,58,26,9);}
            }
            g.endFill();g.lineStyle(1,0x8ba38e,.45);for(var i:int=0;i<6;i++){g.moveTo(295+i*10,17);g.lineTo(295+i*10,40);}
            // Actual gun art where available, framed inside the same rail coordinate system.
            try {
                var Art:Class=w.vWeapon as Class,art:DisplayObject=Art&&gunId!="p10mm"?new Art():null;
                if(art){if(art is MovieClip)MovieClip(art).gotoAndStop(1);var b:Rectangle=art.getBounds(art);if(b.width>5&&b.height>3){var shortGun:Boolean=c.guns[gunId].body=="短枪";var sc:Number=Math.min((shortGun?300:470)/b.width,170/b.height);art.scaleX=art.scaleY=sc;art.x=(shortGun?100:0)-b.x*sc;art.y=38-(b.y+b.height/2)*sc;body.addChild(art);g.clear();}}
            }catch(e:Error){}
        }
        private function backdrop():void {
            if(!bezel)try {
                var Skin:Class=getDefinitionByName("visPipBuck") as Class,skin:MovieClip=new Skin();skin.gotoAndStop(1);
                for(var i:int=0;i<skin.numChildren;i++){var child:DisplayObject=skin.getChildAt(i);child.visible=child.name=="skin";if(child is MovieClip)MovieClip(child).stop();}
                var bounds:Rectangle=skin.skin.getBounds(skin);
                skin.scaleX=1280/bounds.width;skin.scaleY=800/bounds.height;skin.x=-bounds.x*skin.scaleX;skin.y=-bounds.y*skin.scaleY;skin.mouseChildren=false;skin.mouseEnabled=false;bezel=skin;
            }catch(e:Error){}
            if(bezel)content.addChild(bezel);
            var screen:Shape=new Shape();screen.graphics.beginFill(0x000000,.82);screen.graphics.drawRect(16,16,1248,770);screen.graphics.endFill();content.addChild(screen);
        }
        private function drawInstalled(s:Object):void {
            for each(var id:String in s.items) {
                var p:Object=c.parts[id],face:String=p.slot,x:Number=0,y:Number=0,sc:Number=1;
                if(face=="top"){x=railX(face)+8+int(s.positions[id])*43;y=321;sc=p.length*43/55;}
                else if(face=="under"){x=railX(face)+8+int(s.positions[id])*43;y=399;sc=p.length*43/55;}
                else if(face=="muzzle"){x=838;y=347;}
                else if(face=="stock"){x=390;y=354;}
                else if(face=="mag"){x=582;y=403;}
                else if(face=="bipod"){x=746;y=403;}
                else if(face=="side"){x=railX(face)+10+int(s.positions[id])*43;y=381;}
                if(x){var drawing:Sprite=icon(content,id,x,y,1);drawing.scaleX=sc;drawing.scaleY=1;}
            }
        }
        private function icon(parent:Sprite,id:String,x:Number,y:Number,scale:Number):Sprite {
            var s:Sprite=new Sprite();s.x=x;s.y=y;s.scaleX=s.scaleY=scale;parent.addChild(s);var g:Graphics=s.graphics;
            s.mouseEnabled=false;s.mouseChildren=false;g.lineStyle(1.5,GREEN,1,false,LineScaleMode.NONE);g.beginFill(0x003322);
            if(id.indexOf("bayonet")>=0){g.moveTo(0,5);g.lineTo(14,-4);g.lineTo(53,-5);g.lineTo(42,4);g.lineTo(14,7);g.lineTo(0,5);}
            else if(id=="grenade"){g.drawRect(1,-8,51,16);g.endFill();g.lineStyle(1.5,GREEN,1,false,LineScaleMode.NONE);g.moveTo(6,-12);g.lineTo(43,-12);g.moveTo(15,8);g.lineTo(9,17);for(var r:int=8;r<42;r+=6){g.moveTo(r,-6);g.lineTo(r,6);}}
            else if(id=="dot"||id.indexOf("scope")>=0||id=="magnifier"){g.drawRoundRect(2,-8,45,16,5);g.drawRect(15,8,15,5);}
            else if(c.parts[id].slot=="mag"){g.moveTo(9,-18);g.lineTo(37,-18);g.lineTo(31,21);g.lineTo(7,21);g.lineTo(9,-18);}
            else if(id=="bipod"){g.endFill();g.moveTo(25,-13);g.lineTo(6,23);g.moveTo(25,-13);g.lineTo(47,23);}
            else if(id=="grip"){g.drawRoundRect(14,-17,18,37,4);}
            else {g.drawRoundRect(3,-10,46,20,4);}
            g.endFill();return s;
        }
    }
}
