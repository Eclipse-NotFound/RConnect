package rconnect.game
{
   import fe.loc.Tile;
   /** Native tile damage, prediction receipts, and persistent host state.
    * The game's grid is space[x][y]. Never infer orientation from a square room. */
   public class TerrainSync
   {
      private static const FIELDS:Object = {p:"phis",f:"front",b:"back",z:"zad",
         zf:"zForm",w:"water",st:"stair",h:"hp",o:"opac",v:"vid",v2:"vid2",
         d:"diagon",sh:"shelf"};
      private var room:Object;
      private var base:Array = [];
      private var observed:Object = {};
      private var queued:Object = {};
      private var pending:Object;
      private var receipts:Object = {};
      private var epoch:int = 0;
      private var seq:int = 0;
      private var cursor:int = 0;
      public var dirty:Boolean = false;

      public function reset():void { room=null; base=[]; observed={}; queued={}; pending=null; receipts={}; dirty=false; }

      public function checkpoint(loc:Object):Object
      {
         enter(loc);var table:Object=NativeTileState.capture(loc);
         if(table!=null)return table;
         var out:Array=[];
         for(var x:int=0;x<int(loc.spaceX);x++)for(var y:int=0;y<int(loc.spaceY);y++)
         {
            var t:Object=tile(x,y),s:Object=state(t,x,y);
            s.native=NativeRoomState.scalars(t);out.push(s);
         }
         return out;
      }
      public function restoreCheckpoint(loc:Object,snapshot:Object):void
      {
         reset();enter(loc);
         if(snapshot!=null && !(snapshot is Array) && (snapshot.nativeTileTable===1 || snapshot.nativeTileTable===2)) {
            NativeTileState.restore(loc,snapshot,function(t:Object,x:int,y:int):void {observed[key(x,y)]=state(t,x,y);});
            dirty=true;return;
         }
         var list:Array=snapshot as Array;
         if(list==null)throw new Error("Invalid terrain checkpoint");
         for each(var s:Object in list)NativeRoomState.restore(tile(int(s.x),int(s.y)),s.native);
         apply(loc,list,false);dirty=true;
      }

      private function enter(loc:Object):void
      {
         if(room===loc) return;
         reset(); room=loc; epoch++; cursor=0;
         if(room==null) return;
         for(var x:int=0;x<int(room.spaceX);x++)
         {
            var column:Array=base[x]=[];
            for(var y:int=0;y<int(room.spaceY);y++)
            {
               var t:Object=tile(x,y);
               if(t==null) continue;
               column[y]=observed[key(x,y)]=state(t,x,y);
            }
         }
      }

      private function key(x:int,y:int):String {return x+","+y;}
      private function tile(x:int,y:int):Object
      {
         if(room==null || x<0 || y<0 || x>=int(room.spaceX) || y>=int(room.spaceY)) return null;
         return room.space[x][y];
      }
      private function state(t:Object,x:int,y:int):Object
      {
         var native:Tile=t as Tile;
         if(native!=null)return {x:x,y:y,p:native.phis,f:native.front,b:native.back,z:native.zad,
            zf:native.zForm,w:native.water,st:native.stair,h:native.hp,o:native.opac,v:native.vid,
            v2:native.vid2,d:native.diagon,sh:native.shelf};
         return dynamicState(t,x,y);
      }
      // Only fallback objects require optional field access. Keep their
      // missing/throwing-member behavior outside the native Tile hot path.
      private function dynamicState(t:Object,x:int,y:int):Object
      {
         var s:Object={x:x,y:y};
         for(var f:String in FIELDS) try {s[f]=t[FIELDS[f]];} catch(e:*) {}
         return s;
      }
      /** Most tiles do not change between packets. Compare their native fields
       * before allocating a snapshot; cached baselines must remain immutable. */
      private function matchesTile(t:Object,s:Object):Boolean
      {
         if(t==null || s==null) return false;
         var native:Tile=t as Tile;
         if(native!=null)return s.p===native.phis && s.f===native.front && s.b===native.back
            && s.z===native.zad && s.zf===native.zForm && s.w===native.water && s.st===native.stair
            && s.h===native.hp && s.o===native.opac && s.v===native.vid && s.v2===native.vid2
            && s.d===native.diagon && s.sh===native.shelf;
         return matchesDynamicTile(t,s);
      }
      // Keep the generic object's missing/getter semantics in a separate
      // catch scope, so unchanged native tiles allocate no catch activation.
      private function matchesDynamicTile(t:Object,s:Object):Boolean
      {
         for(var f:String in FIELDS)
         {
            var value:*;
            try {value=t[FIELDS[f]];} catch(error:*) {value=undefined;}
            if(s[f]!==value) return false;
         }
         return true;
      }
      private function equal(a:Object,b:Object):Boolean
      {
         if(a==null || b==null) return false;
         for(var f:String in FIELDS) if(a[f]!==b[f]) return false;
         return true;
      }

      /** Repeats non-default state for new peers, rotating past the packet limit. */
      public function hostPatch(loc:Object):Array
      {
         enter(loc); if(room==null) return null;
         var out:Array=[],total:int=int(room.spaceX)*int(room.spaceY),height:int=int(room.spaceY);
         for(var i:int=0;i<total && out.length<128;i++)
         {
            var index:int=cursor; cursor=(cursor+1)%total;
            var x:int=int(index/height),y:int=index%height,t:Object=tile(x,y);
            if(t==null) continue;
            // Column coordinates stay valid if this room changes dimensions.
            var column:Array=base[x] as Array;
            if(!matchesTile(t,column==null?null:column[y])) out.push(state(t,x,y));
         }
         return out.length?out:null;
      }

      private function capture():void
      {
         if(room==null) return;
         for(var k:String in observed)
         {
            var old:Object=observed[k],t:Object=tile(old.x,old.y);
            if(t==null || matchesTile(t,old)) continue;
            var now:Object=state(t,old.x,old.y);
            // Door objects have their own authoritative protocol. Only damage
            // that the native tile accepted may become a terrain request.
            if(t.indestruct!=true && t.door==null && Number(old.p)>0)
            {
               var loss:Number=Math.max(0,Number(old.h)-Number(now.h));
               var destroyed:Boolean=Number(now.p)==0 && Number(old.p)>0;
               if(loss>0 || destroyed)
               {
                  var q:Object=queued[k];
                  if(q==null) q=queued[k]={x:old.x,y:old.y,damage:0,destroy:false};
                  q.damage+=loss;
                  // Some native destruction paths remove the tile without HP damage.
                  q.destroy=q.destroy || (destroyed && loss==0);
               }
            }
            observed[k]=now;
         }
      }

      public function report(loc:Object):Object
      {
         enter(loc); capture();
         if(pending!=null) return null; // TCP is ordered; one unacknowledged batch.
         var list:Array=[];
         for(var k:String in queued)
         {
            list.push(queued[k]); delete queued[k];
            if(list.length>=128) break;
         }
         if(!list.length) return null;
         pending={epoch:epoch,seq:++seq,tiles:list};
         return pending;
      }

      /** Close an old room on the ordered TCP stream. The existing pending
       * batch was already sent; send every later hit before the room-ready
       * message, without waiting for receipts that may cross the barrier. */
      public function finishReports(loc:Object):Array
      {
         enter(loc);capture();
         var batches:Array=[],list:Array=[];
         for(var k:String in queued)
         {
            list.push(queued[k]);delete queued[k];
            if(list.length==128)
            {batches.push({epoch:epoch,seq:++seq,tiles:list});list=[];}
         }
         if(list.length)batches.push({epoch:epoch,seq:++seq,tiles:list});
         pending=null;
         return batches;
      }

      private function predicted(k:String):Boolean
      {
         if(queued[k]!=null) return true;
         if(pending!=null) for each(var p:Object in pending.tiles) if(key(p.x,p.y)==k) return true;
         return false;
      }

      public function apply(loc:Object,list:Array,predict:Boolean):void
      {
         enter(loc);
         if(predict) capture(); // A packet can arrive before the next report tick.
         if(list==null) return;
         for each(var s:Object in list)
         {
            if(s==null || !isFinite(Number(s.x)) || !isFinite(Number(s.y))) continue;
            var x:int=int(s.x),y:int=int(s.y),k:String=key(x,y),t:Object=tile(x,y);
            if(t==null || (predict && predicted(k))) continue;
            var before:Object=state(t,x,y);
            // A live door's collision/opacity/HP belong to its Box and interaction
            // acknowledgement. Terrain packets can contain an older open state.
            // Reapplying it here fights local toggles and looks like tile damage.
            var doorOwned:Boolean=predict && t.door!=null;
            for(var f:String in FIELDS)
            {
               if(s[f]===undefined) continue;
               if(doorOwned && (f=="p" || f=="o" || f=="h"))continue;
               // Recompute native collision bounds when a partial tile changes shape.
               if(f=="zf" && t["setZForm"] is Function) t.setZForm(int(s.zf));
               else t[FIELDS[f]]=s[f];
            }
            // setZForm also changes opacity; the host's final opacity wins.
            if(doorOwned) {t.phis=before.p;t.opac=before.o;t.hp=before.h;}
            else if(s.o!==undefined) t.opac=s.o;
            observed[k]=state(t,x,y);
            if(!equal(before,observed[k]))
            {
               // A destroyed native tile changes the foreground bitmap in place.
               // Rebuilding drawLoc for each enemy hit resets all display layers
               // and the camera, and omits the actual fragment animation.
               var painted:Boolean=predict && paintDestruction(t,before,observed[k]);
               // HP-only corrections do not change the room image or camera.
               for(var visual:String in FIELDS)
                  if(visual!="h" && before[visual]!==observed[k][visual] && !painted) dirty=true;
               if(Number(before.p)!=Number(observed[k].p))
                  try
                  {
                     room.isRebuild=true;
                     if(y<room.waterLevel) {room.recalcTiles.push(t);room.isRecalc=true;}
                  }
                  catch(waterError:*) {}
            }
         }
      }

      /** Presentation only: do not call hitTile/dieTile again on the receiver.
       * Checkpoints and unrelated structural changes retain the full redraw. */
      private function paintDestruction(t:Object,before:Object,after:Object):Boolean
      {
         if(t.door!=null)return false;
         if(Number(before.p)<1 || Number(after.p)!=0)return false;
         for each(var field:String in ["b","z","zf","w","st","d","sh"])
            if(before[field]!==after[field])return false;
         try {
            if(room.active!=true || room.grafon==null)return false;
            room.grafon.tileDie(t,9);
            return true;
         } catch(visualError:*) {}
         return false;
      }

      /** Host settles once through native collision/graphics rules, never trusts a
       * client-provided tile state. Receipts make duplicate reports harmless. */
      public function settle(loc:Object,peer:String,request:Object):Object
      {
         enter(loc);
         if(room==null || request==null || !(request.tiles is Array)) return null;
         var previous:Object=receipts[peer];
         if(previous!=null && int(previous.epoch)==int(request.epoch) && int(request.seq)<=int(previous.seq))
            return int(request.seq)==int(previous.seq)?previous:null;
         var out:Array=[],seen:Object={},count:int=0;
         for each(var p:Object in request.tiles)
         {
            if(p==null || count++>=128 || !isFinite(Number(p.x)) || !isFinite(Number(p.y))) continue;
            var x:int=int(p.x),y:int=int(p.y),k:String=key(x,y),t:Object=tile(x,y);
            if(t==null || seen[k]) continue;
            seen[k]=true;
            var damage:Number=Number(p.damage);
            if(t.indestruct!=true && t.door==null && Number(t.phis)>0)
            {
               if(isFinite(damage) && damage>0 && damage<=1000000) {
                  var amount:int=int(Math.ceil(damage));
                  var lethal:Boolean=Number(t.thre)<=amount && Number(t.hp)<=amount
                     && (room.destroyOn===true || Number(t.hp)<=500);
                  var wasActive:Boolean=room.active;
                  // Damage still uses native Tile.udar. A surviving wall's
                  // real impact pixels arrive separately; do not add another
                  // random decal at the tile centre during settlement.
                  try {if(!lethal)room.active=false;room.hitTile(t,amount,x*40+20,y*40+20);}
                  finally {room.active=wasActive;}
               }
               else if(p.destroy===true) room.dieTile(t);
            }
            out.push(state(t,x,y));
         }
         var receipt:Object={epoch:int(request.epoch),seq:int(request.seq),tiles:out};
         receipts[peer]=receipt;
         return receipt;
      }

      public function acknowledge(loc:Object,receipt:Object):void
      {
         enter(loc);
         if(pending==null || receipt==null || int(receipt.epoch)!=int(pending.epoch) || int(receipt.seq)!=int(pending.seq)) return;
         capture(); // Preserve further local hits made while the receipt was in flight.
         pending=null;
         apply(loc,receipt.tiles as Array,true);
      }
   }
}
