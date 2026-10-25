package lad {
    /** The trigger value is an immutable JSON string: native save() copies it by value. */
    public final class LadStore {
        public static const KEY:String = "lightanddarkness.state.v1";
        private var game:*;
        public var data:Object;
        public var writable:Boolean = true;
        public function bind(value:*):void {
            game = value; writable = true;
            data = {version:1, rooms:{}, headlamp:true};
            var encoded:* = game.triggers[KEY];
            if(encoded == null) return;
            try {
                var decoded:Object = JSON.parse(String(encoded));
                if(decoded.version != 1 || decoded.rooms == null) throw new Error("unsupported state version");
                data = decoded;
            } catch(error:*) {
                writable = false;
                LadLog.write("SAVE_REJECT " + error + "; original trigger retained");
            }
        }
        public function room(key:String):Object {
            if(!data.rooms.hasOwnProperty(key)) data.rooms[key] = {};
            return data.rooms[key];
        }
        public function flush():void {
            if(!writable || game == null) return;
            game.triggers[KEY] = JSON.stringify(data);
        }
        public static function roomKey(loc:*):String {
            var hash:uint = 2166136261;
            // Hash the pristine room definition, never mutable/destroyed terrain.
            var identity:String=loc.room && loc.room.xml ? loc.room.xml.toXMLString() : String(loc.id);
            var fixtures:Array=[];
            for each(var bo:* in loc.backobjs) if(LadLampCatalog.isLamp(String(bo.id)))
                fixtures.push([bo.id,bo.X,bo.Y,bo.scX,bo.scY].join(":"));
            fixtures.sort();identity += fixtures.join("|");
            for(var n:int=0; n<identity.length; n++) {
                hash ^= identity.charCodeAt(n);
                hash += (hash<<1)+(hash<<4)+(hash<<7)+(hash<<8)+(hash<<24);
            }
            return [loc.land.act.id,loc.id,loc.landX,loc.landY,loc.landZ,loc.landProb,
                loc.mirror,loc.spaceX,loc.spaceY,hash.toString(16)].join("|");
        }
    }
}
