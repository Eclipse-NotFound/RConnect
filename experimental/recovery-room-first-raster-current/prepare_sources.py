"""Prepare six RC source overlays only. No compiler, game, or deployment."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = ROOT / "build/m52/recovery-room-production-05/src"
OLD = ROOT / "experimental/recovery-early-exit-authorization/src"
GATE = ROOT / "experimental/recovery-early-buildsrc/src/rconnect/core/EarlyTravelGate.as"
PINS = {
    "rconnect/core/RoomSync.as": "1c5ac8d9c761c40d0908a2c048062a7b09f604c6b9fa34272cae27e27c52a848",
    "rconnect/core/MapGeneration.as": "ba5ea9bf85933329759575ce19e8d5260f9218c1e0aacccd1fa956d1e045a3a6",
    "rconnect/core/Session.as": "14aac9a684133740b95a4bbE3cbcec9f03095965496c292b2d9ffeb54d9f453d".lower(),
    "rconnect/game/GameBridge.as": "f7016bfd096ca3c88ea1214733117758b1998b579ec6f3ca9fc9332b605011a9",
    "rconnect/game/WallImpactVisuals.as": "e1125fa1865598705c1753fd8e49ede037cd16936a680a7a078c4cf9b5ac5a34",
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def load(path):
    return path.read_bytes().decode("utf-8").replace("\r\n", "\n")


def replace(s, old, new, count=1):
    if s.count(old) != count:
        raise RuntimeError("Exact source match count differs: " + old[:100])
    return s.replace(old, new)


def method(s, name):
    found = re.search(r"^      (?:public|private) function " + re.escape(name) + r"\(", s, re.M)
    if found is None:
        raise RuntimeError("Method absent: " + name)
    start = found.start()
    pos = s.index("{", found.end())
    depth = 0
    # Selected old methods contain no unmatched brace text in strings/comments.
    for i in range(pos, len(s)):
        depth += (s[i] == "{") - (s[i] == "}")
        if depth == 0:
            return s[start:i+1] + "\n"
    raise RuntimeError("Unclosed method: " + name)


def produce():
    inputs = {}
    out = {}
    for rel, expected in PINS.items():
        data = (BASE / rel).read_bytes()
        if sha(data) != expected:
            raise RuntimeError("Baseline changed: " + rel)
        inputs[str(BASE / rel)] = expected
        out[rel] = data.decode("utf-8").replace("\r\n", "\n")
    old_room_path = OLD / "rconnect/core/RoomSync.as"
    old_room = load(old_room_path)
    if sha(old_room_path.read_bytes()) != "b2b6a3785cd60f9cb08fb48d52e3cce3a757d474dde35d4f0903d47fe7bac51e":
        raise RuntimeError("Early2 authorization source changed")
    old_map_path = OLD / "rconnect/core/MapGeneration.as"
    old_map = load(old_map_path)
    if sha(old_map_path.read_bytes()) != "b248567ae062d08ae66c7ff8ccff40553c86e978a916d048fbcfeab7ab8e9028":
        raise RuntimeError("Early2 external lease source changed")
    inputs[str(old_room_path)] = sha(old_room_path.read_bytes())
    inputs[str(old_map_path)] = sha(old_map_path.read_bytes())
    if sha(GATE.read_bytes()) != "544d61b428ca0e3b3daf603eb0a8c8546fc01a64d22834c73f7d90d323f6a814":
        raise RuntimeError("EarlyTravelGate changed")
    inputs[str(GATE)] = sha(GATE.read_bytes())
    out["rconnect/core/EarlyTravelGate.as"] = load(GATE)

    rel = "rconnect/game/WallImpactVisuals.as"
    out[rel] = replace(out[rel], 'return loc!=null && get(g,"loc")===loc?get(g,"frontBmp") as BitmapData:null;',
        'return loc!=null && get(g,"loc")===loc && get(g,"rconnectRasterPending")!==true?get(g,"frontBmp") as BitmapData:null;')

    rel = "rconnect/core/MapGeneration.as"
    s = out[rel]
    s = replace(s, "      public var supported:Boolean=false;", """      public var supported:Boolean=false;
      public var earlyTravelSupported:Boolean=false;
      private var earlyCarrier:Object,earlyWorld:Object,earlyGame:Object;
      private var earlyOwner:Object={},earlyLeaseId:String="";""")
    s = replace(s, "         session=s;", """         session=s;
         var nativeGame:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.loc.Game");
         var grafon:Object=s.mod.game.main.loaderInfo.applicationDomain.getDefinition("fe.graph.Grafon");
         // Both exact host contracts are required. Partial/old hosts retain
         // the current ordinary loading route; there is no API-only success.
         if("rconnectTravelBridge" in nativeGame && "rconnectEarlyTravelVersion" in nativeGame
            && int(nativeGame.rconnectEarlyTravelVersion)==1 && "rconnectRasterBridge" in grafon) {
            if(nativeGame.rconnectTravelBridge!=null || grafon.rconnectRasterBridge!=null)
               throw new Error("Native early travel hook already owned");
            nativeGame.rconnectTravelBridge=nativeTravel;
            grafon.rconnectRasterBridge=firstRaster;
            earlyTravelSupported=true;
         }""")
    callbacks = """      private function firstRaster(w:Object,l:Object,g:Object):Object {
         if(session.rooms==null || !session.rooms.earlyTravelPending)return null;
         return session.rooms.openFirstRaster(w,l,g);
      }
      private function nativeTravel(phase:String,g:Object,info:Object):Object {
         if(session.rooms==null)return null;
         if(phase=="loadingHold")return session.rooms.nativeLoadingHold(g);
         if(phase=="cancel-load"){session.rooms.cancelNativeLoading(g);return null;}
         if(phase=="constructed") {
            session.mod.game.refreshWorld();session.rooms.nativeConstructed(g);
         }
         return null;
      }
