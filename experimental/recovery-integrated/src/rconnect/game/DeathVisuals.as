package rconnect.game {
   import flash.utils.getQualifiedClassName;
   /** Native single-blast death recipes. Playback only emits particles/sound;
    * Unit.die/dropLoot/Bullet.explosion also damage terrain and grant rewards. */
   public class DeathVisuals {
      public static function capture(u:Object):Object {
         var name:String=getQualifiedClassName(u),type:int;
         if(name=="fe.unit::UnitMsp" || name=="fe.unit::Mine")type=int(u.tipDamage);
         else if(name=="fe.unit::UnitRoller" && int(u.tr)==2)type=6;
         else return null;
         // Unit.explosion constructs a non-running Bullet and explodes it at once.
         // Its inWater stays -1; only Bullet.run samples water for flying bullets.
         return {armed:u.lootIsDrop!=true,type:type,water:false};
      }
      public static function play(main:Object,loc:Object,s:Object,x:Number,y:Number):void {
         if(s==null || loc==null)return;
         var emitter:Object=main.loaderInfo.applicationDomain.getDefinition("fe.graph.Emitter");
         var sound:Object=main.loaderInfo.applicationDomain.getDefinition("fe.Snd");
         var names:Array=[],snd:String="";
         switch(int(s.type)) {
            case 4:
               if(s.water){names=["explw","bubble"];snd="expl_uw";}
               else{names=["expl","flare","iskr"];snd="expl_e";}
               break;
            case 3:if(!s.water){names=["fireexpl","flare","iskr"];snd="fire_e";}break;
            case 6:names=["plaexpl"];snd="exppla_e";break;
            case 7:names=["gas"];snd="gas_e";break;
            case 8:names=["impexpl"];snd="emp_e";break;
            case 10:names=["acidexpl","acidkap"];snd="acid_e";break;
            case 11:names=["iceexpl","snow"];snd="cryo_e";break;
            case 15:names=["balefire","baleblast"];snd="bale_e";break;
            case 19:names=["pinkgas"];snd="gas_e";break;
         }
         for each(var name:String in names) {
            var options:Object=null;
            if(name=="iskr" || name=="snow")options={kol:16};
            else if(name=="acidkap")options={kol:Math.floor(Math.random()*5+30)};
            else if(name=="bubble")options={kol:30,rx:100,ry:100,rdx:10,rdy:10};
            emitter.emit(name,loc,x,y+(name=="balefire"?-60:0),options);
         }
         if(snd!="")sound.ps(snd,x,y);
      }
   }
}
