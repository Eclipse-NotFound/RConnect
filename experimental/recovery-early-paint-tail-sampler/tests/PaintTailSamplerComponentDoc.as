package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filesystem.File;
   import flash.filesystem.FileMode;
   import flash.filesystem.FileStream;

   /** Tiny run_recovery_component entry. No game, real sampler or production slots. */
   public final class PaintTailSamplerComponentDoc extends Sprite {
      // Compile the real adapter too; never instantiate it or call its sampler API.
      private static const REAL_ADAPTER:Class=FlashPaintTailSampler;
      private var ran:Boolean=false;
      public function PaintTailSamplerComponentDoc() {
         if(stage!=null)run();else addEventListener(Event.ADDED_TO_STAGE,added);
      }
      private function added(event:Event):void {removeEventListener(Event.ADDED_TO_STAGE,added);run();}
      private function run():void {
         if(ran)return;ran=true;
         var result:Object;
         try {result=PaintTailSamplerChecks.run();}
         catch(error:*) {
            result={kind:"paint-tail-injected-component",assertions:[{passed:false,label:"component exception: "+String(error)}],
               failed:1,passed:false,realSamplerUsed:false,gameLoaded:false,performanceQualified:false};
         }
         var stream:FileStream=new FileStream();
         stream.open(File.applicationStorageDirectory.resolvePath("result.json"),FileMode.WRITE);
         stream.writeUTFBytes(JSON.stringify(result));stream.close();
         NativeApplication.nativeApplication.exit(result.passed?0:1);
      }
   }
}
