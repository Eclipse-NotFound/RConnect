package lad {
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;

    /** Visual preferences belong to this AIR profile, not to a particular save slot. */
    public final class LadLightingPreferences {
        public static const KEYS:Array=["outdoor","safe","maintained","interior","abandoned","underground","outage"];
        public static const LABELS:Array=["室外天光","安全据点","维护设施","一般室内","废弃地区","地下区域","停电房间"];
        private static const DEFAULTS:Object={outdoor:1,safe:0.82,maintained:0.72,interior:0.68,abandoned:0.62,underground:0.48,outage:0.24};
        private var values:Object={};
        public var multiplier:Number=1;
        public var lampRange:Number=1.10;
        public function LadLightingPreferences() { bind(null); }
        public function bind(value:Object):void {
            value=value || {};values={};
            for each(var key:String in KEYS) values[key]=LadAtmosphere.clamp(value.regions?value.regions[key]:null,0.10,1,DEFAULTS[key]);
            multiplier=LadAtmosphere.clamp(value.multiplier,0.5,1.5,1);
            lampRange=LadAtmosphere.clamp(value.lampRange,0.5,1.5,1.10);
        }
        public function getLevel(key:String):Number {return Number(values[key]);}
        public function setLevel(key:String,value:*):void {
            if(DEFAULTS.hasOwnProperty(key))values[key]=LadAtmosphere.clamp(value,0.10,1,DEFAULTS[key]);
        }
        public function signature():String {
            var parts:Array=[];for each(var key:String in KEYS)parts.push(values[key]);return parts.join(":");
        }
        public function snapshot():Object {return {version:1,regions:JSON.parse(JSON.stringify(values)),multiplier:multiplier,lampRange:lampRange};}
        public function load():void {
            var file:File=File.applicationStorageDirectory.resolvePath("LightAndDarkness.lighting.json");
            if(!file.exists)return;
            var stream:FileStream=new FileStream();
            try {
                stream.open(file,FileMode.READ);var value:Object=JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
                if(value.version!=1)throw new Error("unsupported lighting preferences");
                bind(value);
            } catch(error:*) {LadLog.write("LIGHTING_PREFERENCES_REJECT "+error+"; defaults retained");}
            finally {try {stream.close();}catch(ignored:*){}}
        }
        public function save():void {
            var file:File=File.applicationStorageDirectory.resolvePath("LightAndDarkness.lighting.json"),temp:File=file.parent.resolvePath(file.name+".tmp");
            var stream:FileStream=new FileStream();
            try {stream.open(temp,FileMode.WRITE);stream.writeUTFBytes(JSON.stringify(snapshot()));stream.close();temp.moveTo(file,true);}
            catch(error:*) {LadLog.write("LIGHTING_PREFERENCES_SAVE_FAILED "+error);}
            finally {try {stream.close();}catch(ignored:*){}}
        }
    }
}
