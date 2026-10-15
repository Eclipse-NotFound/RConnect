package {
   import flash.desktop.NativeApplication;
   import flash.display.Sprite;
   import flash.display.Loader;
   import flash.events.Event;
   import flash.events.IOErrorEvent;
   import flash.net.Socket;
   import flash.net.URLRequest;
   import flash.filesystem.File;
   import flash.system.Capabilities;
   import flash.utils.setTimeout;
   public class SocketApiProbeDoc extends Sprite {
      private var socket:Socket=new Socket(),helper:Loader=new Loader(),done:Boolean=false;
      public function SocketApiProbeDoc() {
         if(NativeApplication.nativeApplication.applicationID.indexOf("rconnect-socket-api-")!=0)return;
         setTimeout(begin,1);
      }
      private function begin():void {
         trace("SOCKET API ROOT "+JSON.stringify({runtime:NativeApplication.nativeApplication.runtimeVersion,
            player:Capabilities.version,swf:loaderInfo.swfVersion,has:"tcpNoDelay" in socket}));
         helper.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
            trace("SOCKET API HELPER "+JSON.stringify(Object(helper.content).inspect(socket)));finish();
         });
         helper.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,function(e:IOErrorEvent):void {trace(e.text);finish();});
         setTimeout(function():void {if(!done){trace("SOCKET API TIMEOUT");finish();}},10000);
         helper.load(new URLRequest(File.applicationDirectory.resolvePath("Helper.swf").url));
      }
      private function finish():void {if(done)return;done=true;NativeApplication.nativeApplication.exit();}
   }
}