"""
    # The lease contract is copied verbatim from the fixed early2 source.
    callbacks += method(old_map, "acquireEarly") + method(old_map, "releaseEarly")
    s = replace(s, "      public function reset():void {\n         remote=null;", callbacks + "      public function reset():void {\n         if(earlyCarrier!=null)releaseEarly(earlyLeaseId);\n         remote=null;")
    out[rel] = s

    rel = "rconnect/core/Session.as"
    s = out[rel]
    s = replace(s, '      public var hostName:String = "";', '      public var hostName:String = "";\n      public var hostEarlyTravel:int=0;')
    s = replace(s, '         _nextWorldSnapshot=_nextSceneReport=0;', '         _nextWorldSnapshot=_nextSceneReport=0;\n         hostEarlyTravel=0;')
    s = replace(s, 'link.send(Protocol.make(Protocol.MSG_HELLO, {name: myName}));', 'link.send(Protocol.make(Protocol.MSG_HELLO, {name: myName,earlyTravel:mod.game.mapGeneration.earlyTravelSupported?1:0}));')
    s = replace(s, '               hostName = msg.name != undefined ? String(msg.name) : "";', '               hostName = msg.name != undefined ? String(msg.name) : "";\n               hostEarlyTravel=int(msg.earlyTravel);')
    s = replace(s, 'peers.push({id: link.id, name: link.peerName, link: link, snap: null});', 'peers.push({id: link.id, name: link.peerName, link: link, snap: null,earlyTravel:int(msg.earlyTravel)});')
    s = replace(s, '{id: link.id, name: myName, worldInfo: wInfo}));', '{id: link.id, name: myName, worldInfo: wInfo,earlyTravel:mod.game.mapGeneration.earlyTravelSupported?1:0}));')
    out[rel] = s

    rel = "rconnect/game/GameBridge.as"
    s = out[rel]
    s = replace(s, '      public function tileRedrawIfDirty():void', """      /** Replay saved wall pixels only after the exact restored first raster. */
      public function finishFirstRaster():void
      {
         if(probe(probe(loc,"grafon"),"rconnectRasterPending")===true)
            throw new Error("First raster still unpainted");
         _wall.redraw(loc);_satsRasterDirty=true;
      }

      public function tileRedrawIfDirty():void""")
    s = replace(s, '         if(!retained && !_terrain.dirty && (s.wallPaint==null || s.wallPaint.length==0)', '         if(!retained && probe(probe(loc,"grafon"),"rconnectRasterPending")!==true\n            && !_terrain.dirty && (s.wallPaint==null || s.wallPaint.length==0)')
    out[rel] = s

    rel = "rconnect/core/RoomSync.as"
    s = out[rel]
    s = replace(s, '      private var preparedToken:String="";', """      private var preparedToken:String="";
      private var early:EarlyTravelGate=new EarlyTravelGate();
      // A nonce must not consume the game's Math.random stream.
      private var earlyNonce:String=getTimer().toString(16)+"-"+new Date().time.toString(16);
      private var earlySerial:int=0,earlySeal:Object;
      private var earlyControlHeld:Boolean=false,earlyViewFinished:Boolean=false;
      private var nativeFrame:int=0,earlyDeadline:int=0;""")
    s = replace(s, '      public function reset():void\n      {', '      public function reset():void\n      {\n         cancelEarly(false,true,true);')
    names = ["earlySupported", "offerEarly", "armEarly", "nativeConstructed", "nativeLoadingHold", "cancelNativeLoading", "checkEarly", "finishEarly", "completeEarly", "cancelEarly"]
    methods = "      public function get earlyTravelPending():Boolean{return early.active;}\n"
    for name in names:
        value = method(old_room, name)
        if name == "offerEarly":
            value = replace(value, 'if(!earlySupported() || pending>0 || early.active', 'if(!earlySupported() || blocked || pending>0 || early.active')
            value = replace(value, 'delete info.earlyId;delete info.earlyEpoch;\n         }', 'delete info.earlyId;delete info.earlyEpoch;\n         }else earlyDeadline=getTimer()+45000;')
        elif name == "armEarly":
            value = replace(value, 'if(!earlySupported() || pending>0)', 'if(!earlySupported() || blocked || pending>0)')
            value = replace(value, 'throw new Error("Early travel prepare identity differs");\n         }', 'throw new Error("Early travel prepare identity differs");\n         }\n         earlyDeadline=getTimer()+45000;')
        elif name == "finishEarly":
            value = replace(value, 'travelId:nativeTravel.id,earlyId:early.id', 'earlyId:early.id', 2)
        elif name == "completeEarly":
            value = replace(value, '         if(nativeTravel.current!=null)nativeTravel.finish(nativeTravel.id);\n         firstRaster.cancel();seedRaster.clear();seedDeadline=0;clearNativeEntry();nativeDeadline=0;\n         game.activeTravelId="";preparing=null;pending=0;readySent=false;', '         preparing=null;pending=0;readySent=false;')
        if name in ("completeEarly", "cancelEarly"):
            value = replace(value, 'early.cancel();earlySeal=null;earlyViewFinished=false;', 'early.cancel();earlySeal=null;earlyViewFinished=false;earlyDeadline=0;')
        methods += value
    methods += """      /** Only the negotiated full-map transaction may defer native pixels. */
      public function openFirstRaster(w:Object,l:Object,g:Object):Object {
         if(!early.active || blocked || w!==game.world || !early.safeWorld(w))return null;
         var ticket:Object=early.open(w,l,g);
         if(ticket==null)cancelEarly(true,true);
         return ticket;
      }

