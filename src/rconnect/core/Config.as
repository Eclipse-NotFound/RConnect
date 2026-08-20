package rconnect.core
{
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /**
    * 配置读写。
    * 读取优先级：applicationStorageDirectory/config.txt（用户已保存值）
    * > release/config.txt（随模组分发的默认值）> 内置默认。
    * 修改后保存到 applicationStorageDirectory（AIR 应用目录可能是只读的）。
    */
   public class Config
   {
      public static const DEFAULTS:Object = {
         nickname: "Pony",
         hostIp: "127.0.0.1",
         port: 23456,
         tickMs: 50,
         autoRole: "",
         autoGame: "",
         autoMove: "",
         autoTravel: "",
         autoFollow: "",
         freezeAI: "",
         autoDamage: "",
         autoTravelLand: "",
         worldInject: "1",
         ghostCombat: "1",
         autoGhostDmg: "",
         autoHeal: "",
         autoLoadSave: "",
         autoHostKill: "",
         autoDeactivate: "",
         autoWalk: "",
        autoGhostAnim: "",
         testGhostDmg: 50
      };

      public var values:Object = {};

      public function Config()
      {
         load();
      }

      public function getValue(key:String):*
      {
         return values[key] != undefined ? values[key] : DEFAULTS[key];
      }

      public function setValue(key:String, val:*):void
      {
         values[key] = val;
      }

      public function load():void
      {
         values = {};
         var base:Object = readJson(releaseConfigFile());
         var user:Object = readJson(userConfigFile());
         // 简单合并：user 覆盖 base，两者缺省走 DEFAULTS
         for(var k:String in DEFAULTS)
         {
            if(user != null && user[k] != undefined)
            {
               values[k] = user[k];
            }
            else if(base != null && base[k] != undefined)
            {
               values[k] = base[k];
            }
            else
            {
               values[k] = DEFAULTS[k];
            }
         }
         // 数值类型兜底
         values.port = int(values.port);
         if(values.port <= 0 || values.port > 65535)
         {
            values.port = DEFAULTS.port;
         }
         values.tickMs = int(values.tickMs);
         if(values.tickMs < 20 || values.tickMs > 500)
         {
            values.tickMs = DEFAULTS.tickMs;
         }
         values.nickname = String(values.nickname).substr(0, 24);
         values.hostIp = String(values.hostIp);
         values.autoRole = String(values.autoRole);
         values.autoGame = String(values.autoGame);
         values.autoMove = String(values.autoMove);
         values.autoTravel = String(values.autoTravel);
         values.autoFollow = String(values.autoFollow);
         values.freezeAI = String(values.freezeAI);
         values.autoDamage = String(values.autoDamage);
         values.autoTravelLand = String(values.autoTravelLand);
         values.worldInject = String(values.worldInject);
         values.ghostCombat = String(values.ghostCombat);
         values.autoGhostDmg = String(values.autoGhostDmg);
         values.autoHeal = String(values.autoHeal);
         values.autoLoadSave = String(values.autoLoadSave);
         values.autoHostKill = String(values.autoHostKill);
         values.autoDeactivate = String(values.autoDeactivate);
         values.autoWalk = String(values.autoWalk);
        values.autoGhostAnim = String(values.autoGhostAnim);
         values.testGhostDmg = Number(values.testGhostDmg);
         if(!isFinite(values.testGhostDmg) || values.testGhostDmg < 0)
         {
            values.testGhostDmg = DEFAULTS.testGhostDmg;
         }
      }

      public function save():void
      {
         writeJson(userConfigFile(), values);
      }

      /** app:/mods/Rconnect/release/config.txt */
      private function releaseConfigFile():File
      {
         try
         {
            return File.applicationDirectory.resolvePath(
               "mods/Rconnect/release/config.txt");
         }
         catch(err:*)
         {
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      private function userConfigFile():File
      {
         try
         {
            return File.applicationStorageDirectory.resolvePath(
               "Rconnect_config.txt");
         }
         catch(err:*)
         {
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      private function readJson(f:File):Object
      {
         if(f == null || !f.exists)
         {
            return null;
         }
         var fs:FileStream = new FileStream();
         try
         {
            fs.open(f, FileMode.READ);
            var s:String = fs.readUTFBytes(fs.bytesAvailable);
            fs.close();
            return JSON.parse(s);
         }
         catch(err:*)
         {
            trace("RConnect: config read failed: " + err);
            return null;
         }
         // mxmlc 控制流怪癖：全部 return 都在 try/catch 内会误报"无返回值"
         return null;
      }

      private function writeJson(f:File, o:Object):void
      {
         if(f == null)
         {
            return;
         }
         var fs:FileStream = new FileStream();
         try
         {
            fs.open(f, FileMode.WRITE);
            fs.writeUTFBytes(JSON.stringify(o));
            fs.close();
         }
         catch(err:*)
         {
            trace("RConnect: config write failed: " + err);
         }
      }
   }
}
