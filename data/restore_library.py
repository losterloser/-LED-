"""Restore a verified local fingerprint database from the separate Release asset."""
from pathlib import Path
from contextlib import closing
import argparse,hashlib,json,sqlite3,tempfile,zipfile

def restore(archive, destination, manifest):
    archive=Path(archive);destination=Path(destination)
    if destination.exists():raise ValueError('Target database exists; close the UI and choose a new target or retain a backup first')
    expected=json.loads(Path(manifest).read_text(encoding='utf-8'))
    with zipfile.ZipFile(archive) as z:
        entry=z.getinfo('library.sqlite3')
        if entry.file_size != expected['bytes']:raise ValueError('Database size mismatch')
        destination.parent.mkdir(parents=True,exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=destination.parent,suffix='.sqlite3',delete=False) as out:
            temp=Path(out.name);digest=hashlib.sha256()
            with z.open(entry) as stream:
                for chunk in iter(lambda:stream.read(1024*1024),b''):out.write(chunk);digest.update(chunk)
    try:
        if digest.hexdigest()!=expected['sha256']:raise ValueError('Database SHA256 mismatch')
        with closing(sqlite3.connect(temp.as_uri()+'?mode=ro',uri=True)) as db:
            if db.execute('pragma integrity_check').fetchone()[0]!='ok':raise ValueError('SQLite integrity check failed')
            if db.execute('select count(*) from tracks').fetchone()[0]!=expected['track_count']:raise ValueError('Track count mismatch')
        temp.replace(destination)
    finally:
        if temp.exists():temp.unlink()
    return {'restored':True,'track_count':expected['track_count'],'sha256':expected['sha256']}

if __name__=='__main__':
    root=Path(__file__).resolve().parent.parent
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--destination',type=Path,default=root/'src/pc/library.sqlite3');p.add_argument('--manifest',type=Path,default=root/'data/library/catalog.json');a=p.parse_args()
    print(json.dumps(restore(a.archive,a.destination,a.manifest)))
