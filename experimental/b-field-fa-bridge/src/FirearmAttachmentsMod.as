package {
    import fa.Runtime;
    import fa.AuthorityAPI;
    public class FirearmAttachmentsMod {
        public static const VERSION:String="0.3.5-b1";
        public static var instance:Runtime;
        public static function init(main:*):void { if(!instance){instance=new Runtime(main);main.addChild(new AuthorityAPI(instance));} }
    }
}
