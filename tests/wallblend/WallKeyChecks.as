package {
    import flash.display.Sprite;
    import flash.desktop.NativeApplication;
    import flash.utils.getTimer;
    import flash.utils.setTimeout;
    import wallblend.BackgroundBlendLayer;
    import wallblend.BlendLayer;
    import wallblend.BaselineBackgroundBlendLayer;
    import wallblend.BaselineBlendLayer;

    public class WallKeyChecks extends Sprite {
        private var background:BackgroundBlendLayer=new BackgroundBlendLayer();
        private var foreground:BlendLayer=new BlendLayer();
        private var oldBack:BaselineBackgroundBlendLayer=new BaselineBackgroundBlendLayer();
        private var oldFront:BaselineBlendLayer=new BaselineBlendLayer();
        private var comparisons:int=0;
        private var randomState:uint=719355926;
        public function WallKeyChecks() {setTimeout(run,25);}
        private function check(ok:Boolean,name:String):void {
            if(!ok)throw new Error(name);
            trace("PASS "+name);
        }
        private function random(n:int):int {
            randomState^=randomState<<13;randomState^=randomState>>>17;randomState^=randomState<<5;
            return int(randomState%n);
        }
        private function tile():Object {
            return {back:"c",front:"A",phis:1,zForm:"",fRear:false,diagon:false,stair:false,
                shelf:false,door:false,fake:false,vid:false,vid2:false};
        }
        private function location(w:int=16,h:int=12):Object {
            var loc:Object={homeStable:false,darkness:0.5,lightOn:true,backwall:"A",transpFon:false,
                cTransform:null,spaceX:w,spaceY:h,space:[],backobjs:[]};
            for(var x:int=0;x<w;x++) {loc.space[x]=[];for(var y:int=0;y<h;y++)loc.space[x][y]=tile();}
            return loc;
        }
        private function equal(loc:Object,style:String="material",width:int=3):void {
            var a:String=oldBack.stateKey(loc),b:String=background.stateKey(loc);
            if(a!==b)throw new Error("background key #"+comparisons+" "+a+" != "+b);
            a=oldFront.gridKey(loc,width,style);b=foreground.gridKey(loc,width,style);
            if(a!==b)throw new Error("foreground key #"+comparisons+" "+a+" != "+b);
            comparisons+=2;
        }
        private function backEqual(loc:Object):void {
            if(oldBack.stateKey(loc)!==background.stateKey(loc))throw new Error("background primitive #"+comparisons);
            comparisons++;
        }
        private function run():void {
            try {
                var loc:Object=location(),i:int,j:int,f:String,v:*,t:Object;
                equal(loc);for(i=0;i<80;i++)equal(loc);
                check(true,"unchanged grid repeated exact old keys");
                var fields:Array=["phis","fRear","diagon","stair","shelf","door","fake","vid","vid2","zForm","front"];
                var values:Array=[null,undefined,NaN,false,true,0,1,2,"","A","B","-","|",":","AB"];
                for each(f in fields) for each(v in values) {
                    loc.space[5][4]=t=tile();t[f]=v;
                    // Native front is a string. Non-string front conversion is
                    // tested on the background path below, and failures below.
                    if(f=="front" && !(v is String))continue;
                    equal(loc,"material");equal(loc,"readable");equal(loc,"materialWeathered");
                }
                check(true,"all foreground eligibility fields and styles");
                for each(f in ["back","front","phis","zForm"]) for each(v in values) {
                    loc.space[5][4]=t=tile();t[f]=v;backEqual(loc);backEqual(loc);
                }
                check(true,"background null undefined NaN booleans numbers and separator strings");
                loc=location();
                for each(f in ["homeStable","darkness","lightOn","backwall","transpFon"]) for each(v in values) {
                    loc[f]=v;equal(loc);equal(loc);
                }
                check(true,"header Array.join semantics incl null undefined and NaN");
                loc=location();var text:MutableText=new MutableText("first");
                loc.cTransform=text;equal(loc);text.value="next";equal(loc);
                var bo:Object={id:"pipe",X:0,Y:20,scX:1,scY:1,frame:0,sloy:0,alpha:1,er:false};
                loc.backobjs.push(bo);equal(loc);
                for each(f in ["id","X","Y","scX","scY","frame","sloy","alpha","er"]) for each(v in values) {
                    bo[f]=v;equal(loc);
                }
                loc.backobjs.push({id:"second",X:10,Y:30,scX:-1,scY:1,frame:3,sloy:1,alpha:.2,er:false});equal(loc);
                loc.backobjs.reverse();equal(loc);loc.backobjs.shift();equal(loc);
                check(true,"mutable color transform and each placed-art field and order");
                loc=location();text=new MutableText("A");loc.space[2][2].back=text;loc.space[2][2].front=text;
                equal(loc);text.value="B";equal(loc);text.value="A";equal(loc);
                check(true,"unknown mutable field values preserve per-scan conversion");
                for each(v in [[0,0],[1,0],[0,1],[1,1],[22,11],[11,22],[4,3],[16,12]]) {
                    loc=location(v[0],v[1]);equal(loc);equal(loc);
                }
                check(true,"dimension changes growth shrink empty and same-area reshape");
                loc=location();
                for(i=0;i<1500;i++) {
                    var x:int=random(loc.spaceX),y:int=random(loc.spaceY);
                    t=loc.space[x][y];
                    switch(random(10)) {
                        case 0:t.back=values[random(values.length)];break;
                        case 1:t.front=["A","B","","AB","-","|",":"][random(7)];break;
                        case 2:t.zForm=["","R","L",0,1,NaN][random(6)];break;
                        case 3:t.phis=random(3);break;
                        case 4:t.fake=!t.fake;break;
                        case 5:t.fRear=!t.fRear;break;
                        case 6:t.vid=!t.vid;break;
                        case 7:t.door=!t.door;break;
                        case 8:t.shelf=!t.shelf;break;
                        case 9:loc.darkness=Number(random(10))/10;break;
                    }
                    equal(loc,["material","materialWeathered","readable"][random(3)],random(6));
                }
                check(true,"1500 deterministic mutations match exact baseline strings");
                background.invalidate();foreground.invalidate();
                check(!background.comparisonValid&&!foreground.comparisonValid,"invalidate drops key cache");equal(loc);
                background.dispose();foreground.dispose();
                check(!background.comparisonValid&&!foreground.comparisonValid,"dispose drops key cache");equal(loc);
                check(background.comparisonValid&&foreground.comparisonValid,"re-entry after dispose restores complete scan");
                loc=location();equal(loc);loc.space[15][11]=null;
                var threw:Boolean=false;try{background.stateKey(loc);}catch(e:Error){threw=true;}
                check(threw&&!background.comparisonValid,"late failed read cannot commit partial background cache");
                loc.space[15][11]=tile();equal(loc);
                loc.space[15][11].front=null;threw=false;try{foreground.gridKey(loc,3,"material");}catch(e2:Error){threw=true;}
                check(threw&&!foreground.comparisonValid,"late failed eligibility cannot commit partial foreground cache");
                loc.space[15][11]=tile();equal(loc);
                text=new MutableText("A");loc.space[15][11].back=text;backEqual(loc);text.broken=true;
                threw=false;try{background.stateKey(loc);}catch(e3:Error){threw=true;}
                check(threw&&!background.comparisonValid,"failed mutable conversion cannot commit partial background cache");
                text.broken=false;text.value="B";equal(loc);
                check(true,"all exception recovery scans match baseline");
                benchmark();
                trace("COMPLETE exactComparisons="+comparisons);
                NativeApplication.nativeApplication.exit(0);
            } catch(error:Error) {
                trace("FAIL "+error.message+" "+error.getStackTrace());
                NativeApplication.nativeApplication.exit(1);
            }
        }
        private function benchmark():void {
            // Same live object, alternating order, no timer-based pass threshold.
            // Does not predict full-game FPS. Native image tests run separately.
            var loc:Object=location(60,35),round:int,k:int,start:int,ms:int,sink:String;
            equal(loc);var batches:Array=[];
            for(round=0;round<7;round++) {
                var row:Object={round:round};
                for(var phase:int=0;phase<4;phase++) {
                    var index:int=(round%2)?3-phase:phase;start=getTimer();
                    for(k=0;k<200;k++) {
                        if(index==0)sink=oldBack.stateKey(loc);
                        else if(index==1)sink=background.stateKey(loc);
                        else if(index==2)sink=oldFront.gridKey(loc,3,"material");
                        else sink=foreground.gridKey(loc,3,"material");
                    }
                    ms=getTimer()-start;row[["oldBack","newBack","oldFront","newFront"][index]]=ms;
                }
                batches.push(row);
            }
            trace("TIMING "+JSON.stringify({cells:2100,scans:200,rows:batches,sinkLength:sink.length}));
        }
    }
}
class MutableText {
    public var value:String;
    public var broken:Boolean=false;
    public var length:int=1;
    public function MutableText(s:String){value=s;}
    public function toString():String{if(broken)throw new Error("injected conversion failure");return value;}
}
