package fa {
    import fe.inter.FAMenuBridge;
    import flash.display.*;
    import flash.events.MouseEvent;
    import flash.text.*;
    /** A contextual action inside the native Inventory > Weapons page. */
    public class WeaponMenu {
        // External probes live in another SWF domain; pass the real bridge class explicitly.
        public const bridge:Class=FAMenuBridge;
        public var root:Sprite=new Sprite(), action:Sprite=new Sprite(), selectedId:String="", enabled:Boolean=false;
        public var label:TextField=new TextField(), reason:TextField=new TextField();
        private var engine:Runtime, workbench:Workbench, page:*, game:*, signature:String="", chosen:String="";
        public function WeaponMenu(e:Runtime, ui:Workbench) {
            engine=e;workbench=ui;root.name="FirearmAttachmentsWeaponMenu";action.name="modify-selected-weapon";
            root.visible=false;root.addChild(action);action.mouseChildren=false;action.buttonMode=true;
            label.defaultTextFormat=new TextFormat("_sans",16,0x00ff99);label.width=166;label.height=29;
            label.x=7;label.y=4;label.mouseEnabled=false;label.selectable=false;action.addChild(label);
            reason.defaultTextFormat=new TextFormat("_sans",15,0x8affd0);reason.width=210;reason.height=39;
            reason.wordWrap=true;reason.multiline=true;reason.mouseEnabled=false;reason.selectable=false;reason.x=190;reason.y=-3;root.addChild(reason);
            action.addEventListener(MouseEvent.CLICK,activate);
            root.addEventListener(MouseEvent.MOUSE_DOWN,block);root.addEventListener(MouseEvent.MOUSE_UP,block);root.addEventListener(MouseEvent.CLICK,block);
        }
        private function block(e:MouseEvent):void { e.stopPropagation(); }
        public function showWeapons():void {
            if(!engine.ready()||engine.w.mm.active||engine.w.t_exit>0||engine.w.sats.active||engine.w.gg.sost>=3)return;
            engine.w.pip.onoff(2,1);tick();
        }
        public function tick():void {
            var w:*=engine.w;
            root.visible=false;enabled=false;selectedId="";
            if(w&&w.game!==game){game=w.game;chosen="";}
            if(workbench.opened)return;
            if(!engine.ready()||!w.pip.active||w.mm.active){chosen="";return;}
            var p:*=w.pip.currentPage;
            if(!p||!FAMenuBridge.isWeapons(p)){chosen="";return;}
            var host:MovieClip=FAMenuBridge.view(p);
            if(root.parent!==host){
                if(root.parent){root.parent.removeEventListener(MouseEvent.CLICK,rememberSelection,true);root.parent.removeChild(root);}
                host.addChild(root);host.addEventListener(MouseEvent.CLICK,rememberSelection,true,1000);signature="";chosen="";
            }
            // Between the native caps footer and storage toggle; do not cover weapon descriptions.
            page=p;root.x=240;root.y=642;root.visible=true;
            selectedId=chosen||FAMenuBridge.selectedId(page);
            var gun:*=selectedId?w.invent.weapons[selectedId]:null;
            var why:String="";
            if(w.pip.noAct||w.gg.pipOff||w.catPause)why="当前状态不能改装武器";
            else if(!selectedId)why="先在武器列表中选中一把枪";
            else if(!gun)why="这把武器已不在背包中";
            else if(!engine.catalog.guns[selectedId])why="所选武器尚未适配改装";
            enabled=why=="";
            var name:String=gun?String(gun.nazv):"";
            var next:String=selectedId+"|"+name+"|"+why;
            if(next!=signature) {
                signature=next;label.text=enabled?"改装所选武器":"无法改装";
                reason.text=enabled?"已选："+name:why;
                action.graphics.clear();action.graphics.lineStyle(1,enabled?0x00ff99:0x007e4b);
                action.graphics.beginFill(0x002116,.98);action.graphics.drawRect(0,0,180,32);action.graphics.endFill();
                action.alpha=enabled?1:.55;action.buttonMode=enabled;
            }
        }
        private function rememberSelection(e:MouseEvent):void {
            if(!ownsCurrentPage()||engine.w.pip.noAct||e.ctrlKey)return;
            var id:String=FAMenuBridge.clickedId(page,e.target as DisplayObject);
            if(id)chosen=id;
        }
        private function activate(e:MouseEvent):void {
            e.stopPropagation();tick();
            if(enabled)workbench.open(selectedId);
        }
        public function ownsCurrentPage():Boolean {
            return engine.ready()&&engine.w.pip.active&&engine.w.pip.currentPage===page&&FAMenuBridge.isWeapons(page);
        }
        public function refresh():void {
            if(ownsCurrentPage())FAMenuBridge.refresh(page);
            tick();
        }
    }
}
