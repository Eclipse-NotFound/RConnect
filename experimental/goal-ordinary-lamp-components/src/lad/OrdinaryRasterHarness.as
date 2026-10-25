package lad {
import flash.utils.Dictionary;
import flash.utils.getDefinitionByName;
public class OrdinaryRasterHarness {
public var enabled:Boolean=true;
private var location:Object,failedLocation:Object,ordinaryRaster:Object;
        /** First-pass omission only. Native BackObj fields stay unchanged until normal attach. */
        public function beginOrdinaryRaster(w:*,g:*,loc:*,firstRaster:Boolean):Object {
            try {
                if(!firstRaster || !enabled || !w || int(w.t_exit)!=19 || !loc || !loc.land || !loc.land.act
                    || !loc.land.act.rnd || loc.spaceX>48 || loc.spaceY>25 || loc.spaceX<=0 || loc.spaceY<=0
                    || !g || g.sceneLarge || loc===location || loc===failedLocation) return null;
                var ticket:Object={world:w,game:w.game,player:w.gg,loc:loc,grafon:g,lamps:[],omit:new Dictionary(true),
                    complete:false,cancelled:false,redrawBefore:int(g.sceneRedraws),redrawComplete:-1};
                if(!ordinaryRasterIdentity(ticket)) return null;
                cancelOrdinaryRaster(true);
                if(ordinaryRaster) return null; // A native draw still owns the pending ticket.
                for each(var bo:* in loc.backobjs) {
                    if(!LadLampCatalog.isLamp(String(bo.id)) || bo.vis==null) continue;
                    if(ticket.omit[bo]) return null;
                    ticket.lamps.push(bo);ticket.omit[bo]=true;
                }
                if(!ticket.lamps.length) return null;
                ordinaryRaster=ticket;return ticket;
            } catch(error:*) {LadLog.write("INITIAL_RASTER_PREPARE_FAILED "+error);}
            return null;
        }
        public function completeOrdinaryRaster(ticket:Object,success:Boolean):void {
            if(ticket==null || ticket!==ordinaryRaster) return;
            if(!success || int(ticket.grafon.sceneRedraws)!=int(ticket.redrawBefore)+1) {
                // No native references changed; leave the original draw/error outcome intact.
                ordinaryRaster=null;return;
            }
            ticket.redrawComplete=int(ticket.grafon.sceneRedraws);ticket.complete=true;
            if(ticket.cancelled || !enabled || !ordinaryRasterIdentity(ticket)) cancelOrdinaryRaster(true);
        }
        private function ordinaryRasterIdentity(ticket:Object):Boolean {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                var w:*=WorldClass["w"],loc:*=ticket.loc,g:*=ticket.grafon;
                return w===ticket.world && Number(WorldClass["boxDamage"])==0.2 && w.game===ticket.game
                    && w.game!=null && w.gg===ticket.player && w.gg!=null && w.gg.loc===loc
                    && loc.gg===w.gg && loc.active && w.loc===loc && w.land===loc.land && w.land.loc===loc
                    && w.grafon===g && g.loc===loc && loc.grafon===g && !g.sceneLarge && int(w.allStat)==1
                    && (!w.verror || !w.verror.visible);
            } catch(ignored:*) {}
            return false;
        }
        private function ordinaryRasterOwnsPixels(ticket:Object):Boolean {
            try {
                var WorldClass:Class=getDefinitionByName("fe.World") as Class;
                var w:*=WorldClass["w"],g:*=ticket.grafon;
                return ticket.complete && w===ticket.world && w.grafon===g && w.loc===ticket.loc
                    && g.loc===ticket.loc && !g.sceneLarge && int(g.sceneRedraws)==int(ticket.redrawComplete);
            } catch(ignored:*) {}
            return false;
        }
        private function restoreOrdinaryRefs(refs:Array):void {
            for each(var item:Object in refs) {
                if(item.bo.vis===null) item.bo.vis=item.vis;
                if(item.bo.light===null) item.bo.light=item.light;
                if(item.bo.erase===null) item.bo.erase=item.erase;
            }
        }
        private function cancelOrdinaryRaster(redraw:Boolean):void {
            var ticket:Object=ordinaryRaster;if(ticket==null) return;
            if(!ticket.complete) {ticket.cancelled=true;return;}
            ordinaryRaster=null;
            if(!redraw || !ordinaryRasterOwnsPixels(ticket)) return;
            var refs:Array=[];
            for each(var bo:* in ticket.lamps) refs.push({bo:bo,vis:bo.vis,light:bo.light,erase:bo.erase});
            try {
                // Strip BEFORE BAKE's clean comparison; restore INSIDE its mutation.
                for each(var item:Object in refs) {item.bo.vis=null;item.bo.light=null;item.bo.erase=null;}
                LadSceneBake.change(ticket.grafon,ticket.loc,
                    function():void {restoreOrdinaryRefs(refs);},ticket.world.cam);
            } finally {restoreOrdinaryRefs(refs);}
        }
        private function canUseOrdinaryRaster(loc:*,found:Array):Boolean {
            var ticket:Object=ordinaryRaster;if(ticket==null) return false;
            var same:Boolean=ticket.loc===loc && ordinaryRasterIdentity(ticket) && ordinaryRasterOwnsPixels(ticket)
                && found.length==ticket.lamps.length;
            var seen:Dictionary=new Dictionary(true);
            if(same) for each(var lamp:Object in found) {
                if(!ticket.omit[lamp.bo] || seen[lamp.bo]) {same=false;break;}
                seen[lamp.bo]=true;
            }
            if(!same) cancelOrdinaryRaster(true);
            return same;
        }

public function pending():Object{return ordinaryRaster;}
public function eligibleSet(loc:Object,found:Array):Boolean{return canUseOrdinaryRaster(loc,found);}
public function cancel(redraw:Boolean=true):void{cancelOrdinaryRaster(redraw);}
public function attachIdentity(loc:Object,failed:Object=null):void{location=loc;failedLocation=failed;}
}}
