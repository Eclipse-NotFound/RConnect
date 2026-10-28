package {
 import flash.display.Loader;
 import flash.display.Sprite;
 import flash.events.Event;
 import flash.events.TimerEvent;
 import flash.media.SoundMixer;
 import flash.media.SoundTransform;
 import flash.net.URLRequest;
 import flash.system.ApplicationDomain;
 import flash.system.LoaderContext;
 import flash.utils.Timer;
 /** Isolated harness only; production bytes are never recompiled into this SWF. */
 public class RConnectMod extends Sprite {
  private static var production:Loader,driver:Loader,mute:Timer;
  public static function init(main:Object):void {
   SoundMixer.soundTransform=new SoundTransform(0);
   mute=new Timer(250);
   mute.addEventListener(TimerEvent.TIMER,function(e:TimerEvent):void {
    if(SoundMixer.soundTransform.volume!=0)SoundMixer.soundTransform=new SoundTransform(0);
   });mute.start();
   production=new Loader();
   production.contentLoaderInfo.addEventListener(Event.COMPLETE,function(e:Event):void {
    var domain:ApplicationDomain=production.contentLoaderInfo.applicationDomain;
    domain.getDefinition("RConnectMod").init(main);
    driver=new Loader();
    driver.load(new URLRequest("app:/tests/EffectsDriver.swf"),new LoaderContext(false,new ApplicationDomain(domain)));
   });
   production.load(new URLRequest("app:/tests/RConnectProduction.swf"),new LoaderContext(false,new ApplicationDomain(main.loaderInfo.applicationDomain)));
  }
 }
}
