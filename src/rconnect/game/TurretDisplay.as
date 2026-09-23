package rconnect.game
{
   import flash.display.MovieClip;
   import flash.utils.getQualifiedClassName;

   /** Turret.animate also decides whether to retract, using internal local AI.
    * Mirrors instead animate the native clips from the authority's display state. */
   public class TurretDisplay
   {
      public static function capture(u:Object):Object
      {
         if(getQualifiedClassName(u).indexOf("::UnitTurret")<0)return null;
         try
         {
            var body:MovieClip=u.vis.osn as MovieClip;
            var mount:int=int(getQualifiedClassName(u.vis).replace(/^.*visualTurret/,""));
            return {kind:"turret",mount:mount,frame:body.currentFrame,
               light:GameBridge.probe(body,"light")!=null?int(body["light"].currentFrame):1,
               rock:body.rotation};
         }
         catch(error:*) {return null;}
         return null;
      }

      public static function constructorId(e:Object):String
      {
         var mount:int=e.body!=null?int(e.body.mount):int(String(e.id).replace(/^turret/,""));
         return ["","land","wall","arm","combat","boss"][Math.max(0,Math.min(5,mount))];
      }

      public static function receive(u:Object,s:Object):void
      {
         if(s==null || s.kind!="turret")return;
         var body:MovieClip=u.vis.osn as MovieClip;
         var frame:int=int(s.frame),local:int=body.currentFrame;
         // Retain native unfold/retract motion between network snapshots.
         if(frame==1 && local!=1 && local<=6)body.gotoAndPlay(7);
         else if(frame==6 && (local==1 || local>6))body.gotoAndPlay(2);
         else if(frame>1 && frame<6 && !(local>1 && local<6))body.gotoAndPlay(frame);
         else if(frame>6 && local<=6)body.gotoAndPlay(frame);
         present(u,s);
      }

      public static function present(u:Object,s:Object):void
      {
         if(s==null || s.kind!="turret")return;
         var body:Object=u.vis.osn;
         body.rotation=Number(s.rock);
         if(body.currentFrame!=1)return;
         body.puha.gotoAndStop(int(u.tr));
         body.puha.rotation=Number(u.currentWeapon.rot)*180/Math.PI;
         if(GameBridge.probe(body,"light")!=null)body.light.gotoAndStop(int(s.light));
         if(int(s.mount)==3)
            body.t1.scaleX=body.t2.scaleX=body.t3.scaleX=u.storona;
      }

      public static function fire(u:Object):void
      {
         var body:Object=u.vis.osn;
         if(body.currentFrame==1)body.puha.puha.gotoAndPlay(2);
      }
   }
}
