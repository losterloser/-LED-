from pathlib import Path
from contextlib import closing
import hashlib,json,runpy,sqlite3,tempfile,unittest,zipfile

ROOT=Path(__file__).resolve().parents[2]
restore=runpy.run_path(str(ROOT/'data/restore_library.py'))['restore']

class RestoreChecks(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);source=self.root/'source.sqlite3'
        with closing(sqlite3.connect(source)) as db:
            with db:
                db.execute('create table tracks(id integer)')
                db.execute('insert into tracks values(1)')
        self.archive=self.root/'library.zip'
        with zipfile.ZipFile(self.archive,'w') as z:z.write(source,'library.sqlite3')
        self.expected={'bytes':source.stat().st_size,'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'track_count':1}
        self.manifest=self.root/'catalog.json';self.save_manifest();self.dest=self.root/'restored.sqlite3'
    def save_manifest(self):self.manifest.write_text(json.dumps(self.expected))
    def tearDown(self):self.temp.cleanup()
    def test_restore_known_database(self):
        self.assertTrue(restore(self.archive,self.dest,self.manifest)['restored']);self.assertEqual(hashlib.sha256(self.dest.read_bytes()).hexdigest(),self.expected['sha256'])
    def test_existing_database_is_preserved(self):
        self.dest.write_bytes(b'keep my library')
        with self.assertRaises(ValueError):restore(self.archive,self.dest,self.manifest)
        self.assertEqual(self.dest.read_bytes(),b'keep my library')
    def test_wrong_digest_rejected(self):
        self.expected['sha256']='0'*64;self.save_manifest()
        with self.assertRaises(ValueError):restore(self.archive,self.dest,self.manifest)
        self.assertFalse(self.dest.exists())
    def test_wrong_size_rejected(self):
        self.expected['bytes']+=1;self.save_manifest()
        with self.assertRaises(ValueError):restore(self.archive,self.dest,self.manifest)
        self.assertFalse(self.dest.exists())

if __name__=='__main__':unittest.main(verbosity=2)
