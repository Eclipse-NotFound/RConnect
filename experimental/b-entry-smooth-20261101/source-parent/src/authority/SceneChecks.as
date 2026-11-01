package authority {
   import flash.display.BitmapData;
   import flash.display.Stage;
   import flash.display.PNGEncoderOptions;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;
   import flash.geom.Rectangle;
   public final class SceneChecks {
      public var matches:Boolean=true,frames:uint=0,visibleEnemies:uint=0,turretFrames:uint=0,roomChanges:uint=0;
      private var previous:String="",captured:Boolean=false;
      private var mismatch:Object;
      public var expectedRooms:Array;
      private var route:Array=[];
      private function eq(ok:Boolean,reason:String,details:Object=null):void {
         if(!ok && mismatch==null){mismatch={reason:reason,details:details};Log.write("scene-mismatch",mismatch);}matches=matches && ok;
      }
      public function observe(replica:ClientReplica):void {
         var frame:Object=replica.displayFrame,scene:ReplicaScene=replica.scene;
         if(scene==null || frame.scene==null)return;
         ++frames;if(previous!==scene.key){++roomChanges;previous=scene.key;route.push(scene.key);}
         eq(scene.key===frame.room && replica.access.world.loc===scene.room && replica.access.world.gg.loc===scene.room,"scene ownership");
         for each(var s:Object in frame.scene.units) {
            var rec:Object=scene.units[s.key];
            if(rec==null){eq(false,"missing unit",{key:s.key});continue;}
            var u:Object=rec.unit;
            // Some native inactive placements have no finite coordinates yet.
            // They are retained as identities, but must never be drawn there.
            var position:Boolean=NativeFields.has(s,"X") && NativeFields.has(s,"Y");
            var same:Boolean=u.loc===scene.room && u.hp===NativeFields.get(s,"hp") && u.sost===NativeFields.get(s,"sost") &&
               (position?(u.X===NativeFields.get(s,"X") && u.Y===NativeFields.get(s,"Y")):(!s.attached && isNaN(u.X) && isNaN(u.Y)));
            if(!same)eq(false,"unit state",{key:s.key,cls:s.cls,attached:s.attached,local:[u.hp,u.sost,u.X,u.Y],source:[NativeFields.get(s,"hp"),NativeFields.get(s,"sost"),NativeFields.get(s,"X"),NativeFields.get(s,"Y")]});
            if(s.attached && s.pose!=null && s.pose.v && !NativeFields.get(s,"disabled") && NativeFields.get(s,"sost")<3) {
               // RV applies the recipient's field of view after confirmation.
               // A body can correctly be hidden locally although the host sees it.
               eq(u.vis.parent!=null && u.vis.alpha===s.pose.a,"unit display",{key:s.key,cls:s.cls,parent:u.vis.parent!=null,visible:u.vis.visible,alpha:u.vis.alpha,sourceAlpha:s.pose.a});
               if(u.vis.visible){++visibleEnemies;if(s.cls.indexOf("UnitTurret")>=0)++turretFrames;}
            } else if(!s.attached)eq(u.vis==null || u.vis.parent==null,"detached unit",{key:s.key});
         }
         for each(var t:Object in frame.scene.tiles)for(var i:int=0;i<SceneSnapshot.TILE.length;i++)
            if(scene.room.space[t.x][t.y][SceneSnapshot.TILE[i]]!==t.v[i])eq(false,"terrain state",{x:t.x,y:t.y,field:SceneSnapshot.TILE[i],local:scene.room.space[t.x][t.y][SceneSnapshot.TILE[i]],source:t.v[i]});
         if(turretFrames>=20 && !captured) {captured=true;picture(replica.access,"scene-turret.png");}
      }
      public function finish(check:Function,enemy:String):void {
         check(frames>50 && matches,"client native terrain, entity health, identity and visibility match confirmed scenes",{frames:frames,matches:matches});
         check(visibleEnemies>0,"client actually attaches living enemy displays",{samples:visibleEnemies});
         if(enemy=="native")check(turretFrames>20,"client actually attaches native turret displays",{samples:turretFrames});
         // Tick zero can present the welcome room before the fixture transfers
         // either player. Check the exact three requested destinations rather
         // than counting that legitimate initial view as an extra visit.
         var exact:Boolean=expectedRooms!=null && (route.length==3 || route.length==4);
         if(exact)for(var i:int=0;i<3;i++)exact=exact && route[route.length-3+i]===expectedRooms[i];
         check(exact,"client presents the exact confirmed background/foreground/background route",{actual:route,expected:expectedRooms});
      }
      public static function picture(access:NativeAccess,name:String):void {
         var stage:Stage=access.world.swfStage as Stage,data:BitmapData=new BitmapData(stage.stageWidth,stage.stageHeight,false,0);
         data.draw(stage);var file:File=File.applicationStorageDirectory.resolvePath(name),stream:FileStream=new FileStream();
         stream.open(file,FileMode.WRITE);stream.writeBytes(data.encode(data.rect,new PNGEncoderOptions()));stream.close();data.dispose();
         Log.write("screenshot",{path:file.nativePath});
         var w:Object=access.world;
         Log.write("scene-display-diagnostic",{room:access.roomKey(),visual:NativeFields.capture(w.visual),
            visualBounds:String(w.visual.getBounds(stage)),bgBounds:String(w.vfon.getBounds(stage)),black:w.loc.black,
            player:{x:w.gg.X,y:w.gg.Y,visible:w.gg.vis.visible,alpha:w.gg.vis.alpha,bounds:String(w.gg.vis.getBounds(stage))},
            layerBounds:String(w.grafon.visObjs[1].getBounds(stage))});
      }
   }
}
