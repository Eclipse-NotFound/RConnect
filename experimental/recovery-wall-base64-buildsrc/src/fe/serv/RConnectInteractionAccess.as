package fe.serv {
public class RConnectInteractionAccess {
public static function capture(o:Object):Object {
var v:Interact=o as Interact;if(v==null)return null;
return {inited:v.inited,t_sign:v.t_sign,begX:v.begX,begY:v.begY,endX:v.endX,endY:v.endY,endX2:v.endX2,t_move:v.t_move,dt_move:v.dt_move,moveP:v.moveP,lootBroken:v.lootBroken,t_autoClose:v.t_autoClose,t_budilo:v.t_budilo,saveMine:v.saveMine,saveLock:v.saveLock,saveOpen:v.saveOpen,saveExpl:v.saveExpl};
}
public static function restore(o:Object,s:Object):void {
var v:Interact=o as Interact;if(v==null || s==null)return;
if(s.inited!==undefined)v.inited=Boolean(s.inited);
if(s.t_sign!==undefined)v.t_sign=int(s.t_sign);
if(s.begX!==undefined)v.begX=Number(s.begX);
if(s.begY!==undefined)v.begY=Number(s.begY);
if(s.endX!==undefined)v.endX=Number(s.endX);
if(s.endY!==undefined)v.endY=Number(s.endY);
if(s.endX2!==undefined)v.endX2=Number(s.endX2);
if(s.t_move!==undefined)v.t_move=Number(s.t_move);
if(s.dt_move!==undefined)v.dt_move=Number(s.dt_move);
if(s.moveP!==undefined)v.moveP=Boolean(s.moveP);
if(s.lootBroken!==undefined)v.lootBroken=Boolean(s.lootBroken);
if(s.t_autoClose!==undefined)v.t_autoClose=int(s.t_autoClose);
if(s.t_budilo!==undefined)v.t_budilo=int(s.t_budilo);
if(s.saveMine!==undefined)v.saveMine=int(s.saveMine);
if(s.saveLock!==undefined)v.saveLock=int(s.saveLock);
if(s.saveOpen!==undefined)v.saveOpen=int(s.saveOpen);
if(s.saveExpl!==undefined)v.saveExpl=int(s.saveExpl);
}
}}
