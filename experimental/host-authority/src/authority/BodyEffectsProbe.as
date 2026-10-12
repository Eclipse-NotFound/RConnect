package authority {
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.MovieClip;
   import flash.filters.BlurFilter;
   import flash.filters.GlowFilter;
   import flash.filters.DropShadowFilter;
   import flash.geom.Matrix;
   import flash.geom.Rectangle;
   import flash.utils.getQualifiedClassName;
   /** Native inventory/Spell/Effect -> actor simulation -> independent display
    * observation. The other pony is an unchanged control in every phase. */
   public final class BodyEffectsProbe extends Probe {
      private static const CASES:Array=["plain","stealth","shield","combo","shadow","blood","frozen","inhibitor","rat","fetter","crystal","dash"];
      private static const EFFECTS:Array=["stealth","stealth_armor","potion_shadow","bloodinv","freezing","inhibitor","potion_rat","fetter"];
      private static const PATHS:Array=["osn","shit","inh","cryst","fetter","rat","svet","osn.body.head.morda.magic"];
      private var phase:int=-1,begin:int=-1,peerReady:int=-1,sent:int=-1,ending:int=-1,owner:int=0;
      private var ready:Boolean=false,waiting:Boolean=false,report:Object,refs:Object={},counts:Object;
      private var activeSamples:int=0,clearSamples:int=0,controlWrong:int=0,cleared:Boolean=false;
      private var fixtureGuns:Array=[];
      public function BodyEffectsProbe(a:NativeAccess,h:Boolean){super(a,h);}
      private function kind():String{return phase<0?"plain":CASES[int(phase/2)];}
      override public function message(v:Object):void {
         if(host && v.type=="body-ready")peerReady=v.phase;
         if(host && v.type=="body-report")report=v;
         if(!host && v.type=="body-phase") {
            phase=v.phase;owner=phase%2;begin=ending=-1;refs={};counts={samples:0,wrong:0,first:null};
         }
         if(!host && v.type=="body-go")begin=v.tick;
         if(!host && v.type=="body-reference")refs[v.tick]=v;
         if(!host && v.type=="body-end")ending=v.tick;
         if(!host && v.type=="body-finish")finish();
      }
      override public function input(f:Object,s:HostSession):Object {
         f.buttons=0;f.actions=[];f.aimX=900;f.aimY=access.world.gg.Y-40;
         if(kind()=="dash" && begin>=0 && (host?0:1)==owner) {
            var elapsed:int=(host?s.runtime.tick:RConnectMod.instance.replica.lastTick)-begin;
            if(elapsed>=8 && elapsed<12)f.buttons=Commands.DASH;
         }
         return f;
      }
      private function clear(actor:PlayerActor):void {
         access.scope.run(actor.context,function():void {
            var g:Object=actor.unit;for each(var effect:String in EFFECTS)g.remEffect(effect);
            g.shithp=0;g.t_cryst=0;g.dash_t=0;g.levit=0;
            // Native inhibitor/rat unequip weapons. Restore the fixture weapon
            // between cases, leaving native removal/animation to the next step.
            g.currentWeapon=fixtureGuns[actor.id];g.childObjs=[g.currentWeapon,g.punchWeapon];g.currentWeapon.addVisual();
         });
      }
      private function start(s:HostSession,index:int):void {
         phase=index;owner=phase%2;begin=peerReady=-1;report=null;waiting=cleared=false;
         activeSamples=clearSamples=controlWrong=0;
         var fy:Number=ProbeArena.floor(s.actors[0].unit.loc);
         for each(var a:PlayerActor in s.actors) {
            if(fixtureGuns[a.id]==null)fixtureGuns[a.id]=a.unit.currentWeapon;
            clear(a);
            access.scope.run(a.context,function():void {
               var g:Object=a.unit;g.setLocPos(360+a.id*220,fy);g.dx=g.dy=0;g.anim();g.invulner=true;
               g.mana=g.maxmana=10000;g.pers.manaHP=10000;g.pers.spellsPoss=1;g.pers.speedShtr=0;g.stam=10000;
               g.invent.items.stealth.kol=20;g.loc.base=false;
            });
         }
         s.link.send({type:"body-phase",phase:phase});
      }
      private function activate(a:PlayerActor):void {
         access.scope.run(a.context,function():void {
            var g:Object=a.unit,k:String=kind(),Spell:Class=access.definition("fe.unit.Spell"),spell:Object;
            if(k=="stealth" || k=="combo")check(g.invent.useItem("stealth"),"native stealth item consumes once for owner "+owner);
            if(k=="shield" || k=="combo" || k=="crystal") {
               spell=new Spell(g,k=="crystal"?"sp_cryst":"sp_mshit");check(spell.cast(g.X,g.Y),"native spell casts "+k+" for owner "+owner);
            }
            var effect:Object={shadow:"potion_shadow",blood:"bloodinv",frozen:"freezing",inhibitor:"inhibitor",rat:"potion_rat",fetter:"fetter"};
            if(effect[k]!=null)g.addEffect(effect[k],0,30,false);
            if(k=="fetter"){g.fetX=g.X-60;g.fetY=g.Y;}
         });
      }
      private function node(root:Object,path:String):DisplayObject {
         var v:Object=root;for each(var key:String in path.split(".")){if(v==null || !(key in v))return null;v=v[key];}return v as DisplayObject;
      }
      private function color(v:DisplayObject):Array {
         var c:Object=v.transform.colorTransform;return [c.redMultiplier,c.greenMultiplier,c.blueMultiplier,c.alphaMultiplier,c.redOffset,c.greenOffset,c.blueOffset,c.alphaOffset];
      }
      private function filters(v:DisplayObject):Array {
         var out:Array=[];for each(var f:Object in v.filters) {
            if(f is BlurFilter)out.push(["blur",f.blurX,f.blurY,f.quality]);
            else if(f is GlowFilter)out.push(["glow",f.color,f.alpha,f.blurX,f.blurY,f.strength,f.inner,f.knockout]);
            else if(f is DropShadowFilter)out.push(["shadow",f.color,f.alpha,f.blurX,f.blurY,f.distance,f.angle,f.hideObject]);
            else out.push([getQualifiedClassName(f)]);
         }return out;
      }
      private function pixels(v:DisplayObject):uint {
         var bounds:Rectangle=v.getBounds(v);
         if(bounds.width<=0 || bounds.height<=0)return 0;
         var left:int=Math.floor(bounds.x),top:int=Math.floor(bounds.y),w:int=Math.min(160,Math.ceil(bounds.right)-left),h:int=Math.min(160,Math.ceil(bounds.bottom)-top);
         var b:BitmapData=new BitmapData(w,h,true,0);b.draw(v,new Matrix(1,0,0,1,-left,-top));
         var hash:uint=2166136261;for each(var p:uint in b.getVector(b.rect)){hash^=p;hash*=16777619;}b.dispose();return hash;
      }
      private function read(g:Object):Object {
         if(g==null)return null;
         var root:DisplayObject=g.vis,out:Object={alpha:root.alpha,color:color(root),filters:filters(root),parts:{}};
         for each(var path:String in PATHS) {
            var v:DisplayObject=node(root,path);if(v==null){out.parts[path]=null;continue;}
            var m:Matrix=v.transform.matrix;
            out.parts[path]={visible:v.visible,alpha:v.alpha,color:color(v),filters:filters(v),matrix:[m.a,m.b,m.c,m.d,m.tx,m.ty],
               frame:v is MovieClip?MovieClip(v).currentFrame:0,pixels:v.visible?pixels(v):0};
         }return out;
      }
      private function has(list:Array,name:String):Boolean {for each(var f:Array in list)if(f[0]==name)return true;return false;}
      private function contract(v:Object,k:String):Boolean {
         var p:Object=v.parts,b:Object=p.osn;
         for each(var required:String in ["osn","shit","inh","cryst","fetter","rat"])if(p[required]==null)return false;
         if(k=="stealth")return v.alpha<.6 && has(b.filters,"blur");
         if(k=="combo")return v.alpha<.6 && has(b.filters,"blur") && p.shit.visible;
         if(k=="shield")return p.shit.visible;
         if(k=="shadow")return has(b.filters,"shadow");
         if(k=="blood")return has(b.filters,"glow");
         if(k=="frozen")return v.color[4]>0 && v.color[6]>0;
         if(k=="inhibitor")return p.inh.visible;
         if(k=="rat")return !b.visible && p.rat.visible;
         if(k=="fetter")return p.fetter.visible && Math.abs(p.fetter.matrix[0])>.1;
         if(k=="crystal")return p.cryst.visible;
         if(k=="dash")return has(b.filters,"blur");
         return v.alpha>.99 && b.visible && !p.rat.visible && !p.shit.visible && !p.inh.visible && !p.cryst.visible && !p.fetter.visible &&
            !has(b.filters,"glow") && !has(b.filters,"shadow") && v.color[4]==0 && v.color[6]==0;
      }
      private function same(a:*,b:*):Boolean {
         if(a===b)return true;if(a==null || b==null)return false;
         if(a is Number && b is Number)return Math.abs(a-b)<.005;
         if(a is String || b is String || a is Boolean || b is Boolean)return false;
         if((a is Array)!=(b is Array) || a is Array && a.length!=b.length)return false;
         for(var k:String in a)if(!(k in b) || !same(a[k],b[k]))return false;
         for(k in b)if(!(k in a))return false;return true;
      }
      private function source(s:HostSession):void {
         if(begin<0 || waiting)return;
         var states:Array=[];for each(var a:PlayerActor in s.actors)states.push(read(a.unit));
         if(!cleared && contract(states[owner],kind()))++activeSamples;
         if(cleared && contract(states[owner],"plain"))++clearSamples;
         if(!contract(states[1-owner],"plain"))++controlWrong;
         s.link.send({type:"body-reference",phase:phase,tick:s.runtime.tick,states:states});
      }
      private function applied(f:Object):void {
         var ref:Object=refs[f.tick];if(ref==null || ref.phase!=phase)return;delete refs[f.tick];
         for(var i:int=0;i<2;i++) {
            ++counts.samples;var actual:Object=read(displayedPlayer(i));
            if(!same(actual,ref.states[i])) {
               ++counts.wrong;if(counts.first==null)counts.first={player:i,tick:f.tick,native:ref.states[i],replica:actual};
            }
         }
      }
      override public function observe(s:HostSession,r:ClientReplica):void {
         if(finished)return;
         if(!host) {
            if(r==null || r.displayFrame==null)return;if(!ready){ready=true;r.confirmed=applied;}
            if(phase>=0 && sent!=phase){sent=phase;RConnectMod.instance.link.send({type:"body-ready",phase:phase});}
            if(ending>=0 && r.displayFrame.tick>=ending) {
               check(counts.samples>140 && counts.wrong==0,"native body tint, opacity, filters, frames and pixels match "+kind()+" owner "+owner,counts);
               RConnectMod.instance.link.send({type:"body-report",phase:phase});ending=-1;
            }return;
         }
         if(s==null || !s.active)return;
         if(!ready){ready=true;var publish:Function=s.runtime.afterStep;s.runtime.afterStep=function():void{source(s);publish();};start(s,0);return;}
         if(begin<0 && peerReady==phase){begin=s.runtime.tick;activate(s.actors[owner]);s.link.send({type:"body-go",tick:begin});}
         if(begin<0)return;
         var elapsed:int=s.runtime.tick-begin;
         if(elapsed>=50 && !cleared){cleared=true;clear(s.actors[owner]);}
         if(elapsed>=90 && !waiting) {
            waiting=true;check(activeSamples>0,"native status actually becomes visible "+kind()+" owner "+owner,{samples:activeSamples});
            check(clearSamples>15,"native status clears without leaving ghost effects "+kind(),{samples:clearSamples});
            check(controlWrong==0,"the other player's ordinary body is not overwritten by this status "+kind(),{wrong:controlWrong});
            s.link.send({type:"body-end",tick:s.runtime.tick});
         }
         if(waiting && report!=null && report.phase==phase) {
            if(phase+1<CASES.length*2)start(s,phase+1);else {s.link.send({type:"body-finish"});finish();}
         }
      }
   }
}
