"""Compare completed real RoomSync component semantics after both actual runs."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--on',required=True);ap.add_argument('--off',required=True);a=ap.parse_args()
 rows=[]
 for path,expected in ((ROOT/a.on,True),(ROOT/a.off,False)):
  receipt=read(path/'receipt.json');actual=read(path/'component-result.json')
  assert receipt['passed'] and receipt['source_unchanged'] and receipt['installation_unchanged']
  assert actual['seed_gate_expected'] is expected and actual['failed']==0 and all(r['passed'] for r in actual['assertions'])
  assert len(actual['seed_semantics'])==7;rows.append(actual)
 assert rows[0]['seed_semantics']==rows[1]['seed_semantics'],'On/off final authority, restore, anchor or ACK semantics differ'
 assert [r['label'] for r in rows[0]['assertions']]==[r['label'] for r in rows[1]['assertions']]
 print(json.dumps(dict(passed=True,assertions_each=len(rows[0]['assertions']),equal_semantic_states=7,native_game_test=False)))
if __name__=='__main__':main()
