package rconnect.net {
   /** Pure endpoint parsing. A tunnel changes the destination, never the wire format. */
   public final class ConnectAddress {
      public static function port(value:*):int {
         var s:String=String(value).replace(/^\s+|\s+$/g,"");
         if(!/^\d{1,5}$/.test(s))return 0;
         var n:Number=Number(s);return n>=1 && n<=65535?int(n):0;
      }
      public static function parse(value:String,fallback:*):Object {
         var host:String=value==null?"":value.replace(/^\s+|\s+$/g,"");
         if(/^tcp:\/\//i.test(host))host=host.substr(6);
         if(host=="" || /[\s\/@?#\\]/.test(host))return null;
         var selected:*=fallback,match:Object;
         if(host.charAt(0)=="[") {
            match=/^\[([0-9a-fA-F:.]+)\](?::(\d{1,5}))?$/.exec(host);
            if(match==null || String(match[1]).indexOf(":")<0)return null;
            host=String(match[1]);if(match[2]!=null)selected=match[2];
         } else if(host.indexOf(":")>=0 && host.indexOf(":")==host.lastIndexOf(":")) {
            match=/^([^:]+):(\d{1,5})$/.exec(host);if(match==null)return null;
            host=String(match[1]);selected=match[2];
         }
         // DNS is resolved by Socket.connect; do not rewrite hostnames to IPs.
         if(host.indexOf(":")>=0) {if(!/^[0-9a-fA-F:.]+$/.test(host))return null;}
         else if(!/^[a-zA-Z0-9](?:[a-zA-Z0-9._-]*[a-zA-Z0-9.])?$/.test(host))return null;
         var n:int=port(selected);return n==0?null:{host:host,port:n};
      }
   }
}
