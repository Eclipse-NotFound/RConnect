"""Compare exact repaired real-RoomSync components after both actual executions."""
import argparse
import json
from pathlib import Path
from prepare_components import ROOT,HERE,sha,read,files,verify_sources


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--on',required=True);ap.add_argument('--off',required=True)
    args=ap.parse_args();verify_sources();rows=[]
    for name,expected in (('on',True),('off',False)):
        path=(ROOT/getattr(args,name)).resolve();assert path.parent==ROOT/'build/m52'
        receipt=read(path/'receipt.json');actual=read(path/'component-result.json');intent=read(path/'intent.json')
        assert receipt['passed'] and receipt['source_unchanged'] and receipt['installation_unchanged']
        assert receipt['observed_checks']==109 and receipt['checks_failed']==0
        assert receipt['component_sha256']==sha(path/'Checks.swf')
        assert files(path/'src')==files(HERE/'components'/name)==intent['sources']
        assert actual['seed_gate_expected'] is expected and actual['failed']==0
        assert len(actual['assertions'])==109 and all(r['passed'] for r in actual['assertions'])
        assert len(actual['seed_semantics'])==7
        rows.append(actual)
    assert rows[0]['seed_semantics']==rows[1]['seed_semantics'],'Final authority/restore/anchor/ACK semantics differ'
    assert [r['label'] for r in rows[0]['assertions']]==[r['label'] for r in rows[1]['assertions']]
    print(json.dumps(dict(passed=True,assertions_each=109,equal_semantic_states=7,native_game_test=False)))


if __name__=='__main__':main()
