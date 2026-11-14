"""Явная developer/CI сборка frontend. Installer этот скрипт не вызывает."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rustc',default=shutil.which('rustc'))
    parser.add_argument('--download',action='store_true',help='Разрешить Cargo скачать закреплённые crates, не Rust SDK')
    parser.add_argument('--work',type=Path,default=ROOT/'.tests/installer-ui')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if not args.rustc:parser.error('Нужен готовый Rust SDK для developer build')
    system={'Windows':'windows','Linux':'linux','Darwin':'macos'}[platform.system()]
    arch='arm64' if platform.machine().lower() in ('aarch64','arm64') else 'x64'
    target=system+'-'+arch;binary='fride-setup'+('.exe' if os.name=='nt' else '')
    work=args.work.resolve();temp=work/'tmp';temp.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env.update(TEMP=str(temp),TMP=str(temp),TMPDIR=str(temp),
        RUSTUP_AUTO_INSTALL='0',CARGO_BUILD_JOBS='2',CARGO_INCREMENTAL='0')
    sysroot=Path(subprocess.check_output([args.rustc,'--print','sysroot'],env=env,text=True).strip())
    rustc=sysroot/'bin'/('rustc.exe' if os.name=='nt' else 'rustc')
    cargo=sysroot/'bin'/('cargo.exe' if os.name=='nt' else 'cargo')
    env.update(RUSTC=str(rustc),PATH=str(sysroot/'bin')+os.pathsep+env.get('PATH',''),
        CARGO_HOME=str(work/'cargo-home'),CARGO_TARGET_DIR=str(work/'target'),
        CARGO_NET_OFFLINE='false' if args.download else 'true')
    for key in ['RUSTC_WRAPPER','RUSTC_WORKSPACE_WRAPPER','CARGO_ENCODED_RUSTFLAGS']:env.pop(key,None)
    env['RUSTFLAGS']='-C target-feature=+crt-static' if os.name=='nt' else ''
    source=ROOT/'installer-ui'
    files=[p for p in source.rglob('*') if p.is_file() and 'target' not in p.relative_to(source).parts]
    if not (source/'Cargo.lock').is_file():parser.error('Сначала подготовьте и проверьте Cargo.lock')
    hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in files}
    with tempfile.TemporaryDirectory(prefix='profile-',dir=temp) as profile:
        profile=Path(profile)
        for key,name in [('HOME','home'),('USERPROFILE','home'),('APPDATA','roaming'),('LOCALAPPDATA','local'),
                         ('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache')]:
            path=profile/name;path.mkdir(exist_ok=True);env[key]=str(path)
        subprocess.run([str(cargo),'build','--release','--locked','--manifest-path',str(source/'Cargo.toml')],cwd=ROOT,env=env,check=True)
    for path,sha in hashes.items():assert hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==sha,path
    output=(args.output or ROOT/'.tools/installer-ui'/target).resolve();output.mkdir(parents=True,exist_ok=True)
    compiled=work/'target/release'/binary;digest=hashlib.sha256(compiled.read_bytes()).hexdigest()
    staged=output/(binary+'.new');shutil.copy2(compiled,staged);staged.replace(output/binary)
    (output/'binary.sha256').write_text(digest+'\n',encoding='ascii')
    receipt={'schema':1,'platform':target,'binary':binary,'sha256':digest,'sources':hashes,
             'rustc':subprocess.check_output([str(rustc),'--version'],env=env,text=True).strip()}
    (output/'manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'binary':str(output/binary),'sha256':digest,'platform':target},ensure_ascii=False))


if __name__=='__main__':main()
