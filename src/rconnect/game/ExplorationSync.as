package rconnect.game
{
   import flash.display.BitmapData;
   import flash.display.DisplayObjectContainer;
   import flash.events.Event;
   import flash.utils.Dictionary;
   import flash.utils.getTimer;
   import rconnect.core.Log;

   /** Optional display-only exploration adapter. No RV classes or linkage. */
   public class ExplorationSync
   {
      private static const HEX:String = "0123456789abcdef";
      private var mod:RConnectMod;
      private var memories:Dictionary = new Dictionary(true);
      private var gameRef:Object;
      private var roomRef:Object;
      private var roomKey:String = "";
      private var serial:int = 0;
      private var epoch:String = "";
      private var remoteEpoch:String = "";
      private var lastSent:String = "";
      private var lastAt:int = -10000;
      private var lastFull:int = -10000;
      private var api:Object;
      private var settingsRegistered:Boolean = false;
      private var lastDiscovery:int = -10000;
      public var received:int = 0;

      public function ExplorationSync(owner:RConnectMod)
      {
         mod = owner;
         if(mod.stage != null) mod.stage.addEventListener(Event.EXIT_FRAME, render, false, -100, true);
      }

      public function get enabled():Boolean
      {
         var v:String = String(mod.config.getValue("sharedExploration")).toLowerCase();
         return v != "0" && v != "false" && v != "no";
      }

      public function setEnabled(value:Boolean):void
      {
         mod.config.setValue("sharedExploration", value ? "1" : "0");
         mod.config.save();
         // Already received memory deliberately survives this toggle.
      }

      /** New TCP session changes the handshake, not the player's acquired map. */
      public function resetLink():void
      {
         epoch = ""; remoteEpoch = ""; roomRef = null;
         lastSent = ""; lastAt = lastFull = -10000;
      }

      private function discover():void
      {
         if(getTimer() - lastDiscovery < 1000) return;
         lastDiscovery = getTimer();
         try
         {
            var main:DisplayObjectContainer = mod.main as DisplayObjectContainer;
            if(main == null) return;
            var carrier:Object = main.getChildByName("RVExplorationAPI");
            api = carrier != null ? carrier["api"] : null;
            if(api != null && (api.version !== 1 || !(api.capture is Function)
               || !(api.merge is Function) || !(api.active is Function))) api = null;
            if(!settingsRegistered)
            {
               var settings:Object = main.getChildByName("ModSettingsCarrier");
               if(settings == null) settings = main.getChildByName("MSWModAPICarrier");
               if(settings != null && settings["modAPI"] != null)
               {
                  var self:ExplorationSync = this;
                  settings["modAPI"]["registerPage"]("rconnect", "RConnect 联机", [
                     {key:"sharedExploration", label:"接收队友探索", kind:"check",
                      min:0, max:1, step:1, def:true,
                      hint:"只控制本端接收；关闭后保留已收到的区域",
                      get:function():* { return self.enabled; },
                      set:function(v:*):void { self.setEnabled(v == true); }}
                  ], function():void {}, "双向共享探索，各端独立开关");
                  settingsRegistered = true;
               }
            }
         }
         catch(err:*) { api = null; }
      }

      private function context():Object
      {
         mod.game.refreshWorld();
         var w:Object = mod.game.world, loc:Object = mod.game.loc;
         if(w == null || loc == null || !loc.active || mod.game.gg == null || mod.game.isTransitioning()) return null;
         if(w.game !== gameRef)
         {
            gameRef = w.game; memories = new Dictionary(true); resetLink();
         }
         var cols:int = int(loc.spaceX), rows:int = int(loc.spaceY);
         if(cols < 1 || rows < 1 || cols > 200 || rows > 200) return null;
         var info:Object = mod.game.readWorldInfo();
         if(info == null || !info.curLandId || !info.locId) return null;
         var key:String = JSON.stringify([info.curLandId, info.locId, info.curCoord,
            info.landStage, cols, rows]);
         if(memories[loc] != null && memories[loc].key !== key) delete memories[loc];
         if(loc !== roomRef || key != roomKey || epoch == "")
         {
            roomRef = loc; roomKey = key;
            epoch = new Date().time.toString(36) + "-" + (++serial) + "-" + Math.random().toString(36);
            remoteEpoch = ""; lastSent = ""; lastFull = -10000;
         }
         return {loc:loc, key:key, cols:cols, height:rows};
      }

      /** 17 lowercase hex chars per tile: brightness nibble + 64 subcell bits. */
      public static function validRows(data:*, cols:int, height:int):Boolean
      {
         if(!(data is Array) || cols < 1 || height < 1 || cols > 200 || height > 200
            || data.length != height) return false;
         for each(var row:* in data)
            if(!(row is String) || row.length != cols * 17 || /[^0-9a-f]/.test(row)) return false;
         return true;
      }

      public static function nativeRows(loc:Object):Array
      {
         var data:Array = [];
         for(var y:int = 0; y < int(loc.spaceY); y++)
         {
            var row:Array = [];
            for(var x:int = 0; x < int(loc.spaceX); x++)
            {
               var value:Number = Number(loc.space[x][y].visi);
               var light:int = isNaN(value) ? 0 : Math.max(0, Math.min(15, Math.round(value * 15)));
               row.push(HEX.charAt(light) + (light > 0 ? "ffffffffffffffff" : "0000000000000000"));
            }
            data.push(row.join(""));
         }
         return data;
      }

      /** Monotone union: retained knowledge cannot be erased by a later packet. */
      public static function unionRows(old:Array, incoming:Array):Array
      {
         if(old == null) return incoming.concat();
         var result:Array = [];
         for(var y:int = 0; y < incoming.length; y++)
         {
            var a:String = old[y], b:String = incoming[y], row:Array = [];
            for(var i:int = 0; i < b.length; i++)
            {
               var av:int = HEX.indexOf(a.charAt(i)), bv:int = HEX.indexOf(b.charAt(i));
               row.push(HEX.charAt(i % 17 == 0 ? Math.max(av,bv) : av | bv));
            }
            result.push(row.join(""));
         }
         return result;
      }

      public function packet():Object
      {
         discover();
         var now:int = getTimer();
         if(now - lastAt < 500) return null;
         lastAt = now;
         var c:Object = context();
         if(c == null) return null;
         var data:Array;
         try { if(api != null) data = api.capture(c.loc) as Array; } catch(err:*) { api = null; }
         if(!validRows(data,c.cols,c.height))
         {
            try { data = nativeRows(c.loc); } catch(nativeError:*) { return null; }
         }
         var retained:Object = memories[c.loc];
         if(retained != null) data = unionRows(data,retained.data);
         var signature:String = remoteEpoch + "|" + data.join("");
         if(signature == lastSent && now - lastFull < 3000) return null;
         lastSent = signature; lastFull = now;
         return {v:1, room:c.key, epoch:epoch, to:remoteEpoch,
            cols:c.cols, height:c.height, rows:data};
      }

      public function receive(p:Object):Boolean
      {
         discover();
         var c:Object = context();
         if(c == null || p == null || p.v !== 1 || p.room !== c.key
            || p.cols !== c.cols || p.height !== c.height || !(p.epoch is String)
            || p.epoch.length < 1 || p.epoch.length > 100 || !validRows(p.rows,c.cols,c.height)) return false;
         // Both rooms must acknowledge each other's current instance before merging.
         remoteEpoch = p.epoch;
         if(!enabled || p.to !== epoch) return false;
         var old:Object = memories[c.loc];
         var data:Array = unionRows(old != null ? old.data : null, p.rows);
         memories[c.loc] = {key:c.key, data:data, apiApplied:null};
         received++;
         applyRV(c.loc, memories[c.loc]);
         return true;
      }

      private function applyRV(loc:Object, memory:Object):void
      {
         if(api == null || memory.apiApplied === api) return;
         try { if(api.merge(loc, memory.data) === true) memory.apiApplied = api; }
         catch(err:*) { api = null; }
      }

      private function render(e:Event):void
      {
         try
         {
            discover();
            var c:Object = context();
            if(c == null) return;
            var memory:Object = memories[c.loc];
            if(memory == null) return;
            applyRV(c.loc,memory);
            if(api != null && memory.apiApplied === api && api.active(c.loc) === true) return;
            paintNative(c.loc,memory.data);
         }
         catch(err:*) { /* Optional display integration must not interrupt gameplay. */ }
      }

      public static function paintNative(loc:Object, data:Array):void
      {
         // These rooms deliberately do not retain full-bright history.
         if(loc.retDark) return;
         var bmp:BitmapData = loc.grafon.lightBmp as BitmapData;
         if(bmp == null) return;
         for(var y:int = 1; y < int(loc.spaceY); y++)
         {
            var row:String = data[y];
            for(var x:int = 1; x < int(loc.spaceX); x++)
            {
               var remote:Number = HEX.indexOf(row.charAt(x * 17)) / 15;
               var local:Number = Number(loc.space[x][y].visi);
               if(remote > local) bmp.setPixel32(x,y+1,Math.floor((1-remote)*255) << 24);
            }
         }
      }
   }
}
