package addiction {
 import flash.display.*;import flash.events.*;import flash.text.*;
 public class Panel {
  public var runtime:Runtime;public var root:Sprite=new Sprite(),openButton:Sprite,body:Sprite=new Sprite(),cancelButton:Sprite;
  public var expanded:Boolean=false;public var selected:String='dash',quantity:int=1;
  private var status:TextField,info:TextField;private var messageLeft:int=0;private var rows:Sprite=new Sprite();private var treatment:Boolean=false;
  private var edge:Shape=new Shape();
  private var doseButtons:Array=[];
  public function Panel(r:Runtime){runtime=r;root.name='AddictionSystemPanel';r.main.stage.addChild(edge);r.main.stage.addChild(root);r.main.stage.addEventListener(KeyboardEvent.KEY_DOWN,onKey);
   openButton=button('战斗药品',0,0,135,function(e:MouseEvent):void{expanded=!expanded;refresh();});root.addChild(openButton);
   root.addChild(body);body.y=36;body.graphics.beginFill(0x102120,.98);body.graphics.lineStyle(1,0x49bb95);body.graphics.drawRoundRect(0,0,550,440,12);body.graphics.endFill();
   body.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void{e.stopPropagation();});
   text(body,'战斗药品 · 同批服用 / 临床疗程',18,12,510,30,19);
   body.addChild(button('收起',455,9,78,function(e:MouseEvent):void{expanded=false;refresh();}));
   text(body,'同批多颗补强度，上限为原始药效；持续时间不叠加。',18,49,515,42,14);
   rows.y=94;body.addChild(rows);
   doseButtons.push(body.addChild(button('−',18,354,44,function(e:MouseEvent):void{quantity=Math.max(1,quantity-1);refresh();})));
   doseButtons.push(body.addChild(button('+',150,354,44,function(e:MouseEvent):void{quantity=Math.min(1000,quantity+1);refresh();})));
   doseButtons.push(body.addChild(button('服用本批',208,354,132,function(e:MouseEvent):void{runtime.dose(selected,quantity);refresh();})));
   body.addChild(button('瘾头解 ×1',355,354,170,function(e:MouseEvent):void{runtime.dose('detoxin');refresh();}));
   info=text(body,'',18,397,510,38,13);
   cancelButton=button('正在伸向药物… 点击忍住',0,0,290,function(e:MouseEvent):void{runtime.cancelAuto();});root.addChild(cancelButton);
   status=text(root,'',0,0,550,52,15);status.mouseEnabled=false;
   refresh();
  }
  private function text(parent:Sprite,value:String,x:Number,y:Number,w:Number,h:Number,size:int=15):TextField{
   var t:TextField=new TextField();t.defaultTextFormat=new TextFormat('Microsoft YaHei',size,0xc3f4de);t.text=value;t.x=x;t.y=y;t.width=w;t.height=h;t.wordWrap=true;t.selectable=false;parent.addChild(t);return t;
  }
  public function button(label:String,x:Number,y:Number,w:Number,fn:Function):Sprite {
   var b:Sprite=new Sprite();b.x=x;b.y=y;b.graphics.beginFill(0x234d42);b.graphics.lineStyle(1,0x4eab8b);b.graphics.drawRoundRect(0,0,w,30,6);b.graphics.endFill();
   text(b,label,6,3,w-10,27,14).mouseEnabled=false;b.buttonMode=true;b.mouseChildren=false;
   b.addEventListener(MouseEvent.MOUSE_DOWN,function(e:MouseEvent):void{e.stopImmediatePropagation();});
   b.addEventListener(MouseEvent.CLICK,function(e:MouseEvent):void{e.stopImmediatePropagation();fn(e);});return b;
  }
  public function refresh():void {
   body.visible=expanded;while(rows.numChildren)rows.removeChildAt(0);
   if(!runtime.engine)return;
   treatment=runtime.doctor();var y:int=-24;
   if(treatment){
    text(rows,'临床治疗（新增）：6 分钟一疗程；开单即收费。',18,0,510,26,14);y=30;
    for each(var cat:String in Catalog.families)addClinic(cat,y+=32);
   }else{
    for each(var id:String in Catalog.ids)addDrug(id,y+=30);
   }
   if(!treatment)text(rows,'本批 '+quantity+' 颗',70,262,85,30,15);
   for each(var b:DisplayObject in doseButtons)b.visible=!treatment;
   var active:Object=runtime.engine.s.families[Catalog.drugs[selected].category].active;
   info.text=runtime.engine.s.clinic?'疗程剩余 '+Math.ceil((runtime.engine.s.clinic.end-runtime.engine.s.t)*60)+' 秒有效游戏时间；同类服药会中断且不退款。':active?'当前药效：'+Catalog.drugs[active.drug].name+'，剩余 '+Math.ceil((active.end-runtime.engine.s.t)*60)+' 秒。':'反复服药会降低药效；停药后缓慢恢复。医生可提供收费疗程。';
  }
  private function addDrug(id:String,y:int):void {
   var selectedNow:Boolean=id==selected;
   rows.addChild(button((selectedNow?'● ':'')+Catalog.drugs[id].name+'  背包 '+runtime.stock(id),18,y,505,function(e:MouseEvent):void{selected=id;refresh();}));
  }
  private function addClinic(id:String,y:int):void {
   rows.addChild(button(Catalog.categories[id].name+'  治疗 '+runtime.engine.cost(id)+' 瓶盖',18,y,505,function(e:MouseEvent):void{runtime.treat(id);refresh();}));
  }
  public function update():void {
   var r:Runtime=runtime,w:Object=r.world,stage:Stage=r.main.stage;
   root.visible=true;edge.visible=true;
   var available:Boolean=w.pip && w.pip.active && !w.pip.noAct && (r.bridge['page'](w.pip)==2 || r.doctor());
   openButton.visible=available;body.visible=available&&expanded;
   if(!available)expanded=false;
   var scale:Number=Math.min(1,stage.stageWidth/900,stage.stageHeight/650);root.scaleX=root.scaleY=scale;root.x=stage.stageWidth-565*scale;root.y=18;
   cancelButton.y=(stage.stageHeight-100)/scale;cancelButton.visible=!!r.engine.s.pending && w.allStat==1;
   status.y=(stage.stageHeight-62)/scale;status.visible=messageLeft>0;
   if(messageLeft>0)messageLeft--;
   if(available&&expanded&&treatment!=r.doctor())refresh();
   var severity:Number=0;for each(var id:String in Catalog.families)if(r.engine.stage(id)>=3)severity=Math.max(severity,r.engine.w(id));
   edge.graphics.clear();if(severity>.12 && w.allStat==1 && !w.alicorn){edge.graphics.lineStyle(10,0x99775d,severity*(.07+.04*Math.sin(r.engine.s.t*60)));edge.graphics.drawRect(3,3,stage.stageWidth-6,stage.stageHeight-6);}
  }
  private function onKey(e:KeyboardEvent):void {if(runtime.engine && runtime.engine.s.pending)runtime.cancelAuto();}
  public function message(s:String):void {status.text=s;messageLeft=150;}
  public function hide():void {root.visible=false;edge.visible=false;}
  public function dispose():void {runtime.main.stage.removeEventListener(KeyboardEvent.KEY_DOWN,onKey);if(root.parent)root.parent.removeChild(root);if(edge.parent)edge.parent.removeChild(edge);}
 }
}
