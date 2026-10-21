"""Exact scene12 observer delta; source only, never compiles or runs a process."""
from pathlib import Path
import difflib, hashlib, json, re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/room-travel-driver-12'
BASE_MANIFEST='3106b031b97743e2a0fda30e26ab735a387b201683339ab4335a998b0d25b784'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def save(p,v):Path(p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def change(s,old,new):
    assert s.count(old)==1,old[:130]
    return s.replace(old,new,1)

def generated():
    assert sha(BASE/'prepared.json')==BASE_MANIFEST
    meta=read(BASE/'prepared.json')
    for n,h in meta['files'].items():assert sha(BASE/n)==h,n
    s=old=(BASE/'tests/RoomEntryProbe.as').read_text(encoding='utf-8-sig')
    s=change(s,'      private var connection:Object;',
        '      private var connection:Object;\n      private var confirmation:RoomEntryConfirmation=new RoomEntryConfirmation();')
    s=change(s,'connection=current;confirmedRoom=null;confirmedLand=null;confirmedStamp=null;',
        'connection=current;confirmedRoom=null;confirmedLand=null;confirmedStamp=null;confirmation.reset();')
    s=change(s,'links[link]=true;link.addEventListener(TcpLink.MESSAGE,settled);',
        'links[link]=true;link.addEventListener(TcpLink.MESSAGE,settled,false,-2147483648);')
    begin=s.index('         // Session handles these messages first.')
    end=s.index('      private function render(',begin)
    s=s[:begin]+'''         // Session's priority-0 handler has already processed this exact message.
         // READY can commit/release the host locally; ACK confirms the peer later.
         // Reject messages from a previously observed (now disconnected) socket.
         if(e.currentTarget!==connection)return;
         var isHost:Boolean=mod.session.mode==Session.HOSTING;
         if((isHost && (p.op=="ready" || p.op=="ack")) ||
            (mod.session.mode==Session.CONNECTED && p.op=="grant")) {
            var view:Object=confirmationView(),accepted:Boolean=confirmation.observe(isHost,p,view);
            if(accepted) {
               confirmedRoom=confirmation.room;confirmedLand=confirmation.land;confirmedStamp=confirmation.stamp;
            }
            Log.d("ROOM ENTRY CONFIRM "+JSON.stringify({at:getTimer(),wall:new Date().time,op:p.op,
               accepted:accepted,localCommitted:confirmation.same(view),
               peerAcknowledged:confirmation.same(view) && confirmation.peerAcknowledged,confirmedStamp:confirmedStamp,
               barrier:p.barrier,epoch:rooms.epoch,term:rooms.term,stamp:rooms.stamp({}),
               ready:rooms.ready,busy:rooms.busy,canSync:rooms.canSyncWorld,
               sameRoom:mod.game.world.loc===confirmedRoom,sameLand:mod.game.world.land===confirmedLand}));
         }
      }
      private function confirmationView():Object {
         var w:Object=mod.game.world,rooms:Object=mod.session.rooms;
         return {room:w.loc,land:w.land,gameRoom:mod.game.loc,landRoom:w.land!=null?w.land.loc:null,
            playerRoom:w.gg!=null?w.gg.loc:null,key:mod.game.roomKey(),stamp:rooms.stamp({}),
            term:rooms.term,epoch:rooms.epoch,ready:rooms.ready,busy:rooms.busy,
            authority:rooms.authority,canSync:rooms.canSyncWorld};
      }
'''+s[end:]
    s=change(s,'var sameConfirmed:Boolean=confirmedRoom!=null && w.loc===confirmedRoom && w.land===confirmedLand;',
        'var sameConfirmed:Boolean=confirmation.same(confirmationView());')
    return old,s

def assertion_calls(s):
    # Every existing call body is preserved verbatim, not merely its label.
    out=[]
    for match in re.finditer(r'(?<!function )\b(?:check|require)\(',s):
        start=match.start();opening=s.index('(',start);i=opening+1;depth=1;quote=None;escape=False
        while depth:
            c=s[i]
            if quote:
                if escape:escape=False
                elif c=='\\':escape=True
                elif c==quote:quote=None
            elif c in '\"\'':quote=c
            elif c=='(':depth+=1
            elif c==')':depth-=1
            i+=1
        out.append(s[start:i])
    return out

def check():
    old,expected=generated()
    actual=(HERE/'tests/RoomEntryProbe.as').read_text(encoding='utf-8')
    assert actual==expected,'Observer differs from exact declared delta'
    assert assertion_calls(old)==assertion_calls(actual),'Original render/native assertion changed'
    for name in ('A22RoomEntryTestDoc.as','RoomCooperationTestDoc.as','RoomScalarParity.as'):
        assert sha(BASE/'tests'/name)==read(BASE/'prepared.json')['files']['tests/'+name]
    helper=(HERE/'tests/RoomEntryConfirmation.as').read_bytes()
    assert (HERE/'component/RoomEntryConfirmation.as').read_bytes()==helper
    return dict(original_probe_calls=len(assertion_calls(old)),all_original_probe_assertions_unchanged=True,
                original_suite_byte_exact=True,component_uses_exact_observer_helper=True)

def main():
    old,new=generated()
    (HERE/'tests/RoomEntryProbe.as').write_text(new,encoding='utf-8',newline='\n')
    (HERE/'component').mkdir(exist_ok=True)
    (HERE/'component/RoomEntryConfirmation.as').write_bytes((HERE/'tests/RoomEntryConfirmation.as').read_bytes())
    (HERE/'observer.patch').write_text(''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),
        fromfile='scene12/RoomEntryProbe.as',tofile='observer/RoomEntryProbe.as')),encoding='utf-8')
    save(HERE/'static-checks.json',check())
    print(json.dumps(check()))

if __name__=='__main__':main()
