// Build a candidate only. Never writes the live host or game-reference.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const dir=path.resolve(process.argv[2]||'');
const allowed=path.resolve(__dirname);
if(dir===allowed||!dir.startsWith(allowed+path.sep))throw Error('Output must be a new job below the independent PI recipe');
const source=path.join(dir,'host/scripts'),dest=path.join(dir,'candidate/scripts');
if(fs.existsSync(dest))throw Error('Use a new native preparation job');
let changes=[];
function edit(file,fn){const p=path.join(source,file),original=fs.readFileSync(p,'utf8').replace(/\r\n/g,'\n');if(original.includes('PI_HOOK_V1'))throw Error('Already patched: '+file);let text=original;function replace(a,b,n=1){const count=text.split(a).length-1;if(count!==n)throw Error(file+' anchor count '+count+' expected '+n+': '+a.slice(0,100));text=text.split(a).join(b);}fn(replace,()=>text,v=>text=v);text=text.replace('{','{\n   // PI_HOOK_V1: PermanentInjury optional exact-event bridge.');fs.mkdirSync(path.dirname(path.join(dest,file)),{recursive:true});fs.writeFileSync(path.join(dest,file),text);changes.push({file,before:crypto.createHash('sha256').update(original).digest('hex'),after:crypto.createHash('sha256').update(text).digest('hex')});}
edit('fe/unit/Pers.as',(r)=>{
 r('var loadObj:Object = param1;','var loadObj:Object = param1;\n         if(param1 && param1.hasOwnProperty("piPermanent")) this["piPermanent"] = param1.piPermanent;');
 r('         return _loc1_;\n      }\n      \n      public function setGlobalDif', '         var piSaved:* = this.piEvent("save");\n         if(piSaved != null) _loc1_.piPermanent = piSaved;\n         else if(this.hasOwnProperty("piPermanent")) _loc1_.piPermanent = this["piPermanent"];\n         return _loc1_;\n      }\n      \n      public function setGlobalDif');
 for(const [part,field,min]of [['head','headHP','headMin'],['torso','torsHP','torsMin'],['legs','legsHP','legsMin']])r(`            this.${field} -= param1;`,`            if(!param3) this.piEvent("part",{part:"${part}",D:param1,H:Math.max(0,this.${min},this.${field}-param1),M:this.inMaxHP});\n            this.${field} -= param1;`);
 r('            this.bloodHP -= param1;','            this.piEvent("part",{part:"blood",D:param1,H:Math.max(0,this.bloodMin,this.bloodHP-param1),M:this.inMaxHP});\n            this.bloodHP -= param1;');
 r('         this.manaHP -= param1;','         this.piEvent("part",{part:"mana",D:param1,H:Math.max(this.manaMin>0?1:0,this.manaHP-param1),M:this.inMaxMana});\n         this.manaHP -= param1;');
 r('         this.gg.setSpeeds();\n         if(this.gg.currentWeapon)','         this.piEvent("changed");\n         this.meleeSpdMult /= this.piFactor("meleeInterval");\n         this.gg.setSpeeds();\n         if(this.gg.currentWeapon)');
 r('      public function damage(param1:Number, param2:int, param3:Boolean = false) : *',`      public function piEvent(key:String,arg:* = null) : *
      {
         var result:* = null;
         try { var carrier:* = World.w.main.getChildByName("PermanentInjuryCarrier"); if(carrier != null) result = carrier["api"].dispatch(this,key,arg); } catch(piError:*) { }
         return result;
      }
      public function piFactor(key:String) : Number
      {
         var result:* = this.piEvent("factor",key);
         return result == null ? 1 : Number(result);
      }
      public function damage(param1:Number, param2:int, param3:Boolean = false) : *`);
});
edit('fe/unit/UnitPlayer.as',(r)=>{
 r('            this.pers.damage(_loc6_,param2);\n            this.pers.bloodDamage(_loc6_,param2);',`            this.pers.piEvent("begin",{dot:param2==Unit.D_BLEED || param2==Unit.D_POISON || param2==Unit.D_INSIDE,shot:param3==null?0:param3.piShot});
            try { this.pers.damage(_loc6_,param2); this.pers.bloodDamage(_loc6_,param2); }
            finally { this.pers.piEvent("end"); }`);
 r('runSpeed = this.pers.maxSpeed;\n         }','runSpeed = this.pers.maxSpeed;\n         }\n         runSpeed -= Math.max(0,runSpeed-walkSpeed)*(1-this.pers.piFactor("runBonus"));');
 r('         precMult = this.pers.allPrecMult;','         precMult = this.pers.allPrecMult * this.pers.piFactor("accuracy");');
 r('this.pers.healMult / 5 * this.pers.metaMult','this.pers.healMult / 5 * this.pers.metaMult * this.pers.piFactor("hpRate")',2);
 r('this.stam -= this.pers.stamRun * this.dstam;','this.stam -= this.pers.stamRun * this.dstam * this.pers.piFactor("runCost");');
 r('this.stam -= this.pers.stamRun * this.pers.stamDash * this.dstam;','this.stam -= this.pers.stamRun * this.pers.stamDash * this.dstam * this.pers.piFactor("dashCost");',2);
 r('this.stam -= this.pers.stamRun * this.pers.stamJump * this.dstam;','this.stam -= this.pers.stamRun * this.pers.stamJump * this.dstam * this.pers.piFactor("jumpCost");');
 r('this.stam += this.pers.stamRes;','this.stam += this.pers.stamRes * this.pers.piFactor("staminaRecovery");');
 r('            if(dmana < this.pers.recManaMin * this.pers.shtrManaRes)\n            {\n               dmana = this.pers.recManaMin * this.pers.shtrManaRes;\n            }\n            dmana += this.pers.recMana * this.pers.shtrManaRes;',`            var piRecovery:Number = this.pers.piFactor("mpRecovery");
            if(piRecovery <= 0) dmana=0;
            else {
               if(dmana < this.pers.recManaMin*this.pers.shtrManaRes*piRecovery) dmana=this.pers.recManaMin*this.pers.shtrManaRes*piRecovery;
               dmana += this.pers.recMana*this.pers.shtrManaRes*piRecovery;
            }`);
 r('         mana -= param1 * this.pers.allDManaMult;\n         this.pers.manaDamage(param2 * this.pers.allDManaMult);',`         mana -= param1 * this.pers.allDManaMult * this.pers.piFactor("mpCost");
         this.pers.piEvent("castBegin");
         try { this.pers.manaDamage(param2 * this.pers.allDManaMult); }
         finally { this.pers.piEvent("castEnd"); }`);
 // Match affordability checks to the charged cost for the native teleport paths.
 r('this.pers.portMana * this.pers.allDManaMult','this.pers.portMana * this.pers.allDManaMult * this.pers.piFactor("mpCost")',2);
});
edit('fe/unit/Unit.as',(r)=>{
 r('                  this.cut -= this.critHeal;','                  this.cut -= this.critHeal * (this == World.w.gg ? World.w.pers.piFactor("bleedDecay") : 1);');
});
edit('fe/unit/Invent.as',(r)=>{
 r('hhp = pot.@hhp * this.gg.pers.healMult;','hhp = pot.@hhp * this.gg.pers.healMult * this.gg.pers.piFactor("hpYield");');
 r('hhplong = pot.@hhplong * this.gg.pers.healMult;','hhplong = pot.@hhplong * this.gg.pers.healMult * this.gg.pers.piFactor("hpYield");');
 r('this.gg.pers.heal(pot.@hblood,5);','this.gg.pers.heal(pot.@hblood * this.gg.pers.piFactor("bloodYield"),5);');
 r('         this.minusItem(ci);\n         return true;','         this.minusItem(ci);\n         if(ci == "potHP") this.gg.pers.piEvent("potion");\n         return true;');
});
edit('fe/weapon/Weapon.as',(r)=>{
 r('this.t_reload = Math.round(this.reload * this.reloadMult);','this.t_reload = Math.round(this.reload * this.reloadMult * (this.owner == World.w.gg ? World.w.pers.piFactor("reloadTime") : 1));');
 r('         _loc3_ = 0;\n         while(_loc3_ < this.kol)','         var piShotId:Number = Number(World.w.pers.piEvent("shot"));\n         _loc3_ = 0;\n         while(_loc3_ < this.kol)');
 r('            this.b.weap = this;','            this.b.weap = this;\n            this.b.piShot = piShotId;');
});
edit('fe/weapon/Bullet.as',(r)=>{r('      public var weap:Weapon;','      public var weap:Weapon;\n      public var piShot:Number = 0;');});
edit('fe/unit/Spell.as',(r)=>{r('this.dmagic = this.magic * World.w.pers.allDManaMult;','this.dmagic = this.magic * World.w.pers.allDManaMult * World.w.pers.piFactor("mpCost");');});
edit('fe/weapon/WMagic.as',(r)=>{
 r('dmagic = magic * param2.allDManaMult * param2.warlockDManaMult;','dmagic = magic * param2.allDManaMult * param2.warlockDManaMult * param2.piFactor("mpCost");');
 r('               World.w.pers.manaDamage(dmana);','               World.w.pers.piEvent("castBegin");\n               try { World.w.pers.manaDamage(dmana); } finally { World.w.pers.piEvent("castEnd"); }');
});
edit('fe/World.as',(r)=>{
 r('                  this.land.step();','                  if(this.pers != null && Land.rconnectRoomStep == null) this.pers.piEvent("tick",1/fps);\n                  this.land.step();\n                  if(this.pers != null && Land.rconnectRoomStep == null) this.pers.piEvent("flush");');
});
edit('fe/inter/PipPageMed.as',(r)=>{
 r('         this.showBottext();\n      }\n      \n      override internal function setStatItem',`         if(page2 == 1) {
            var piRows:* = this.pers.piEvent("doctorRows",{currency:this.plata});
            if(piRows != null) for each(var piRow:Object in piRows) arr.push(piRow);
         }
         this.showBottext();
      }

      override internal function setStatItem`);
 r('         this.infoItemId = param1.currentTarget.id.text;','         this.infoItemId = param1.currentTarget.id.text;\n         if(this.infoItemId.indexOf("pi:") == 0) {\n            var piResult:* = this.pers.piEvent("doctor",{id:this.infoItemId,currency:this.plata});\n            if(piResult != null) { if(piResult.ok && this.plata.id=="money" && pip.vendor) pip.vendor.money+=piResult.cost; setStatus(); this.showBottext(); pip.setRPanel(); vis.info.text=piResult.message; }\n            return;\n         }');
 r('            vis.nazv.text = Res.pipText(param1.currentTarget.id.text);','            if(String(param1.currentTarget.id.text).indexOf("pi:")==0) { vis.nazv.text="永久伤残医疗"; vis.info.text=this.pers.piEvent("describe",String(param1.currentTarget.id.text)); return; }\n            vis.nazv.text = Res.pipText(param1.currentTarget.id.text);');
});
// The donor compiler confuses a local "id" with XML @id. Rename only the
// edited setParameters method's local, preserving XML attributes and strings.
const persFile=path.join(dest,'fe/unit/Pers.as');
let ps=fs.readFileSync(persFile,'utf8'),start=ps.indexOf('public function setParameters()'),end=ps.indexOf('\n      public function ',start+1);
if(start<0||end<0)throw Error('setParameters extent');
ps=ps.slice(0,start)+ps.slice(start,end).replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:id)\b/g,(t,o,s)=>t==='id'&&!/[.@]/.test(s.slice(0,o).trimEnd().slice(-1))?'piXmlKey':t)+ps.slice(end);
fs.writeFileSync(persFile,ps);
// Only methods containing the bridge are transplanted; all other bytecode stays original.
const methods=[];
for(const change of changes){const s=fs.readFileSync(path.join(dest,change.file),'utf8'),cls=change.file.replace(/\.as$/,'').replaceAll('/','.');const re=/\bfunction\s+(\w+)\s*\(/g;const positions=[...s.matchAll(re)];for(let i=0;i<positions.length;i++){const pos=positions[i],chunk=s.slice(pos.index,i+1<positions.length?positions[i+1].index:s.length);if(/piEvent|piFactor|piPermanent|piShot/.test(chunk))methods.push(cls+'\t'+(pos[1]===cls.split('.').pop()?'$init':pos[1]));}}
fs.writeFileSync(path.join(dir,'methods.tsv'),methods.join('\n')+'\n');
fs.writeFileSync(path.join(dir,'patch-plan.json'),JSON.stringify({version:1,scope:'candidate only; live deployment separate',changes,methods},null,2));
console.log('Prepared '+changes.length+' exact-source scripts');
