"""Явная native SQLS сборка; runtime редактора этот модуль не вызывает."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil

from prepare_rust import unpack

ROOT=Path(__file__).resolve().parents[2]
META=ROOT/'scripts/sdk/sqls.json'

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def metadata():
    data=json.loads(META.read_text(encoding='utf-8'))
    patch=ROOT/data['patch']
    if sha(patch)!=data['patch_sha256']:raise RuntimeError('SQLS patch SHA mismatch')
    return data

def build(out,sources,fetch,run,env,target,go=None,go_cc=None,cc=None,patched=True):
    meta=metadata() if patched else None
    go=go or shutil.which('go')
    if not go:raise RuntimeError('SQLS source build требует предоставленный Go >=1.25; задай --go')
    go=str(Path(shutil.which(str(go)) or go).resolve())
    version=run([go,'version'],capture_output=True,text=True).stdout.strip()
    found=re.search(r'go1\.(\d+)',version)
    if not found or int(found[1])<25:raise RuntimeError('Нужен Go >=1.25 (--go); GOTOOLCHAIN=local, SDK не скачивается')
    archive=fetch(sources['sqls_source']);directory=out/'src/sqls';unpack(archive,directory)
    work=next(directory.glob('*/go.mod')).parent
    if patched:
        for name,hashes in meta['files'].items():
            if sha(work/name)!=hashes['before_sha256']:raise RuntimeError('SQLS source SHA mismatch: '+name)
        run(['git','init',work],capture_output=True,text=True)
        run(['git','-c','core.autocrlf=false','-C',work,'apply','--check',ROOT/meta['patch']])
        run(['git','-c','core.autocrlf=false','-C',work,'apply',ROOT/meta['patch']])
        for name,hashes in meta['files'].items():
            if sha(work/name)!=hashes['after_sha256']:raise RuntimeError('SQLS patched SHA mismatch: '+name)
    compiler={}
    if go_cc:
        env['CC']=go_cc;compiler={'provided':go_cc}
    elif os.name=='nt':
        # Host LLVM/MSVC не умеет Go CGO -mthreads. Portable GNU target
        # готовится только здесь, по pinned archive; PATH/система не меняются.
        spec=(meta or metadata())['windows_cc'];cc_archive=fetch(spec)
        cc_dir=out/'compiler';unpack(cc_archive,cc_dir)
        zig=next(cc_dir.glob('*/zig.exe'))
        zig_version=run([zig,'version'],capture_output=True,text=True).stdout.strip()
        if zig_version!=spec['version']:raise RuntimeError('Неожиданная версия Zig: '+zig_version)
        env['CC']='"'+zig.as_posix()+'" cc -target x86_64-windows-gnu'
        env['ZIG_GLOBAL_CACHE_DIR']=str(out/'zig-cache')
        env['ZIG_LOCAL_CACHE_DIR']=str(out/'zig-local-cache')
        compiler={'zig':str(zig),'version':zig_version,'archive_sha256':sha(cc_archive)}
    else:
        native=cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
        if not native:raise RuntimeError('SQLS CGO требует native C compiler (--go-cc)')
        env['CC']='"'+str(native)+'"' if ' ' in str(native) else str(native)
        compiler={'provided':env['CC']}
    env['GOOS']={'Windows':'windows','Darwin':'darwin','Linux':'linux'}[platform.system()]
    env['GOARCH']='arm64' if platform.machine().lower() in ('aarch64','arm64') else 'amd64'
    env['GOFLAGS']='';env['GOWORK']='off';env.setdefault('GOMAXPROCS','2');env.setdefault('GOMEMLIMIT','512MiB')
    for name in ('CGO_CFLAGS','CGO_CPPFLAGS','CGO_CXXFLAGS','CGO_LDFLAGS'):env.pop(name,None)
    locks={name:sha(work/name) for name in ('go.mod','go.sum')}
    tag=meta['version'] if patched else sources['versions']['sqls']
    revision=meta['revision'] if patched else '7fcf633'
    print('Building SQLS '+tag+' (native CGO, Go -p=2)...',flush=True)
    run([go,'build','-mod=readonly','-buildvcs=false','-trimpath','-p=2','-ldflags',
         '-s -w -X main.revision='+revision,'-o',target,'.'],cwd=work)
    if patched:
        print('Checking upstream SQLS executeQuery tests...',flush=True)
        run([go,'test','-mod=readonly','-buildvcs=false','-p=2','./internal/handler','-run','^Test_executeQuery$','-count=1'],cwd=work)
    if locks!={name:sha(work/name) for name in locks}:raise RuntimeError('SQLS build изменил upstream Go locks')
    return {'go':str(go),'version':version,'cc':compiler,'source_sha256':sha(archive),'go_locks':locks,
            'sdk_sha256':sha(META) if patched else None,'patch_sha256':meta['patch_sha256'] if patched else None,'variant':tag}
