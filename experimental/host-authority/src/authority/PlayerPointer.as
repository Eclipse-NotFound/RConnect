package authority {
   import flash.utils.Dictionary;
   /** Cursor selection belongs to one actor, even when both share a room. */
   public final class PlayerPointer {
      public static function run(actor:PlayerActor,input:Object,operation:Function):void {
         var room:Object=actor.unit.loc,old:Object=room.celObj,dist:Number=room.celDist;
         var marks:Dictionary=new Dictionary(true),reserved:Dictionary=new Dictionary(true),chosen:Object=null,object:Object=room.firstObj,count:int=0;
         var candidates:Array=room.units.concat();
         while(object!=null && ++count<=10000) {if(candidates.indexOf(object)<0)candidates.push(object);object=object.nobj;}
         if(count>10000)throw new Error("Cursor object chain exceeds bound");
         try {
            for each(object in candidates)if(object!=null && object!==actor.unit && "onCursor" in object) {
               marks[object]=object.onCursor;
               var eligible:Boolean=!NativeAccess.get(object,"disabled",false) && int(NativeAccess.get(object,"sost",1))<4;
               // Native single-player actTele has no competing caster. Guard both
               // direct hover and its nearby-object fallback for this invocation.
               // Restore eligibility before the owner's next native actions step.
               if(actor.grips!=null && actor.grips.heldByOther(actor,object)) {
                  eligible=false;
                  reserved[object]=object.levitPoss;object.levitPoss=false;
               }
               if(NativeAccess.get(object,"player",false)) {
                  var peer:PlayerActor=actor.grips==null?null:actor.grips.actorFor(object);
                  eligible=eligible && peer!=null && peer.personal.allowGrab;
               }
               if(NativeAccess.get(object,"isVis",true)===false || NativeAccess.get(object,"invis",false)===true)eligible=false;
               // Loot calculates its hover box from X/Y each step; its inherited
               // cached X1/Y1 bounds remain NaN. Use the same native geometry.
               var x1:Number=isFinite(object.X1)?object.X1:object.X-object.scX/2;
               var x2:Number=isFinite(object.X2)?object.X2:object.X+object.scX/2;
               var y1:Number=isFinite(object.Y1)?object.Y1:object.Y-object.scY;
               var y2:Number=isFinite(object.Y2)?object.Y2:object.Y;
               var over:Boolean=eligible && x1<input.aimX && x2>input.aimX && y1<input.aimY && y2>input.aimY;
               object.onCursor=over?object.prior:0;
               if(over && (chosen==null || object.onCursor>=chosen.onCursor))chosen=object;
            }
            room.celObj=chosen;room.celDist=chosen==null?-1:Math.pow(actor.unit.X-chosen.X,2)+Math.pow(actor.unit.Y-chosen.Y,2);
            actor.interacting=(input.buttons&Commands.ACTION)!=0?chosen:null;
            operation();
         }
         finally {
            for(object in marks)object.onCursor=marks[object];
            for(object in reserved)object.levitPoss=reserved[object];
            room.celObj=old;room.celDist=dist;
         }
      }
   }
}
