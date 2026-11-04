"""Build the full DFHack Workshop mod without installing or uploading it."""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, zipfile

ROOT=Path(__file__).resolve().parents[1]
PRELUDE="reqscript('internal/world-bridge-workshop').add_lua_path()\n"

def wrap_script(text):
    lines=text.splitlines(keepends=True)
    index=0
    while index<len(lines) and (not lines[index].strip() or lines[index].lstrip().startswith('--')):
        index+=1
    return ''.join(lines[:index])+PRELUDE+''.join(lines[index:])

def write_hashes(folder):
    entries=[]
    for path in sorted(folder.rglob('*')):
        if path.is_file() and path.name!='SHA256SUMS.txt':
            entries.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.relative_to(folder).as_posix())
    (folder/'SHA256SUMS.txt').write_text('\n'.join(entries)+'\n',encoding='utf-8')

def build(output,preview):
    output=Path(output);preview=Path(preview)
    if output.exists(): raise ValueError('Choose a new output directory; existing Workshop IDs must be preserved.')
    data=preview.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n') or len(data)>=1024*1024:
        raise ValueError('Use a PNG preview smaller than 1 MiB.')
    width,height=struct.unpack('>II',data[16:24])
    if min(width,height)<256: raise ValueError('Preview dimensions are too small.')
    version=(ROOT/'VERSION').read_text().strip()
    folder=output/'world-bridge'
    folder.mkdir(parents=True)
    for path in (ROOT/'lua').rglob('*.lua'):
        target=folder/path.relative_to(ROOT)
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(path,target)
    for path in (ROOT/'dfhack-config/scripts').rglob('*.lua'):
        target=folder/'scripts_modinstalled'/path.relative_to(ROOT/'dfhack-config/scripts')
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(wrap_script(path.read_text(encoding='utf-8')),encoding='utf-8',newline='\n')
    helper=folder/'scripts_modinstalled/internal/world-bridge-workshop.lua'
    helper.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(ROOT/'workshop/bootstrap.lua',helper)
    for name in ('info.txt','README.md'):
        shutil.copyfile(ROOT/'workshop'/name,folder/name)
    for name in ('LICENSE','CHANGELOG.md','VERSION'):
        shutil.copyfile(ROOT/name,folder/name)
    shutil.copyfile(preview,folder/'preview.png')
    source={'version':version,'license':'MIT','author':'Huitzilopochtli-98',
            'delivery':'Full DFHack Workshop Lua mod; no manual installer required',
            'luaModuleHashes':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in sorted((ROOT/'lua').rglob('*.lua'))}}
    (folder/'SOURCE.json').write_text(json.dumps(source,indent=2)+'\n',encoding='utf-8')
    shutil.copyfile(ROOT/'workshop/WORKSHOP_DESCRIPTION.bbcode',output/'WORKSHOP_DESCRIPTION.bbcode')
    write_hashes(folder)
    archive=output/('WorldBridge-'+version+'-workshop.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for path in sorted(folder.rglob('*')):
            if path.is_file():z.write(path,path.relative_to(output).as_posix())
    Path(str(archive)+'.sha256').write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
    return folder,archive

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--preview',type=Path,required=True)
    args=parser.parse_args()
    folder,archive=build(args.output,args.preview)
    print(json.dumps({'folder':str(folder),'archive':str(archive),'files':sum(p.is_file() for p in folder.rglob('*'))}))
