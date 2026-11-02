"""Read-only checks for the reorganized source, evidence and final materials."""
from pathlib import Path
import argparse, hashlib, json, re, runpy, struct, zipfile

ROOT=Path(__file__).resolve().parent.parent
SKIP=('.git/','.Xil/','src/pc/.venv/','board/vivado/','board/output/','board/current/',
      'board/runtime/','build/current/','sim/results/current_pc/')

def sha256(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for data in iter(lambda:f.read(1024*1024),b''):h.update(data)
    return h.hexdigest()

def included(path,root):
    rel=path.relative_to(root).as_posix()
    return path.is_file() and '__pycache__' not in path.parts and not rel.startswith(SKIP)

def boxes(data,start=0,end=None):
    end=len(data) if end is None else end
    while start+8<=end:
        size,kind=struct.unpack_from('>I4s',data,start);header=8
        if size==1:
            size=struct.unpack_from('>Q',data,start+8)[0];header=16
        elif size==0:size=end-start
        if size<header or start+size>end:raise ValueError('Invalid MP4 box')
        yield kind,start+header,start+size
        start+=size

def video_metadata(path):
    with Path(path).open('rb') as f:
        while True:
            head=f.read(8)
            if not head:raise ValueError('MP4 moov missing')
            size,kind=struct.unpack('>I4s',head);header=8
            if size==1:size=struct.unpack('>Q',f.read(8))[0];header=16
            if size<header:raise ValueError('Invalid top-level MP4 box')
            if kind==b'moov':data=f.read(size-header);break
            f.seek(size-header,1)
    info={'bytes':Path(path).stat().st_size,'sample_entry_types':[]}
    def visit(data,start,end):
        for kind,a,b in boxes(data,start,end):
            if kind==b'mvhd':
                p=data[a:b]
                if p[0]==0:scale,duration=struct.unpack_from('>II',p,12)
                else:scale=struct.unpack_from('>I',p,20)[0];duration=struct.unpack_from('>Q',p,24)[0]
                info['duration_seconds']=duration/scale
            elif kind==b'stsd':
                for entry,_,_ in boxes(data,a+8,b):info['sample_entry_types'].append(entry.decode('ascii'))
            elif kind in {b'trak',b'mdia',b'minf',b'stbl'}:visit(data,a,b)
    visit(data,0,len(data))
    return info

def verify(root,check_library=False):
    root=Path(root).resolve();errors=[];details={}
    required=['README.md','src/rtl/top_music_rgb.v','src/pc/desktop.py',
      'src/constraints/navigator_v39.xdc','sim/tb/tb_top_music_rgb.sv','build/build.ps1',
      'build/create_project.tcl','build/run_checks.tcl','board/jtag_device.tcl',
      'board/hardware.md','board/results/acceptance.json','data/restore_library.py',
      'data/library/catalog.json','skill/README.md','skill/fpga-audio-reproduce/SKILL.md',
      'report/design_report.pdf','report/design_report.docx','report/collaboration.md',
      'report/requirements_map.md','report/directory_map.md']
    for rel in required:
        if not (root/rel).is_file():errors.append('Missing '+rel)
    try:
        inputs=json.loads((root/'build/compiled_inputs.json').read_text())
        for rel,digest in inputs.items():
            if not (root/rel).is_file() or sha256(root/rel)!=digest:errors.append('Archived input differs: '+rel)
        details['archived_inputs_verified']=len(inputs)
        if len(inputs)!=54:errors.append('Expected 54 archived inputs')
        manifest=json.loads((root/'board/artifacts/manifest.json').read_text())
        for name,row in manifest.items():
            if sha256(root/'board/artifacts'/name)!=row['sha256']:errors.append('Artifact differs: '+name)
        tests=re.search(r'set tests \{([^}]+)\}',(root/'build/run_checks.tcl').read_text()).group(1).split()
        for name in tests:
            text=(root/'sim/results/archived_rtl'/(name+'.log')).read_text(errors='replace')
            if not re.search(r'^PASS '+re.escape(name)+r'[: ]',text,re.M) or re.search(r'FATAL:',text,re.I):errors.append('Archived RTL test failed: '+name)
        details['archived_rtl_tests']=len(tests)
        pc=(root/'sim/results/archived_pc/regression_33.log').read_text(errors='replace')
        if not re.search(r'Ran 33 tests',pc) or not re.search(r'^OK\s*$',pc,re.M):errors.append('Archived PC regression invalid')
        checker=runpy.run_path(str(root/'skill/fpga-audio-reproduce/scripts/check_reports.py'))['check_reports']
        result=checker(root,json.loads((root/'build/config/report_checks.json').read_text()))
        details['implementation_reports']=result
        if not result['passed']:errors.extend(result['errors'])
        for rel,count in [('sim/results/archived_pc/display_replay/replay_summary.json',7),('sim/results/archived_pc/mic_acquisition_summary.json',11)]:
            record=json.loads((root/rel).read_text())
            if not record['all_passed'] or record['cases']!=count:errors.append('Invalid replay evidence: '+rel)
        materials=json.loads((root/'report/provenance/materials.json').read_text(encoding='utf-8'))
        absent=[]
        for row in materials['materials']:
            p=root/row['path']
            if not p.is_file():
                if row['path'] in {'report/media/demo.mp4','data/library/fingerprints.zip'}:absent.append(row['path']);continue
                errors.append('Missing final material: '+row['path']);continue
            if sha256(p)!=row['sha256']:errors.append('Final material differs: '+row['path'])
        details['video_separate_attachment']='report/media/demo.mp4' in absent
        details['optional_release_assets_missing']=absent
        video=root/'report/media/demo.mp4'
        if video.exists():
            meta=video_metadata(video);details['video']=meta
            if meta['bytes']>=300000000 or meta['duration_seconds']>=180 or 'avc1' not in meta['sample_entry_types']:errors.append('Video format, size or duration exceeds declared target')
        if check_library:
            expected=json.loads((root/'data/library/catalog.json').read_text(encoding='utf-8'))
            with zipfile.ZipFile(root/'data/library/fingerprints.zip') as z:
                if z.testzip():errors.append('Fingerprint archive CRC invalid')
                h=hashlib.sha256()
                with z.open('library.sqlite3') as stream:
                    for data in iter(lambda:stream.read(1024*1024),b''):h.update(data)
                if h.hexdigest()!=expected['sha256'] or z.getinfo('library.sqlite3').file_size!=expected['bytes']:errors.append('Fingerprint library differs from catalog')
            details['fingerprint_library_verified']=True
    except (OSError,ValueError,KeyError,AttributeError,struct.error,zipfile.BadZipFile) as exc:errors.append(str(exc))
    files=[p for p in root.rglob('*') if included(p,root)]
    for p in files:
        rel=p.relative_to(root)
        for part in rel.parts:
            if part in {'README.md','SKILL.md','.gitignore','.gitattributes'}:continue
            if not re.fullmatch(r'[a-z0-9_.-]+',part):errors.append('Nonconforming name: '+rel.as_posix());break
        if p.name in {'.env','config.local.json'} or p.suffix.lower() in {'.mp3','.key','.pem','.sqlite3'}:errors.append('Private/raw asset: '+rel.as_posix())
    details.update(files_checked=len(files),total_bytes=sum(p.stat().st_size for p in files))
    return dict(passed=not errors,details=details,errors=errors,new_hardware_actions=False,network_used=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--check-library',action='store_true')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args();result=verify(args.root,args.check_library)
    if args.output:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result['passed'] else 1)
