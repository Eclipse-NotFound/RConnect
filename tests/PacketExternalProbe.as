package {
   import flash.utils.IDataInput;
   import flash.utils.IDataOutput;
   import flash.utils.IExternalizable;
   public class PacketExternalProbe implements IExternalizable {
      public static var executed:int=0;
      public function PacketExternalProbe(){executed++;}
      public function writeExternal(out:IDataOutput):void {out.writeInt(7);}
      public function readExternal(input:IDataInput):void {executed++;input.readInt();}
   }
}
