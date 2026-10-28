package fa {
    /** Drafts contain assembly only. Weapon values, ammunition and save data stay in Runtime. */
    public class AssemblySession {
        private var catalog:Catalog;
        public var originals:Object={}, drafts:Object={}, history:Object={};
        public function AssemblySession(c:Catalog) { catalog=c; }
        public function touch(id:String,s:Object):void {
            if(!drafts[id]) { originals[id]=Catalog.clone(s); drafts[id]=Catalog.clone(s); history[id]=[]; }
        }
        public function accept(id:String,result:Object):String {
            if(result.error)return result.error;
            var error:String=catalog.validate(id,result.state);
            if(error)return error;
            history[id].push(Catalog.clone(drafts[id]));
            if(history[id].length>30)history[id].shift();
            drafts[id]=Catalog.clone(result.state);return "";
        }
        public function restore(id:String):void {
            history[id].push(Catalog.clone(drafts[id]));drafts[id]=Catalog.clone(originals[id]);
        }
        public function undo(id:String):Boolean {
            if(!history[id].length)return false;drafts[id]=history[id].pop();return true;
        }
        public function commit(id:String,s:Object):void {
            originals[id]=Catalog.clone(s);drafts[id]=Catalog.clone(s);history[id]=[];
        }
        public static function signature(s:Object):String {
            var a:Array=s.items.concat().sort(),r:Array=[s.mode];
            for each(var f:String in Catalog.FACES)r.push(f,s.railStarts[f],s.rails[f]);
            for each(var p:String in a)r.push(p,s.positions[p]);
            return JSON.stringify(r);
        }
        public function changed(id:String):Boolean {return signature(originals[id])!=signature(drafts[id]);}
    }
}
