"""IDE-BOOT-28: native publisher preparation, no host install/font registration."""
import argparse
from contextlib import contextmanager
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import platform
import shutil
import stat
import subprocess
import tarfile
import tempfile
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def policy():
    return json.loads((ROOT/'scripts/sdk/terminal.json').read_text(encoding='utf-8'))


def native_platform():
    system = {'Windows':'windows','Linux':'linux','Darwin':'macos'}[platform.system()]
    arch = {'amd64':'x64','x86_64':'x64','arm64':'arm64','aarch64':'arm64'}.get(platform.machine().lower())
    return system+'-'+str(arch)


def sources(native):
    p = policy(); w = p['wezterm']
    if native not in w['platforms']: raise ValueError('Unsupported native Terminal platform: '+native)
    asset = w['platforms'][native]
    return [dict(archive=asset['archive'], url=w['release']+asset['archive'], sha256=asset['sha256']),
            {k:p['font'][k] for k in ('archive','url','sha256')}, w['license']]


def checked(raw, expected):
    if hashlib.sha256(raw).hexdigest() != expected: raise ValueError('Terminal source SHA mismatch')
    return raw


def zip_tree(raw, target, prefix):
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        links = []
        for entry in archive.infolist():
            if not entry.filename.startswith(prefix): continue
            name = entry.filename[len(prefix):]
            if not name: continue
            path = target/name
            if '\\' in name or ':' in name or not path.resolve().is_relative_to(target.resolve()):
                raise ValueError('Unsafe Terminal archive member')
            if entry.is_dir(): path.mkdir(parents=True,exist_ok=True); continue
            if name.endswith('.pdb'): continue  # upstream debug symbols, not runtime
            path.parent.mkdir(parents=True,exist_ok=True)
            mode = entry.external_attr >> 16
            if stat.S_ISLNK(mode):
                link = archive.read(entry).decode()
                if Path(link).is_absolute() or not (path.parent/link).resolve().is_relative_to(target.resolve()):
                    raise ValueError('External Terminal archive link')
                links.append((path,link))
            else:
                path.write_bytes(archive.read(entry)); path.chmod(mode & 0o777 or 0o755)
        for path,link in links: path.symlink_to(link)


@contextmanager
def payload(raw, native, parent):
    p = policy(); specs = sources(native)
    for data,spec in zip(raw,specs): checked(data,spec['sha256'])
    with tempfile.TemporaryDirectory(prefix='.terminal-',dir=parent) as temporary:
        work = Path(temporary); terminal = work/'terminal'; terminal.mkdir()
        if native.startswith('windows-'):
            zip_tree(raw[0],terminal/'wezterm','WezTerm-windows-'+p['wezterm']['version']+'/')
        elif native.startswith('macos-'):
            zip_tree(raw[0],work/'mac',Path(specs[0]['archive']).stem + '/')
            for path in (work/'mac').rglob('*'):
                if path.is_symlink() and not path.resolve().is_relative_to(work/'mac'):
                    raise ValueError('External Terminal archive link')
            shutil.copytree(work/'mac',terminal/'wezterm',symlinks=False)
        else:
            image=work/'wezterm.AppImage'; image.write_bytes(raw[0]); image.chmod(0o755)
            subprocess.run([str(image),'--appimage-extract'],cwd=work,stdout=subprocess.DEVNULL,check=True,timeout=45)
            for path in (work/'squashfs-root').rglob('*'):
                if path.is_symlink() and not path.resolve().is_relative_to(work/'squashfs-root'):
                    raise ValueError('External Terminal archive link')
            shutil.copytree(work/'squashfs-root',terminal/'wezterm',symlinks=False)
        fonts=terminal/'fonts';fonts.mkdir()
        licenses=terminal/'licenses';licenses.mkdir()
        with tarfile.open(fileobj=io.BytesIO(raw[1]),mode='r:xz') as archive:
            for face in p['font']['faces']:
                name='CaskaydiaCoveNerdFont-'+face+'.ttf'
                (fonts/name).write_bytes(archive.extractfile(name).read())
            (licenses/'CascadiaCode-LICENSE').write_bytes(archive.extractfile(p['font']['license']).read())
            (licenses/'CascadiaCode-README.md').write_bytes(archive.extractfile('README.md').read())
        (licenses/'WezTerm-LICENSE.md').write_bytes(raw[2])
        yield terminal


