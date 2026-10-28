package addiction {
 /** Host-independent state machine. All timestamps are active gameplay minutes. */
 public class Engine {
  public var s:Object;
  public var events:Array=[];
  public var p:Object=Catalog.params;
  public function Engine(saved:String=null,nativeA:Object=null) {
   if(saved!=null){s=JSON.parse(saved);validate();return;}
   s={v:1,t:0,seed:uint(1+Math.random()*4294967294),families:{},clinic:null,pending:null,lastAuto:-1000,lastDetox:-1000,detoxUntil:0};
   for each(var id:String in Catalog.families){var a:Number=nativeA&&nativeA[id]?Math.min(750,Math.max(0,Number(nativeA[id]))):0;
    s.families[id]={A:a,N:0,W:0,dependent:a>=p.T_1,recovered:null,until:0,active:null,post:0};}
  }
  private function finite(x:*):Boolean{return x is Number && isFinite(Number(x));}
  private function check(ok:Boolean,msg:String):void{if(!ok)throw new Error('Invalid addiction state: '+msg);}
  private function validate():void {
   check(s && s.v===1 && s.families,'schema');
   for each(var n:String in ['t','seed','lastAuto','lastDetox','detoxUntil'])check(finite(s[n]),n);
   check(s.t>=0 && s.seed>=1 && s.seed<=4294967295,'clock/seed');
   for each(var id:String in Catalog.families){var f:Object=s.families[id];check(f!=null,id);
    for each(n in ['A','N','W','until'])check(finite(f[n]),id+'.'+n);
    check(f.A>=0 && f.A<=p.cap && f.N>=0 && f.W>=0 && f.W<=1 && f.dependent is Boolean,'family range');
    check(f.recovered===null || (finite(f.recovered)&&f.recovered<=s.t),'recovery');
    check(finite(f.post)&&f.post>=0,'post');
    if(f.active)check(Catalog.drugs[f.active.drug] && Catalog.drugs[f.active.drug].category==id && finite(f.active.end)&&finite(f.active.strength)&&f.active.strength>=0&&f.active.strength<=1 && (f.active.level==1||f.active.level==2),'active');
   }
   if(s.clinic)check(s.families[s.clinic.category] && finite(s.clinic.end)&&finite(s.clinic.cost)&&s.clinic.cost>=0,'clinic');
   if(s.pending)check(s.families[s.pending.category] && finite(s.pending.end),'pending');
  }
  public function json():String{return JSON.stringify(s);}
  public function random():Number {var x:uint=uint(s.seed);x^=x<<13;x^=x>>>17;x^=x<<5;s.seed=x;return x/4294967296;}
  public function single(id:String):Number {var n:Number=s.families[id].N;return 1/(1+Math.log(1+Math.pow(n/p.N_50,p.nu))/Math.LN2);}
  public function relapse(id:String):Number {var f:Object=s.families[id];var r:Number=f.recovered===null?0:Math.max(0,1-(s.t-f.recovered)/p.window);return 1+p.rho*Math.pow(r,p.eta);}
  public function stage(id:String):int {var f:Object=s.families[id];return !f.dependent?0:f.A>=p.T_3?3:f.A>=p.T_2?2:1;}
  public function w(id:String):Number {var k:Number=s.t<s.detoxUntil?p.detox_relief:1;if(s.clinic && s.clinic.category==id)k=Math.min(k,p.clinic_relief);return s.families[id].W*k;}
  public function cost(id:String):int{return Math.ceil(p.clinic_fee*Math.sqrt(1+s.families[id].A/p.T_1));}
  private function recover(id:String):void {var f:Object=s.families[id];if(f.dependent && f.A<=p.exit+1e-8){f.dependent=false;f.recovered=s.t;events.push('recovered:'+id);}}
  public function boundaries():void {
   if(s.clinic && s.clinic.end<=s.t+1e-9){var id:String=s.clinic.category;s.families[id].A=Math.max(0,s.families[id].A-p.clinic_heal);s.clinic=null;recover(id);events.push('clinic-complete');}
   for each(id in Catalog.families){var f:Object=s.families[id];recover(id);
    if(f.active && f.active.end<=s.t+1e-9){f.active=null;f.post=f.dependent?0:s.t+Catalog.categories[id].postMinutes;}
    if(f.post<=s.t+1e-9)f.post=0;
   }
  }
  public function dose(drug:String,count:int,skill:Number=1,difficulty:Number=1,time:Number=1,level:int=1):void {
   boundaries();var d:Object=Catalog.drugs[drug],id:String=d.category,f:Object=s.families[id];
   if(count<=0 || !isFinite(skill)||!isFinite(difficulty)||!isFinite(time)||skill<0||difficulty<0||time<=0)throw new Error('Invalid dose');
   if(s.clinic && s.clinic.category==id){s.clinic=null;events.push('clinic-interrupted');}
   if(s.pending && s.pending.category==id)s.pending=null;
   var strength:Number=Math.min(1,count*single(id)),r:Number=relapse(id);
   for(var j:int=0;j<count;j++)f.A=Math.min(p.cap,f.A+int(Math.round(d.lo+(d.hi-d.lo)*random())*skill*difficulty)*r);
   for each(var other:String in Catalog.cancel[drug]){var of:Object=s.families[Catalog.drugs[other].category];if(of.active && of.active.drug==other)of.active=null;}
   f.post=0;f.active={drug:drug,end:s.t+d.duration*time,strength:strength,level:level>=2?2:1};f.until=f.active.end;f.N+=count;
   if(f.A>=p.T_1)f.dependent=true;
  }
  public function beginClinic(id:String):Boolean {
   boundaries();if(s.clinic || !s.families[id] || s.families[id].A<=0)return false;
   s.clinic={category:id,end:s.t+p.clinic_time,cost:cost(id)};s.families[id].active=null;s.families[id].post=0;s.pending=null;return true;
  }
  public function detox():Boolean {
   boundaries();if(s.t<s.lastDetox+p.detox_gap-1e-9)return false;
   var order:Array=Catalog.families.concat();order.sort(function(a:String,b:String):Number{return s.families[b].A-s.families[a].A;});
   var remain:Number=p.detox_heal;
   for each(var id:String in order){var f:Object=s.families[id],red:Number=Math.min(remain,f.A);f.A-=red;remain-=red;recover(id);if(remain<=0)break;}
   s.lastDetox=s.t;s.detoxUntil=s.t+p.detox_time;return true;
  }
  public function advance(dt:Number):void {
   if(dt<0 || !isFinite(dt))throw new Error('Invalid dt');
   var end:Number=s.t+dt;
   while(s.t<end-1e-11){boundaries();var next:Number=Math.min(end,s.t+1/1800);
    if(s.clinic && s.clinic.end>s.t)next=Math.min(next,s.clinic.end);
    for each(var id:String in Catalog.families){var f:Object=s.families[id];if(f.active && f.active.end>s.t)next=Math.min(next,f.active.end);if(f.until>s.t)next=Math.min(next,f.until);
     if(f.dependent && f.A>p.exit && s.t>=f.until)next=Math.min(next,s.t+p.A_half*Math.log(f.A/p.exit)/Math.LN2);}
    var delta:Number=next-s.t;if(delta<=1e-11){s.t=next;boundaries();continue;}
    for each(id in Catalog.families){f=s.families[id];var old:Number=f.A,rest:Number=Math.max(0,next-Math.max(s.t,f.until));
     f.A*=Math.pow(2,-rest/p.A_half);f.N*=Math.pow(2,-rest/p.N_half);
     var target:Number=f.dependent?Math.pow(Math.max(0,Math.min(1,((old+f.A)/2-p.exit)/(p.T_3-p.exit))),p.sev_exp)*(1-(f.active?f.active.strength:0)):0;
     var tau:Number=target>f.W?p.tau_on:p.tau_relief;f.W=target+(f.W-target)*Math.exp(-delta/tau);
    }s.t=next;
   }boundaries();
  }
  public function eligible(id:String,stock:Object):Boolean {
   var f:Object=s.families[id];return !s.clinic&&!f.active&&stage(id)>=2&&w(id)>=p.auto_W&&autoDrug(id,stock)!=null;
  }
  public function autoDrug(id:String,stock:Object):String {
   var chosen:String=null;
   for each(var drug:String in Catalog.ids)if(Catalog.drugs[drug].category==id && stock[drug]>0 && (chosen==null || Catalog.drugs[drug].price<Catalog.drugs[chosen].price))chosen=drug;
   return chosen;
  }
  /** Returns a real one-pill action. The host must supply actual inventory and cancellation input. */
  public function automatic(stock:Object):String {
   boundaries();if(s.pending && !eligible(s.pending.category,stock))s.pending=null;
   if(s.pending && s.pending.end<=s.t+1e-9){var ready:String=autoDrug(s.pending.category,stock);s.pending=null;return ready;}
   if(s.clinic || s.pending || s.t<s.lastAuto+p.auto_gap)return null;
   var id:String,chosen:String=null;
   for each(id in Catalog.families)if(eligible(id,stock) && (chosen==null||w(id)>w(chosen)))chosen=id;
   if(chosen==null)return null;s.lastAuto=s.t;
   if(stage(chosen)>=3)return autoDrug(chosen,stock);
   s.pending={category:chosen,end:s.t+p.auto_delay};return null;
  }
  public function cancelAuto():Boolean {if(!s.pending)return false;s.pending=null;return true;}
  private function apply(target:Object,eff:Object,k:Number,positive:Boolean):void {
   for(var key:String in eff){var b:Number=Catalog.mult[key]?1:0,v:Number=b+(eff[key]-b)*k;
    if(positive && Catalog.abilities[key])v=k>=p.ability_gate?eff[key]:0;
    if(positive && (key=='lockPick'||key=='hacker'))v=Math.round(v);
    target[key]=b?(target[key]===undefined?1:target[key])*v:(target[key]===undefined?0:target[key])+v;
   }
  }
  public function metrics():Object {
   var pos:Object={},neg:Object={},maxW:Number=0,id:String;
   for each(id in Catalog.families){var f:Object=s.families[id];if(f.active)apply(pos,Catalog.drugs[f.active.drug].effects[f.active.level-1],f.active.strength,true);
    var ew:Number=w(id);maxW=Math.max(maxW,ew);if(ew>1e-9)apply(neg,Catalog.categories[id].post[2],ew,false);
    if(f.post>s.t)apply(neg,Catalog.categories[id].post[0],1,false);
   }
   neg.allDamMult=(neg.allDamMult===undefined?1:neg.allDamMult)*(1-p.weak*maxW);
   var low:Object={allSpeedMult:.75,runSpeedMult:.75,allDamMult:.6,maxhp:.8,maxOd:-30,lockPick:-3,hacker:-3},high:Object={allVulnerMult:1.3,stamRun:2.5};
   for(id in low)if(neg[id]!==undefined)neg[id]=Math.max(low[id],neg[id]);
   for(id in high)if(neg[id]!==undefined)neg[id]=Math.min(high[id],neg[id]);
   var result:Object={};for(id in pos)result[id]=pos[id];
   for(id in neg)result[id]=Catalog.mult[id]?(result[id]===undefined?1:result[id])*neg[id]:(result[id]===undefined?0:result[id])+neg[id];
   for each(id in ['lockPick','hacker','maxOd'])if(result[id]!==undefined)result[id]=Math.round(result[id]);
   return result;
  }
 }
}
