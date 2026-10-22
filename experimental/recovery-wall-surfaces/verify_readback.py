"""Grafon source/readback anchors; no JVM, AIR, mutation or deployment.

Use on the exported candidate Grafon after the parent-owned host build. This
does NOT replace host header/tag/class/representative/installed-input checks.
"""
from pathlib import Path
import argparse,re

def method(source,name):
    m=re.search(r'(?:public|private) function '+re.escape(name)+r'\(',source)
    assert m,name
    start=source.index('{',m.end());depth=0
    for i in range(start,len(source)):
        depth+=(source[i]=='{')-(source[i]=='}')
        if depth==0:return source[m.start():i+1]
    raise AssertionError('Unclosed '+name)
def compact(s):return re.sub(r'\s+','',s)
def ordered(s,*parts):
    at=-1
    for part in parts:
        found=s.find(part,at+1);assert found>at,part;at=found
def verify(source):
    assert '§§' not in source
    s=compact(source)
    assert 'publicstaticvarrconnectWallBridge:Function=null;' in s
    assert 'privatevarrconnectWallClips:Array=null;' in s
    assert '"m","rconnectWallClips"]' in s
    body=lambda name:compact(method(source,name))
    applied=body('sceneApply')
    assert applied.count('Math.random()')==2
    assert applied.count('this.sceneApplyCompactDecal(args,affected)')==1
    assert applied.count('this.sceneApplyRegionAction(kind,args,affected)')==1
    ordered(applied,'this.sceneMarks.push(wallMark)','rconnectWallNotify("mark",wallMark,affected)',
            'this.frontBmp=entry.nativeBuffers[0]','this.sceneX=entry.x',
            'rconnectWallNotify("before",wallMark,affected)','try{',
            'this.sceneApplyCompactDecal(args,affected)',
            'finally{','rconnectWallNotify("after",wallMark,affected,wallToken)',
            '++entry.revision','finally{','this.frontBmp=this.sceneScratch[0]',
            'this.sceneX=ox','this.sceneY=oy','this.sceneRasterizing=false','this.sceneStamp=null')
    restored=body('sceneRestoreMarks')
    ordered(restored,'rconnectWallNotify("before",item,','try{','this.sceneApplyRegionAction(',
            'finally{','rconnectWallNotify("after",item,','finally{','this.sceneStamp=null',
            'rconnectWallNotify("raster")')
    notify=body('rconnectWallNotify')
    ordered(notify,'if(rconnectWallBridge==null)','returnnull','try{',
            'rconnectWallBridge(kind,this,this.loc,this.frontBmp,this.sceneX,this.sceneY,affected,mark,token,this.rconnectWallClips)',
            'catch(','this.rconnectWallErrors++<4')
    draw=body('sceneRegionDrawPass')
    ordered(draw,'savedWallClips:Array=this.rconnectWallClips','this.sceneRegionPassActive=true',
            'this.rconnectWallClips=wallClips','try{','this.drawLoc(this.loc)',
            'finally{','this.rconnectWallClips=savedWallClips')
    chunk=body('sceneDrawRegionChunk')
    assert 'this.rconnectWallBaseClips(viewport,groups)' in chunk
    assert 'this.sceneRegionDrawPass(group.style,rconnectWallBridge!=null?group.clips:null)' in chunk
    for name in ('scenePreloadRegions','sceneFirstWindow'):
        assert 'this.sceneRegionDrawPass(style,rconnectWallBridge!=null?[clip]:null)' in body(name)
    warm=body('sceneAdvanceWarm')
    ordered(warm,'group=job.groups[job.group]','this.rconnectWallClips=rconnectWallBridge!=null?group.clips:null',
            'job.steps=this.sceneDrawSteps(this.loc)')
    assert 'foreach(fieldinthis.sceneWarmFields){this[field]=prior[field];}' in warm
    # Previous first-raster behavior remains present; do not silently lose FD92.
    assert 'rconnectRasterBridge:Function' in source and 'rconnectRasterTicket:Object' in source
    return True

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('grafon',type=Path);a=p.parse_args()
    verify(a.grafon.read_text(encoding='utf-8-sig'));print('Wall-surface Grafon anchors passed; not complete host qualification')