def version(binary):
    result=subprocess.run([str(binary),'--version'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=10)
    expected='wezterm '+policy()['wezterm']['version']
    if result.returncode or result.stdout.strip()!=expected: raise ValueError('Unexpected native WezTerm version: '+result.stdout+result.stderr)
    return result.stdout.strip()


def hashes(directory):
    result={}
    for p in sorted(directory.rglob('*')):
        if p.is_symlink(): raise ValueError('Prepared Terminal links are not supported')
        name=p.relative_to(directory).as_posix()
        if p.is_file() and name!='prepared.json':result[name]=hashlib.sha256(p.read_bytes()).hexdigest()
    return result


def verify(directory):
    directory=Path(directory).resolve();native=native_platform();p=policy();specs=sources(native)
    meta=json.loads((directory/'prepared.json').read_text(encoding='utf-8'))
    if meta.get('schema')!=1 or meta.get('platform')!=native or meta.get('policy')!=p or meta.get('sources')!=specs:
        raise ValueError('Terminal manifest/policy mismatch')
    if json.loads((directory/'terminal/prepared.json').read_text(encoding='utf-8'))!=meta: raise ValueError('Delivered Terminal metadata mismatch')
    raw=[(directory/'sources'/s['archive']).read_bytes() for s in specs]
    with payload(raw,native,directory.parent) as expected:
        if hashes(expected)!=meta['files'] or hashes(directory/'terminal')!=meta['files']:
            raise ValueError('Terminal payload differs from pinned source')
    version(directory/'terminal'/p['wezterm']['platforms'][native]['executable'])
    return meta


def prepare(output, source_dir=None, download=False):
    output=Path(output).resolve();native=native_platform();p=policy();specs=sources(native)
    raw=[]
    for spec in specs:
        if source_dir: data=(Path(source_dir)/spec['archive']).read_bytes()
        elif download:
            with urllib.request.urlopen(spec['url'],timeout=45) as response: data=response.read()
        else: raise ValueError('Provide --source-dir or explicitly allow --download')
        raw.append(checked(data,spec['sha256']))
    if output.exists(): return verify(output)
    output.parent.mkdir(parents=True,exist_ok=True)
    with payload(raw,native,output.parent) as terminal:
        actual=version(terminal/p['wezterm']['platforms'][native]['executable'])
        stage=terminal.parent
        meta={'schema':1,'platform':native,'policy':p,'sources':specs,'native_version':actual,'files':hashes(terminal)}
        for path in [stage/'prepared.json',terminal/'prepared.json']:path.write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
        source=stage/'sources';source.mkdir()
        for data,spec in zip(raw,specs):(source/spec['archive']).write_bytes(data)
        # Move only delivered preparation; temporary extraction inputs stay disposable.
        ready=stage/'ready';ready.mkdir()
        shutil.move(str(terminal),ready/'terminal');shutil.move(str(source),ready/'sources')
        shutil.move(str(stage/'prepared.json'),ready/'prepared.json');ready.rename(output)
    return meta


def package(directory, output):
    directory=Path(directory).resolve();output=Path(output).resolve()
    if output==directory or directory in output.parents: raise ValueError('Output must be outside prepared Terminal')
    meta=verify(directory)
    Path(output).resolve().parent.mkdir(parents=True,exist_ok=True)
    module=importlib.util.spec_from_file_location('terminal_packager',ROOT/'scripts/package-runtime.py')
    packager=importlib.util.module_from_spec(module);module.loader.exec_module(packager)
    with tempfile.TemporaryDirectory(prefix='.terminal-package-',dir=Path(output).resolve().parent) as temporary:
        work=Path(temporary);shutil.copytree(directory/'terminal',work/'runtime/terminal')
        native=meta['platform'];binary='terminal/'+meta['policy']['wezterm']['platforms'][native]['executable']
        recipe={'schema':1,'platform':native,'components':['terminal'],'paths':[], 'probes':[[binary,'--version']]}
        path=work/'recipe.json';path.write_text(json.dumps(recipe),encoding='utf-8')
        return packager.package(work/'runtime',path,output,component='terminal')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--source-dir',type=Path);parser.add_argument('--download',action='store_true')
    parser.add_argument('--package',type=Path,help='Package an existing prepared directory into --output')
    args=parser.parse_args()
    print(json.dumps(package(args.package,args.output) if args.package else prepare(args.output,args.source_dir,args.download),indent=2))
