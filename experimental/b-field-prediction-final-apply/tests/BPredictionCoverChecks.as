package {
   import flash.system.ApplicationDomain;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
   import flash.display.Bitmap;
   import flash.display.BitmapData;
   import flash.utils.getQualifiedClassName;
   /** Root calls this in a functional probe, not a performance sample. The
    * native check compares every descendant, including hidden children. */
   public final class BPredictionCoverChecks {
      private static function copy(value:Object):Object{return JSON.parse(JSON.stringify(value));}
      private static function same(a:*,b:*):Boolean {
         if(a===b)return true;
         if(a==null||b==null||typeof a!='object'||typeof b!='object'||(a is Array)!=(b is Array))return false;
         if(a is Array&&a.length!=b.length)return false;
         for(var key:String in a)if(!b.hasOwnProperty(key)||!same(a[key],b[key]))return false;
         for(key in b)if(!a.hasOwnProperty(key))return false;return true;
      }
      public static function run(domain:ApplicationDomain,check:Function):void {
         var C:Object=domain.getDefinition('authority.PredictionPoseCover');
         var leaf:Object={x:0,y:0,f:1,a:1,v:true,c:[1,1,1,1,0,0,0,0],filters:[],children:[]};
         var a:Object={x:0,y:0,f:1,a:1,v:true,children:[{n:'body',i:0,cls:'MovieClip',s:copy(leaf)}]};
         var b:Object=copy(a);b.x=40;b.children[0].s.f=3;b.children[0].s.x=4;
         var previous:String=JSON.stringify(a),next:String=JSON.stringify(b);
         check(C.covers(a,b),'prediction_cover_same_topology_changed_motion_and_frame');
         var count:uint=C.checks,hits:uint=C.hits;
         check(C.covers(a,b)&&C.checks==count&&C.hits>hits,'prediction_cover_reuses_original_pair');
         check(JSON.stringify(a)===previous&&JSON.stringify(b)===next,'prediction_cover_keeps_recipes_immutable');
         var hidden:Object=copy(b);delete hidden.children[0].s.children;hidden.children[0].s.v=false;
         check(!C.covers(a,hidden),'prediction_cover_rejects_hidden_subtree_residue');
         var vector:Object=copy(a);vector.children[0].s.vector={commands:[1],data:[2,3]};
         check(!C.covers(vector,b),'prediction_cover_rejects_vector_residue');
         var pixel:Object=copy(a);pixel.children[0].s.pixels={width:1,height:1};
         check(!C.covers(pixel,b),'prediction_cover_rejects_pixel_residue');
         var text:Object=copy(a);text.children[0].s.text='old';
         check(!C.covers(text,b),'prediction_cover_rejects_text_residue');
         var scroll:Object=copy(text),partial:Object=copy(text);scroll.children[0].s.scrollH=3;
         check(!C.covers(scroll,partial),'prediction_cover_rejects_text_scroll_residue');
         var dropped:Object=copy(b);dropped.children=[];
         check(!C.covers(a,dropped),'prediction_cover_rejects_authored_limb_removal');
         var renamed:Object=copy(b);renamed.children[0].n='another';
         check(!C.covers(a,renamed),'prediction_cover_rejects_ambiguous_child_identity');
         check(C.covers(a,copy(b)),'prediction_cover_accepts_new_safe_pair');
         count=C.checks;
         check(!C.covers(a,hidden)&&C.checks==count,'prediction_cover_reuses_negative_pair');
      }
      private static function compareTree(P:Object,a:DisplayObject,b:DisplayObject):Boolean {
         if(a==null||b==null)return a===b;
         if(getQualifiedClassName(a)!==getQualifiedClassName(b)||!same(P.captureRoot(a),P.captureRoot(b)))return false;
         if((a.mask==null)!=(b.mask==null))return false;
         if(a is Bitmap){
            var ap:BitmapData=Bitmap(a).bitmapData,bp:BitmapData=Bitmap(b).bitmapData;
            if((ap==null)!=(bp==null))return false;
            if(ap!=null&&ap!==bp){var delta:Object=ap.compare(bp);if(delta is BitmapData){BitmapData(delta).dispose();return false;}if(delta!==0)return false;}
         }
         var ac:DisplayObjectContainer=a as DisplayObjectContainer,bc:DisplayObjectContainer=b as DisplayObjectContainer;
         if((ac==null)!=(bc==null))return false;
         if(ac!=null){if(ac.numChildren!=bc.numChildren)return false;for(var i:int=0;i<ac.numChildren;i++)if(!compareTree(P,ac.getChildAt(i),bc.getChildAt(i)))return false;}
         return true;
      }
      private static function nativePair(mod:Object,C:Object,P:Object,kind:String,older:Object,newer:Object,type:String,check:Function):Object {
         var accepted:Boolean=C.covers(older,newer),equal:Boolean=false;
         if(!accepted)return {kind:kind,covered:false,equal:null};
         var Type:Class=mod.access.visualClass(type),a:DisplayObject=new Type(),b:DisplayObject=new Type();
         try {
            P.apply(a,older);P.apply(a,newer);P.apply(b,newer);
            equal=compareTree(P,a,b);check(equal,'prediction_native_'+kind+'_older_then_newer_equals_newer_including_hidden');
         } finally {P.dispose(a);P.dispose(b);}
         return {kind:kind,covered:true,equal:equal};
      }
      /** Requires an established join. These are actual current/newest player
       * recipes and native body/weapon classes, not synthetic-only hit counts. */
      public static function nativeCurrent(mod:Object,domain:ApplicationDomain,check:Function):Object {
         if(mod.replica==null||mod.replica.clock.current==null||mod.replica.lastFrame==null)throw new Error('Prediction check requires confirmed join');
         var C:Object=domain.getDefinition('authority.PredictionPoseCover'),P:Object=domain.getDefinition('authority.VisualPose');
         var old:Object=mod.replica.clock.current.players[1],latest:Object=mod.replica.lastFrame.players[1];
         var out:Object={tick:mod.replica.lastTick,hasMotion:latest.motion!=null,body:null,weapon:null,
            candidates:mod.replica.localInterpolationCandidates,deferred:mod.replica.deferredLocalInterpolations,
            skipped:mod.replica.skippedLocalInterpolations,coverageRejected:mod.replica.localPoseCoverageRejected,
            proofChecks:C.checks,proofHits:C.hits,proofFailures:copy(C.failures)};
         out.body=nativePair(mod,C,P,'body',old.visual,latest.visual,getQualifiedClassName(mod.access.world.gg.vis),check);
         if(old.weapon!=null&&latest.weapon!=null&&old.weapon.id===latest.weapon.id&&old.weaponEpoch===latest.weaponEpoch&&mod.replica.weaponDisplay(1)!=null)
            out.weapon=nativePair(mod,C,P,'weapon',old.weapon.visual,latest.weapon.visual,getQualifiedClassName(mod.replica.weaponDisplay(1)),check);
         return out;
      }
   }
}
