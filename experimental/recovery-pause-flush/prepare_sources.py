"""Materialize exact recovery22 AS-only pause edge proposal; no process launches."""
from pathlib import Path
import argparse, difflib, hashlib, json

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
BASE=ROOT/'build/m52/recovery-22'
CORE='rconnect/core/'
BASE_MANIFEST='cada3af2e49459a3fe7c3b53ddca0e31392ab8b8fd1589ad0c4b05aa0a3042ce'
BASE_INTEGRATION='63b2f0cc1d06a0be68b9f883430255b5ef500d624cce341e5184cef04a632a0a'
VERSION='0.2.24-recovery23'

FLUSH='''      /** One stopped-pose flush; normal timer cadence remains unchanged. */
      public function flushPausedWorldState():void
      {
         if(mode!=HOSTING || pause==null || !pause.paused
            || mod.game==null || !mod.game.coopPaused || !rooms.canSyncWorld
            || !rooms.authority || mod.game.isTransitioning()
            || server==null || !server.bound || server.clients.length==0)return;
         try {broadcastWorldState();}
         catch(error:*) {Log.d("RConnectNet: pause flush failed "+error);}
      }

'''

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def method(source,name):
    start=source.index('      private function '+name+'(')
    opening=source.index('{',start);depth=1;i=opening+1
    # Existing method contains no brace characters in strings/comments.
    while depth:
        depth+=(source[i]=='{')-(source[i]=='}');i+=1
    return source[start:i]+'\n'

def planned():
    assert sha(BASE/'prepared.json')==BASE_MANIFEST
    assert sha(BASE/'integration.json')==BASE_INTEGRATION
    manifest=json.loads((BASE/'prepared.json').read_text('utf-8-sig'))
    all_sources={p.relative_to(BASE/'src').as_posix():p.read_bytes() for p in (BASE/'src').rglob('*.as')}
    assert len(all_sources)==90
    assert {n:hashlib.sha256(v).hexdigest() for n,v in all_sources.items()}==manifest['source']
    originals={name:(BASE/'src'/CORE/(name+'.as')).read_bytes() for name in ['CoopPause','Session']}
    assert all(raw==(ROOT/'build/m52/recovery-21/src'/CORE/(name+'.as')).read_bytes()
               for name,raw in originals.items()),'21/22 pause base differs'
    text={k:v.decode('utf-8-sig') for k,v in originals.items()}
    assert all('\r' not in s for s in text.values()),'Keep original line endings'
    old='         setPaused(playable && reasons.length>0);\n'
    new='         var wasPaused:Boolean=_paused;\n'+old
    assert text['CoopPause'].count(old)==1
    pause=text['CoopPause'].replace(old,new)
    old_send='''            if(now<nextSend && summary==lastSummary)return;
            lastSummary=summary;nextSend=now+250;
            var state:Object={type:"coop-pause",op:"state",seq:++serial,epoch:epoch,menus:_menus,sats:_sats,reasons:reasons};
            for each(p in session.peers)if(p.link!=null && p.link.isOpen)p.link.send(state);'''
    new_send='''            if(now>=nextSend || summary!=lastSummary) {
               lastSummary=summary;nextSend=now+250;
               var state:Object={type:"coop-pause",op:"state",seq:++serial,epoch:epoch,menus:_menus,sats:_sats,reasons:reasons};
               for each(p in session.peers)if(p.link!=null && p.link.isOpen)p.link.send(state);
            }
            // Notify pause first; capturing a large stopped-world payload must
            // not delay the existing pause acknowledgement.
            if(!wasPaused && _paused)session.flushPausedWorldState();'''
    assert pause.count(old_send)==1
    pause=pause.replace(old_send,new_send)
    session=text['Session']
    slot='      private function broadcastWorldState():void\n'
    assert session.count(slot)==1
    session=session.replace(slot,FLUSH+slot)
    assert pause.replace(new_send,old_send).replace(new,old)==text['CoopPause']
    assert session.replace(FLUSH,'')==text['Session']
    files={'src/'+n:v for n,v in all_sources.items()}
    old_entry=all_sources['RConnectMod.as']
    old_version=b'"0.2.24-recovery22"'
    new_version=('"'+VERSION+'"').encode()
    assert old_entry.count(old_version)==1
    new_entry=old_entry.replace(old_version,new_version)
    assert new_entry.replace(new_version,old_version)==old_entry
    files['src/RConnectMod.as']=new_entry
    files['version.diff']=''.join(difflib.unified_diff(
        old_entry.decode('utf-8-sig').splitlines(True),new_entry.decode('utf-8-sig').splitlines(True),
        fromfile='recovery22/RConnectMod.as',tofile='pause-edge/RConnectMod.as')).encode()
    files.update({'src/'+CORE+'CoopPause.as':pause.encode(),'src/'+CORE+'Session.as':session.encode(),
           'components/'+CORE+'CoopPause.as':pause.encode()})
    files['components/'+CORE+'ControlCoopPause.as']=text['CoopPause'].replace('CoopPause','ControlCoopPause').encode()
    shell=(HERE/'fixtures/Session.shell.txt').read_text('utf-8')
    files['components/'+CORE+'Session.as']=shell.replace('@@FLUSH@@',FLUSH).replace('@@BROADCAST@@',method(session,'broadcastWorldState')).encode()
    files['proposal.patch']=''.join(''.join(difflib.unified_diff(text[name].splitlines(True),updated.splitlines(True),
        fromfile='recovery22/'+CORE+name+'.as',tofile='pause-edge/'+CORE+name+'.as'))
        for name,updated in [('CoopPause',pause),('Session',session)]).encode()
    integration={'version':VERSION,'compiled':False,'runtime_tested':False,
       'diagnostic_only':False,'candidate_only':True,'baseline':str(BASE),'baseline_sha256':manifest['candidate_sha256'],
       'baseline_manifest_sha256':BASE_MANIFEST,'static_errors':[],
       'unchanged_class_count':87,'complete_class_count':90,'performance_qualified':False,'installed':False,
       'version_note':'Parent assigned recovery23; RConnectMod changes only the version literal.',
       'source':[{'path':n[4:],'sha256':hashlib.sha256(v).hexdigest()}
                 for n,v in sorted(files.items()) if n.startswith('src/') and n.endswith('.as')]}
    files['integration.json']=(json.dumps(integration,ensure_ascii=False,indent=2)+'\n').encode()
    return files,originals

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--materialize',action='store_true');a=ap.parse_args()
    files,originals=planned()
    for name,raw in files.items():
        p=HERE/name
        if a.materialize:p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
        assert p.read_bytes()==raw,name+' differs'
    manifest={'base':str(BASE),'base_prepared_sha256':sha(BASE/'prepared.json'),
       'base_integration_sha256':sha(BASE/'integration.json'),
       'base_sources':{CORE+k+'.as':hashlib.sha256(v).hexdigest() for k,v in originals.items()},
       'production_scope':'complete 90-class recovery23 source; CoopPause and Session logic; RConnectMod version-only; other 87 byte-identical',
       'compiled':False,'runtime_tested':False,'expected_component_assertions':50,
       'component_boundary':'exact full CoopPause; exact Session flush and broadcast methods in fixture shell; no game or real socket',
       'files':{p.relative_to(HERE).as_posix():sha(p) for p in sorted(HERE.rglob('*'))
           if p.is_file() and p.name!='inputs.json'}}
    (HERE/'inputs.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'verified':True,'logic_classes':2,'version_classes':1,'unchanged_classes':87,'compiled':False,'runtime_tested':False}))
if __name__=='__main__':main()
