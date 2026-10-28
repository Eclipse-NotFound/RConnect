package modlocales.connect
{
   import flash.events.TimerEvent;
   import flash.text.TextField;
   import flash.text.TextFormat;
   import flash.utils.Dictionary;
   import flash.utils.Timer;
   import flash.utils.getDefinitionByName;

   /** Local, embedded UI catalog. IDs, saves, protocol and player text stay untouched. */
   public class RCLocale
   {
      private static var messages:Object;
      private static var fragments:RegExp;
      private static var fields:Dictionary = new Dictionary(true);
      private static var fitted:Dictionary = new Dictionary(true);
      private static var watcher:Timer;
      private static var observed:String = "";

      public static function language():String
      {
         var code:String = "zh";
         try { code = String(getDefinitionByName("fe.World")["w"]["lang"]); } catch(e:*) {}
         return normalize(code);
      }
      private static function normalize(code:String):String
      {
         code = code == null ? "en" : code.toLowerCase().replace(/_/g,"-");
         if(code == "tw" || code == "zh-tw" || code == "zh-hk" || code.indexOf("zh-hant") == 0) return "tw";
         if(code.indexOf("zh") == 0) return "zh";
         var base:String=code.split("-")[0];
         if(base == "uk") return "ua";
         if(base == "ja") return "jp";
         return ["en","ru","ua","pl","de","es","jp"].indexOf(base)>=0?base:"en";
      }
      private static function load():void
      {
         if(messages != null) return;
         messages = RCLocaleMessages.DATA;
         var keys:Array = [];
         for(var key:String in messages) keys.push(key);
         keys.sort(function(a:String,b:String):Number { return b.length-a.length; });
         for(var i:int=0;i<keys.length;i++) keys[i] = String(keys[i]).replace(/[.*+?^${}()|\[\]\\]/g,"\\$&");
         fragments = new RegExp(keys.join("|"),"g");
      }
      public static function text(source:String):String { return translate(source,language()); }
      public static function translate(source:String,code:String):String
      {
         if(source == null) return "";
         load(); code=normalize(code);
         var row:Object=messages[source];
         return row == null ? source : row[code] != null ? String(row[code]) : row.en != null ? String(row.en) : source;
      }
      /** Only for UI assembled from developer-owned fragments, never chat/profile names. */
      public static function render(source:String):String { return renderLanguage(source,language()); }
      public static function renderLanguage(source:String,code:String):String
      {
         if(source == null) return "";
         load(); code=normalize(code);
         if(messages[source] != null) return translate(source,code);
         return source.replace(fragments,function(...args):String {
            var row:Object=messages[String(args[0])];
            return row != null && row[code] != null ? String(row[code]) : String(args[0]);
         });
      }
      public static function format(source:String,...values):String
      {
         var result:String=text(source);
         // One pass prevents player-authored braces in a value from becoming placeholders.
         return result.replace(/\{(\d+)\}/g,function(...args):String {
            var index:int=int(args[1]); return index<values.length?String(values[index]):String(args[0]);
         });
      }
      /** Fit fixed controls only. Unchanged text costs no font/layout mutation. */
      public static function fit(field:TextField,width:Number=NaN,height:Number=NaN):void
      {
         if(field == null || field.styleSheet != null)return;
         width=isNaN(width)?field.width:width;height=isNaN(height)?field.height:height;
         var signature:String=field.text+"\u0000"+width+"/"+height;
         var cached:Object=fitted[field];
         if(cached!=null && cached.signature===signature)return;
         var style:TextFormat=field.defaultTextFormat;
         var baseSize:Number=cached==null?Number(style.size):cached.baseSize;
         style.size=baseSize;
         field.setTextFormat(style);
         var size:Number=Number(style.size);
         while(size>10 && (field.textWidth>width-4 || field.textHeight>height-4))
         {size-=0.5;style.size=size;field.setTextFormat(style);}
         // Reassigning text uses this format, so unchanged labels need no
         // further text measurement or format operations on later ticks.
         field.defaultTextFormat=style;
         fitted[field]={signature:signature,baseSize:baseSize};
      }
      /** Weak binding refreshes persistent labels after the native language menu changes. */
      public static function bind(field:TextField,source:String,fit:Boolean=false):void
      {
         if(field == null) return;
         var entry:Object=fields[field];
         if(entry == null)
         {
            var style:TextFormat=field.defaultTextFormat;
            entry={source:null,code:"",font:style.font,size:style.size,embed:field.embedFonts,fit:fit};
            fields[field]=entry;
         }
         var code:String=language();
         if(entry.source !== source || entry.code != code || entry.fit != fit)
         { entry.source=source;entry.fit=fit;paint(field,entry,code); }
         if(watcher == null)
         {
            observed=code;watcher=new Timer(200);
            watcher.addEventListener(TimerEvent.TIMER,refresh);watcher.start();
         }
      }
      private static function refresh(e:TimerEvent):void
      {
         var code:String=language();if(code == observed)return;observed=code;
         for(var field:Object in fields)paint(field as TextField,fields[field],code);
      }
      private static function paint(field:TextField,entry:Object,code:String):void
      {
         entry.code=code;
         var style:TextFormat=field.defaultTextFormat;
         style.font=code == "zh"?entry.font:"_sans";style.size=entry.size;
         field.embedFonts=code == "zh"?entry.embed:false;
         if(field.styleSheet == null)field.defaultTextFormat=style;
         field.text=renderLanguage(entry.source,code);
         if(field.styleSheet == null)field.setTextFormat(style);
         if(entry.fit && field.autoSize == "none" && field.styleSheet == null)
         {
            var size:Number=Number(style.size);
            while(size>10 && (field.textWidth>field.width-4 || field.textHeight>field.height-4))
            { size-=0.5;style.size=size;field.setTextFormat(style); }
         }
      }
   }
}
