"""Exact raster guard verification; accepts only optional statement braces."""
import re

def body(source, name):
    match=re.search(r'function\s+(?:get\s+)?'+name+r'\([^\n]*\)[^{]*\{',source)
    assert match,name
    start=match.end();end=start;depth=1
    while end<len(source) and depth:
        depth+=(source[end]=='{')-(source[end]=='}');end+=1
    assert depth==0,name+' truncated'
    return re.sub(r'\s+','',source[start:end-1])

def first_if(text):
    """Return exact first condition, statement body and remaining method text.

    This deliberately handles only known compact guard syntax, not generic AS.
    Extra statements inside braces remain visible and therefore fail callers.
    """
    assert text.startswith('if('),'guard is not first'
    end=3;depth=1
    while end<len(text) and depth:
        depth+=(text[end]=='(')-(text[end]==')');end+=1
    assert depth==0,'unterminated guard condition'
    condition=text[3:end-1]
    start=end
    if text[start:start+1]=='{':
        end=start+1;depth=1
        while end<len(text) and depth:
            depth+=(text[end]=='{')-(text[end]=='}');end+=1
        assert depth==0,'unterminated guard block'
        statement=text[start+1:end-1]
    else:
        end=text.find(';',start)+1
        assert end>start,'guard statement missing'
        statement=text[start:end]
    assert not text[end:].startswith('else'),'unexpected guard else branch'
    return condition,statement,text[end:]

def verify_guard(text, condition, statement):
    actual,branch,rest=first_if(text)
    assert actual==condition,('guard condition',actual)
    assert branch==statement,('guard statement',branch)
    return rest

def verify_grafon(source):
    assert 'rconnectRasterBridge:Function' in source and 'rconnectRasterTicket:Object' in source
    opened=body(source,'sceneOpen');last=-1
    for call in ('rconnectRasterBridge(','sceneSyncRegionLighting(','sceneClear(',
                 'sceneConfigureBorders(','scenePrepare(','setLight(','sceneIndexBackdrops(',
                 'sceneEnsure(','drawAllObjs(','rconnectRasterPainted('):
        found=opened.index(call);assert found>last,call;last=found
    for name,statement in (('sceneEnsure','return;'),('sceneTick','return;'),('sceneViewReady','returnfalse;')):
        verify_guard(body(source,name),'this.rconnectRasterWaiting()',statement)
    verify_guard(body(source,'rconnectRasterPainted'),
        'this.rconnectRasterTicket!=null&&this.rconnectRasterTicket.unpainted===true&&'
        '!this.rconnectRasterWaiting()&&this.sceneResident>0&&this.sceneViewReady()',
        'this.rconnectRasterTicket.unpainted=false;')
    drawing=body(source,'drawLoc')
    # FFDec hoists pure local declarations. No executable statement may be
    # inserted before either native large-room branch or ticket reset.
    while drawing.startswith('var'):
        declaration=re.match(r'var\w+:(?:[\w.]+|\*);',drawing)
        assert declaration,'unexpected executable declaration before draw guard'
        drawing=drawing[declaration.end():]
    drawing=verify_guard(drawing,
        '!this.sceneRasterizing&&(param1.spaceX>World.cellsX||param1.spaceY>World.cellsY)',
        'this.sceneOpen(param1);return;')
    drawing=verify_guard(drawing,'!this.sceneRasterizing','this.rconnectRasterTicket=null;')
    assert drawing.startswith('sceneStarted=int(getTimer());this.scenePrepare(param1);'),'reset guard moved'
    assert not re.search(r'\.\s*\(\s*@',source),'Unexpected E4X import hazard'

