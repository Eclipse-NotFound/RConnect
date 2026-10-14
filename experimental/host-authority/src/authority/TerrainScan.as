package authority {
   /** Fixed schema, direct property reads; every tile and field is still examined. */
   public final class TerrainScan {
      public static function capture(value:Object,before:Array):Array {
         if(before!=null && value.phis===before[0] &&
            value.shelf===before[1] &&
            value.hp===before[2] &&
            value.thre===before[3] &&
            value.zForm===before[4] &&
            value.diagon===before[5] &&
            value.stair===before[6] &&
            value.water===before[7] &&
            value.fake===before[8] &&
            value.vid===before[9] &&
            value.vid2===before[10] &&
            value.front===before[11] &&
            value.back===before[12] &&
            value.zad===before[13] &&
            value.fRear===before[14] &&
            value.vRear===before[15] &&
            value.v2Rear===before[16] &&
            value.opac===before[17] &&
            value.mat===before[18] &&
            value.grav===before[19] &&
            value.lurk===before[20] &&
            value.kontur===before[21] &&
            value.konturRot===before[22] &&
            value.floor===before[23] &&
            value.place===before[24] &&
            value.kont1===before[25] &&
            value.kont2===before[26] &&
            value.kont3===before[27] &&
            value.kont4===before[28] &&
            value.pont1===before[29] &&
            value.pont2===before[30] &&
            value.pont3===before[31] &&
            value.pont4===before[32] &&
            value.indestruct===before[33])return before;
         return [value.phis,value.shelf,value.hp,value.thre,value.zForm,value.diagon,value.stair,value.water,value.fake,value.vid,value.vid2,value.front,value.back,value.zad,value.fRear,value.vRear,value.v2Rear,value.opac,value.mat,value.grav,value.lurk,value.kontur,value.konturRot,value.floor,value.place,value.kont1,value.kont2,value.kont3,value.kont4,value.pont1,value.pont2,value.pont3,value.pont4,value.indestruct];
      }
   }
}
