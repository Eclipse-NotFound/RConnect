package lad { public class LadLampCatalog {
        private static const TYPES:Object={
            light1:{radius:300,color:0xffe4b3},stlight1:{radius:310,color:0xfff0cc},
            light2:{radius:370,color:0xffefd4},light3:{radius:340,color:0xffe6c0},
            stlight3:{radius:350,color:0xe0efff},light4:{radius:390,color:0xffe1a1},
            stlight4:{radius:390,color:0xd5e8ff},light5:{radius:190,color:0xff5a3f},
            light6:{radius:320,color:0xffedc4},light7:{radius:360,color:0xd0e7ff}
        };
        public static function isLamp(id:String):Boolean {return TYPES.hasOwnProperty(id);}
}}
