"""One post-registration/pre-copy check; failed inputs always leave a receipt."""
from pathlib import Path
import json
import baseline

def assert_installation(args,output):
    receipt=dict(phase='registration acquired before private copies',passed=False,
        air_started=False,private_copies_built=False,performance_qualified=False)
    try:
        intent_path=Path(args.effects_driver).resolve().parent/'intent.json'
        receipt['outer_intent']=str(intent_path);receipt['outer_intent_sha256']=baseline.sha(intent_path)
        expected=baseline.read(intent_path)['installation']
        receipt['expected']=expected
        assert expected==baseline.expected_installation() and len(expected)==22,'Outer intent is not the pre-admitted exact installation'
        actual=baseline.installation();receipt['actual']=actual
        assert actual==expected,'Installed inputs changed while queued; no private copy or AIR may start'
        from native_inputs import verify_tools
        verify_tools()  # Recheck pinned observer/host/helper/sampler inputs after queue too.
        receipt['passed']=True
    except BaseException as error:
        receipt.update(error_type=type(error).__name__,error=str(error))
        (output/'installation-gate.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        (output/'error.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        (output/'result.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
        raise
    (output/'installation-gate.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