"""
    s = replace(s, '      private function currentSettledRoom():Boolean', methods + '      private function currentSettledRoom():Boolean')
    s = replace(s, '         if(e!=null)game.refreshWorld();', '         if(e!=null) {\n            game.refreshWorld();\n            if(early.active)try {finishEarly();}catch(earlyError:Error){fail(earlyError);}\n         }')
    s = replace(s, '         if(connected())mod.stage.invalidate();', '         ++nativeFrame;\n         if(connected())mod.stage.invalidate();')
    s = replace(s, 'if(ready || busy)reset();', 'if(ready || busy || early.active)reset();')
    old_before = '            game.refreshWorld();\n            if(game.world==null || game.loc==null || game.gg==null)return;'
    s = replace(s, old_before, '            game.refreshWorld();\n            if(early.active && (!early.safeWorld(game.world) || game.isPlayerDead()))cancelEarly(false,true);\n            if(early.active && getTimer()>earlyDeadline && !blocked)throw new Error("Early travel timed out before activation");\n            if(game.world==null || game.loc==null || game.gg==null)return;')
    s = replace(s, '      private function check():void\n      {', '      private function check():void\n      {\n         if(early.active){checkEarly();return;}')
    s = replace(s, '         if(game.isTransitioning())return;\n         if(pending>0)return;', '         if(game.isTransitioning() && !(early.active && early.valid(game.world)))return;\n         if(pending>0)return;')
    s = replace(s, '''         send({op:"seal",barrier:pending,epoch:epoch,info:game.readWorldInfo(),
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),
            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)});''', '''         var entryInfo:Object=game.readWorldInfo();
         if(early.active)entryInfo.worldReady=true;
         var seal:Object={op:"seal",barrier:pending,epoch:epoch,info:entryInfo,
            together:TravelGuard.restricted(game.loc) || TravelGuard.restricted(settledRoom),
            peerRoom:peerInfo==null?"":String(peerInfo.roomKey)};
         if(early.active){seal.earlyId=early.id;if(!early.acceptSeal(seal))throw new Error("Early host seal differs");}
         send(seal);''')
    s = replace(s, '         if(info==null || host() || info.worldReady===false)return;', '         if(info==null || host() || info.worldReady===false || early.active)return;')
    old_start = method(s, "startPreparedMap")
    new_start = replace(old_start, '         if(game.startSharedTravel(info)) {', '''         if(game.startSharedTravel(info)) {
            if(early.active && busy && pending==0) {
               if(pauseWorld!=null)pauseWorld.onPause=savedPause;
               pauseWorld=null;busy=false;game.roomHold=false;
            }''')
    new_start = replace(new_start, '            game.independentRooms=false;\n         }',
        '            game.independentRooms=false;\n         }else if(early.active)cancelEarly(true,true);')
    s = replace(s, old_start, new_start)
    s = replace(s, '''         send({op:"prepare",info:{curLandId:String(land.act.id),layoutSeed:seed,
            layoutLevel:Number(land.landDifLevel),landStage:Number(land.act.landStage),
            hostVisited:Boolean(land.act.visited),sceneMerged:game.mapGeneration.sceneMode(land,constructing),worldReady:true}});''', '''         var info:Object={curLandId:String(land.act.id),layoutSeed:seed,
            layoutLevel:Number(land.landDifLevel),landStage:Number(land.act.landStage),
            hostVisited:Boolean(land.act.visited),sceneMerged:game.mapGeneration.sceneMode(land,constructing),worldReady:true};
         offerEarly(info);
         send({op:"prepare",info:info});''')
    prehandle = """            if(msg.op=="earlyCancel") {
               if(early.active && String(msg.earlyId)==early.id)cancelEarly(false,true);
               return true;
            }
            if(String(msg.earlyId || "")!="" && (!early.active || String(msg.earlyId)!=early.id))return true;
            if(early.active) {
               if(!early.safeWorld(game.world) || game.isPlayerDead()){cancelEarly(false,true);return true;}
               if(blocked)return true;
               if(msg.op=="seal" && !host()) {
                  if(!early.acceptSeal(msg))return true;
                  if(earlySeal==null && !readySent)earlySeal=msg;
                  checkEarly();return true;
               }
               if(msg.op=="activate" && !host()) {
                  if(early.accepts(msg) && early.ackSent && early.localReady)completeEarly();
                  return true;
               }
               if(msg.op=="ack" && host()) {
                  if(early.accepts(msg) && early.paintAllowed){early.peerReady=true;finishEarly();}
                  return true;
               }
               if(msg.op=="request" || msg.op=="prepare")return true;
               if(msg.op=="ready" && host() && (!early.accepts(msg) || !early.constructed || early.paintAllowed))return true;
               if(msg.op=="grant" && (!early.accepts(msg) || early.paintAllowed))return true;
            }
