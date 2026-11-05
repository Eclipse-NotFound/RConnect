import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.abc.*;
import com.jpexs.decompiler.flash.abc.types.*;
import com.jpexs.decompiler.flash.abc.types.traits.*;
import com.jpexs.decompiler.flash.abc.avm2.parser.pcode.ASM3Parser;
import com.jpexs.decompiler.flash.abc.avm2.parser.pcode.MissingSymbolHandler;
import com.jpexs.decompiler.flash.helpers.*;
import com.jpexs.decompiler.flash.configuration.Configuration;
import com.jpexs.decompiler.flash.exporters.modes.ScriptExportMode;
import com.jpexs.decompiler.flash.tags.*;
import java.io.*;import java.nio.file.*;import java.util.*;
public class MethodPatch {
 static SWF load(String f)throws Exception{return new SWF(new FileInputStream(f),false);}
 static ABC abc(SWF s,String cls){for(ABCContainerTag t:s.getAbcList())if(t.getABC().findClassByName(cls)>=0)return t.getABC();throw new IllegalArgumentException(cls);}
 static String asm(ABC a,MethodBody b)throws Exception{HighlightedTextWriter w=new HighlightedTextWriter(Configuration.getCodeFormatting(),false);b.getCode().toASMSource(a,a.constants,a.method_info.get(b.method_info),b,ScriptExportMode.PCODE,w);return w.toString();}
 static TraitMethodGetterSetter trait(ABC a,String cls,String name){int ci=a.findClassByName(cls);for(Trait t:a.instance_info.get(ci).instance_traits.traits)if(t instanceof TraitMethodGetterSetter&&a.constants.getString(t.getName(a).name_index).equals(name))return (TraitMethodGetterSetter)t;throw new IllegalArgumentException(cls+":"+name);}
 static int method(ABC a,String cls,String name){return name.equals("$init")?a.instance_info.get(a.findClassByName(cls)).iinit_index:trait(a,cls,name).method_info;}
 static Map<String,String> namespaces(ABC target,ABC donor){Map<String,String> m=new LinkedHashMap<>();for(int i=0;i<target.instance_info.size();i++){String cn=target.instance_info.get(i).getName(target.constants).getNameWithNamespace(new HashSet<>(),target,target.constants,true).toRawString();int j=donor.findClassByName(cn);if(j<0)continue;List<Trait> ts=new ArrayList<>(target.instance_info.get(i).instance_traits.traits);ts.addAll(target.class_info.get(i).static_traits.traits);List<Trait> ds=new ArrayList<>(donor.instance_info.get(j).instance_traits.traits);ds.addAll(donor.class_info.get(j).static_traits.traits);for(Trait x:ts)for(Trait y:ds)if(x.getClass()==y.getClass()&&target.constants.getString(x.getName(target).name_index).equals(donor.constants.getString(y.getName(donor).name_index))){String src=Multiname.namespaceToString(donor.constants,y.getName(donor).namespace_index),dst=Multiname.namespaceToString(target.constants,x.getName(target).namespace_index);if(!src.equals(dst)){String old=m.put(src,dst);if(old!=null&&!old.equals(dst))throw new IllegalStateException("Ambiguous namespace "+src);}}}return m;}
 public static void main(String[] v)throws Exception{
  if(v.length==3){SWF s=load(v[0]);ABC a=abc(s,v[1]);System.out.println(asm(a,a.findBody(method(a,v[1],v[2]))));return;}
  Path input=Paths.get(v[0]).toRealPath(),output=Paths.get(v[2]).toAbsolutePath().normalize();if(input.equals(output)||!output.startsWith(Paths.get(System.getProperty("rconnect.pi.outputRoot", "__unset__")).toRealPath()))throw new IllegalArgumentException("Only own candidate output allowed");
  String inputHash=HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(input)));
  if(!inputHash.equals("eced04ad8dae6b74444ee6e5f5ec5ddf2e83528a9eecfef66f58985cb0c83063"))throw new IllegalArgumentException("Expected exact B native021");
  SWF target=load(v[0]),donor=load(v[1]);Map<MethodBody,byte[]> untouched=new IdentityHashMap<>();for(ABCContainerTag t:target.getAbcList())for(MethodBody b:t.getABC().bodies)untouched.put(b,b.getCodeBytes().clone());
  ABC pa=abc(target,"fe.unit.Pers");for(String n:Arrays.asList("piEvent","piFactor")){try{trait(pa,"fe.unit.Pers",n);throw new IllegalArgumentException("Already patched");}catch(IllegalArgumentException e){if(e.getMessage().equals("Already patched"))throw e;}pa.addMethod(pa.findClassByName("fe.unit.Pers"),n,false);}
  ABC ba=abc(target,"fe.weapon.Bullet");TraitSlotConst slot=new TraitSlotConst();slot.kindType=Trait.TRAIT_SLOT;slot.name_index=ba.constants.getPublicQnameId("piShot",true);slot.type_index=ba.constants.getPublicQnameId("Number",true);slot.value_kind=ValueKind.CONSTANT_Double;slot.value_index=ba.constants.getDoubleId(0,true);ba.instance_info.get(ba.findClassByName("fe.weapon.Bullet")).instance_traits.addTrait(slot);((Tag)ba.parentTag).setModified(true);
  int count=0;for(String line:Files.readAllLines(Paths.get(v[3]))){if(line.isBlank())continue;String[] p=line.split("\t");ABC a=abc(target,p[0]),d=abc(donor,p[0]);int mi=method(a,p[0],p[1]);MethodBody b=a.findBody(mi);if(b==null){b=new MethodBody();b.method_info=mi;b.setAbc(a);a.addMethodBody(b);}untouched.remove(b);String code=asm(d,d.findBody(method(d,p[0],p[1])));for(Map.Entry<String,String> ns:namespaces(a,d).entrySet())code=code.replace(ns.getKey(),ns.getValue());
   if(java.util.regex.Pattern.compile("(?m)^\\s*(newfunction|callstatic|newclass)\\s").matcher(code).find())throw new IllegalStateException("Indexed reference requires explicit mapping: "+line);
   Files.writeString(Paths.get(v[2]).getParent().resolve(p[0]+"."+p[1]+".pcode"),code);
   b.setCode(ASM3Parser.parse(a,new StringReader(code),p[1].equals("$init")?null:trait(a,p[0],p[1]),new MissingSymbolHandler(){public boolean missingString(String s){return true;}public boolean missingInt(long n){return true;}public boolean missingUInt(long n){return true;}public boolean missingDouble(double n){return true;}public boolean missingFloat(float n){return true;}public boolean missingFloat4(Float4 n){return true;}public boolean missingDecimal(macromedia.asc.util.Decimal128 n){return true;}},b,a.method_info.get(mi)));b.setModified();((Tag)a.parentTag).setModified(true);System.out.println("Patched "+line);count++;
  }
  for(Map.Entry<MethodBody,byte[]> e:untouched.entrySet())if(!Arrays.equals(e.getValue(),e.getKey().getCodeBytes()))throw new IllegalStateException("Unrelated body changed");
  try(OutputStream out=Files.newOutputStream(output)){target.saveTo(out);}
  SWF readback=load(output.toString());int verified=0;for(int ai=0;ai<target.getAbcList().size();ai++){ABC a=target.getAbcList().get(ai).getABC(),r=readback.getAbcList().get(ai).getABC();for(MethodBody b:a.bodies){MethodBody rb=r.findBody(b.method_info);if(rb==null||!Arrays.equals(b.getCodeBytes(),rb.getCodeBytes())||b.max_stack!=rb.max_stack||b.max_regs!=rb.max_regs||b.init_scope_depth!=rb.init_scope_depth||b.max_scope_depth!=rb.max_scope_depth||b.exceptions.length!=rb.exceptions.length)throw new IllegalStateException("Saved method differs "+ai+":"+b.method_info);if(untouched.containsKey(b))verified++;}}
  String baseHash=HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(input))),outHash=HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(output)));
  Files.writeString(output.getParent().resolve("verification.json"),"{\"baseline\":\""+baseHash+"\",\"candidate\":\""+outHash+"\",\"untouchedBodies\":"+verified+",\"transplantedMethods\":"+count+",\"readback\":true}");
  System.out.println("Verified "+verified+" untouched method bodies and saved readback; transplanted "+count);
 }
}
