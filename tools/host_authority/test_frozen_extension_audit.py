"""A historical-byte audit must not silently qualify new extension sources."""
import hashlib, tempfile, unittest
from pathlib import Path
from audit_checkpoint import current_extension_changes
from common import ROOT

class FrozenExtensions(unittest.TestCase):
    def test_source_policy(self):
        base=ROOT/'build/ab';base.mkdir(parents=True,exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='source-audit-test-',dir=base) as folder:
            root=Path(folder).resolve();self.assertTrue(root.is_relative_to(base.resolve()))
            p=root/'bridge.as';p.write_bytes(b'old');digest=hashlib.sha256(b'old').hexdigest();sources={'bridge.as':digest}
            self.assertEqual(current_extension_changes(root,sources),[])
            p.write_bytes(b'new')
            with self.assertRaises(ValueError):current_extension_changes(root,sources)
            drift=current_extension_changes(root,sources,True)
            self.assertEqual(drift,[dict(path='bridge.as',frozen_sha256=digest,current_sha256=hashlib.sha256(b'new').hexdigest())])
            self.assertEqual(current_extension_changes(root,{'missing.as':digest},True)[0]['current_sha256'],None)
            with self.assertRaises(ValueError):current_extension_changes(root,{'missing.as':digest})
            with self.assertRaises(ValueError):current_extension_changes(root,{'../bridge.as':digest},True)
            self.assertEqual(sources,{'bridge.as':digest})
if __name__=='__main__':unittest.main()