"""
    s = replace(s, '            game.refreshWorld();\n            if(host())\n', '            game.refreshWorld();\n' + prehandle + '            if(host())\n')
    s = replace(s, '               preparing=msg.info;game.mapGeneration.receive(preparing);startPreparedMap();', '               preparing=msg.info;game.mapGeneration.receive(preparing);\n               armEarly(preparing);startPreparedMap();')
    s = replace(s, '               var state:Object;\n               var crossedUnchanged', '               var completingEarly:Boolean=early.active;\n               var state:Object;\n               var crossedUnchanged')
    s = replace(s, '               if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)', '               if(completingEarly) {\n                  if(game.roomKey()!=String(early.anchor.roomKey))throw new Error("Early entry room differs");\n                  TravelPlacement.place(game.gg,Number(early.anchor.x),Number(early.anchor.y));\n               }\n               else if(initial && hostInfo!=null && game.roomKey()==String(hostInfo.roomKey)')
    s = replace(s, '               TravelGuard.endTravel();\n               send({op:"ack",barrier:pending});', '               if(completingEarly) {\n                  early.allowPaint(game.world,nativeFrame);mod.stage.invalidate();return true;\n               }\n               TravelGuard.endTravel();\n               send({op:"ack",barrier:pending});')
    s = replace(s, '         if(game.isTransitioning() || game.loc==null)return;', '         if(game.loc==null || game.isTransitioning() && !(early.active && early.valid(game.world)))return;')
    s = replace(s, '''         send({op:"ready",barrier:pending,epoch:epoch,info:info,
            oldKey:settledKey,oldTerm:term,own:ownPacked,fresh:freshPacked});''', '''         var message:Object={op:"ready",barrier:pending,epoch:epoch,info:info,
            oldKey:settledKey,oldTerm:term,own:ownPacked,fresh:freshPacked};
         if(early.active){info.worldReady=true;message.earlyId=early.id;}
         send(message);''')
    s = replace(s, '''         send({op:"grant",barrier:pending,epoch:epoch,term:pending,owner:theirKey!=myKey,fresh:fresh,
            unchanged:unchanged,retained:retained,key:theirKey,state:grantPacked});''', '''         var grant:Object={op:"grant",barrier:pending,epoch:epoch,term:pending,owner:theirKey!=myKey,fresh:fresh,
            unchanged:unchanged,retained:retained,key:theirKey,state:grantPacked};
         if(early.active)grant.earlyId=early.id;
         send(grant);''')
    s = replace(s, '         // until ACK: another handoff still cannot overtake this transaction.\n         release();', '         // until ACK: another handoff still cannot overtake this transaction.\n         if(early.active){early.allowPaint(game.world,nativeFrame);mod.stage.invalidate();}\n         else release();')
    for forbidden in ("NativeTravelPlan", "FirstRasterGate", "SeedRasterEntry", "nativeTravel.", "seedRaster.", "firstRaster."):
        if forbidden in s:
            raise RuntimeError("Legacy fallback dependency retained: " + forbidden)
    out[rel] = s
    return out, inputs


def main():
    if sys.argv[1:] not in ([], ["--check"]):
        raise RuntimeError("Use no arguments to prepare text, or --check for read-only verification")
    check_only = sys.argv[1:] == ["--check"]
    out, inputs = produce()
    diffs = []
    products = {}
    for rel, text in out.items():
        source = BASE / rel
        old = load(source) if source.exists() else ""
        data = text.replace("\n", "\r\n" if source.exists() and b"\r\n" in source.read_bytes() else "\n").encode("utf-8")
        target = HERE / "src" / rel
        if check_only:
            if target.read_bytes() != data:
                raise RuntimeError("Prepared overlay differs: " + rel)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        products[rel] = sha(data)
        diffs += list(difflib.unified_diff(old.splitlines(True), text.splitlines(True), fromfile="roomfix5/" + rel, tofile="first-raster-current/" + rel))
    diff_bytes = "".join(diffs).encode("utf-8")
    if check_only:
        if (HERE / "source.diff").read_bytes() != diff_bytes:
            raise RuntimeError("Prepared source diff differs")
        if sorted(str(p.relative_to(HERE / "src")).replace("\\", "/") for p in (HERE / "src").rglob("*.as")) != sorted(out):
            raise RuntimeError("Unexpected source added to overlay")
    else:
        (HERE / "source.diff").write_bytes(diff_bytes)
    manifest = {"kind": "room-first-raster-current-source", "runtimeValidated": False, "performanceQualified": False,
                "base": str(BASE), "inputs": inputs, "sources": products, "generator_sha256": sha(Path(__file__).read_bytes()),
                "source_diff_sha256": sha((HERE / "source.diff").read_bytes())}
    if check_only:
        if json.loads((HERE / "manifest.json").read_text(encoding="utf-8")) != manifest:
            raise RuntimeError("Prepared source manifest differs")
    else:
        (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"source_check_passed": check_only, "sources": products, "runtimeValidated": False}, ensure_ascii=False))


if __name__ == "__main__":
    main()
