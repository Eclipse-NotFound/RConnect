package {
   import flash.display.Sprite;
   import flash.net.Socket;
   public class SocketApiHelper extends Sprite {
      public function inspect(oldSocket:Object):Object {
         var own:Object=new Socket(),r:Object={swf:loaderInfo.swfVersion,oldHas:"tcpNoDelay" in oldSocket,ownHas:"tcpNoDelay" in own};
         try {oldSocket["tcpNoDelay"]=true;r.oldValue=oldSocket["tcpNoDelay"];}catch(e:Error){r.oldError=String(e);}
         try {own["tcpNoDelay"]=true;r.ownValue=own["tcpNoDelay"];}catch(e:Error){r.ownError=String(e);}
         return r;
      }
   }
}
