package fe.inter {
    import flash.display.MovieClip;
    import flash.display.DisplayObject;
    import flash.utils.getQualifiedClassName;
    /** Read the real inventory selection, never its hover-only assId. */
    public class FAMenuBridge {
        public static function isWeapons(page:PipPage):Boolean {
            return page && getQualifiedClassName(page)=="fe.inter::PipPageInv" && page.page2==1 && page.vis.visible;
        }
        public static function view(page:PipPage):MovieClip { return page.vis; }
        public static function rows(page:PipPage):Array { return page.statArr.concat(); }
        public static function clickedId(page:PipPage,target:DisplayObject):String {
            while(target&&target.parent!==page.vis)target=target.parent;
            return target&&page.statArr.indexOf(target)>=0&&target.visible ? String(MovieClip(target).id.text) : "";
        }
        public static function selectedId(page:PipPage):String {
            if(!isWeapons(page))return "";
            var row:MovieClip=page.selItem;
            // Native list rows are recycled when scrolling. A stale selItem is not a selection.
            return row && row.parent==page.vis && row.visible && row.ramka.visible ? String(row.id.text) : "";
        }
        public static function refresh(page:PipPage):void { page.setStatus(false); }
    }
}
