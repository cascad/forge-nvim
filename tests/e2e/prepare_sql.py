"""Явная pinned подготовка native SQL tools/parser; startup не устанавливает SDK."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import urllib.request

from prepare_rust import unpack
import sql_sdk

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tests/e2e/sql-tools/sources.json'

def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download',action='store_true')
    p.add_argument('--output',type=Path,default=ROOT/'.tests/sql-deps')
    p.add_argument('--nvim',default=os.environ.get('FORGE_TEST_NVIM','nvim'))
    p.add_argument('--go')
    p.add_argument('--cc')
    p.add_argument('--go-cc',help='Go CC command; иначе native CC / pinned Windows Zig')
    p.add_argument('--sqls-variant',choices=['upstream','patched'],help='Fresh preparation: patched; readiness сохраняет вариант manifest')
    args=p.parse_args();out=args.output.resolve();sources=json.loads(SOURCE.read_text(encoding='utf-8'))
    if os.name=='nt' and out.drive.lower()!=ROOT.drive.lower():p.error('Windows output/temp/build остаются на диске checkout')
    key=('win32' if os.name=='nt' else platform.system().lower())+'-'+('arm64' if platform.machine().lower() in ('aarch64','arm64') else 'x64')
    if key not in sources['platforms']:p.error('Нет tools для '+key)
    temp=out/'tmp';bin_dir=out/'bin'
    check_profile=None
    if args.download:temp.mkdir(parents=True,exist_ok=True);bin_dir.mkdir(exist_ok=True)
    else:
        if not (out/'manifest.json').is_file():p.error('Сначала явно prepare_sql.py --download')
        # Readiness работает и с readonly SDK без build scratch/profile.
        base=ROOT/'.tests/tmp' if os.name=='nt' else None
        if base is not None:base.mkdir(parents=True,exist_ok=True)
        check_profile=tempfile.TemporaryDirectory(prefix='forge-sql-readiness-'+str(os.getpid())+'-',dir=base)
        temp=Path(check_profile.name).resolve()
        if base is not None and not temp.is_relative_to(base.resolve()):raise RuntimeError('Readiness temp вне workspace')
    env=dict(os.environ,TEMP=str(temp),TMP=str(temp),TMPDIR=str(temp),NVIM_LOG_FILE=str(temp/'nvim.log'),
             GOTOOLCHAIN='local',GOENV='off',GOCACHE=str(out/'go-build'),GOMODCACHE=str(out/'go-mod'),
             GOTMPDIR=str(temp),GOPATH=str(out/'go'),CGO_ENABLED='1')
    # Изолируем также LSP/stdpath лог, а не только core NVIM_LOG_FILE.
    env['NVIM_APPNAME']='forge_sql_prepare'
    for name in ['HOME','USERPROFILE','LOCALAPPDATA','APPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME']:
        env[name]=str(temp/name.lower())
        Path(env[name]).mkdir(exist_ok=True)
    def run(command,**kwargs):
        if kwargs.get('text'):kwargs.setdefault('encoding','utf-8')
        return subprocess.run([str(v) for v in command],env=env,check=True,**kwargs)
    def fetch(spec):
        target=out/'archives'/spec['archive']
        if not target.is_file():
            if not args.download:p.error('Нет archive '+target.name)
            target.parent.mkdir(exist_ok=True)
            request=urllib.request.Request(spec['url'],headers={'User-Agent':'forge-nvim-e2e'})
            with urllib.request.urlopen(request,timeout=45) as response:target.write_bytes(response.read())
        if sha(target)!=spec['sha256']:p.error('SHA не совпал: '+target.name)
        return target
    manifest_path=out/'manifest.json'
    previous=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.is_file() else {}
    variant=args.sqls_variant or previous.get('sqls_variant') or ('upstream' if previous else 'patched')
    if not args.download and previous.get('source_sha256')!=sha(SOURCE):p.error('Sources изменились, нужна явная подготовка')
    if not args.download and variant!=previous.get('sqls_variant','upstream'):p.error('Вариант SQLS изменён; нужна явная подготовка --download')
    if variant=='patched':
        sql_sdk.metadata()
        if not args.download and previous.get('sdk_sha256')!=sha(sql_sdk.META):p.error('SQLS SDK изменён; нужна явная подготовка --download')
    suffix='.exe' if os.name=='nt' else ''
    build_context=previous.get('build_context',{})
    for name in ['sqls','sqruff']:
        spec=sources['platforms'][key][name];target=bin_dir/(name+suffix)
        if name=='sqls' and (spec.get('source_build') or variant=='patched'):
            if args.download:
                build_context['sqls']=sql_sdk.build(out,sources,fetch,run,env,target,args.go,args.go_cc,args.cc,variant=='patched')
        else:
            archive=fetch(spec)
            if args.download:
                directory=out/'unpacked'/name;unpack(archive,directory)
                files=list(directory.rglob(name+suffix));assert len(files)==1,(name,files)
                shutil.copyfile(files[0],target)
        if not target.is_file():p.error('Нет '+name)
        if os.name!='nt' and args.download:target.chmod(0o755)
    grammar=sources['grammar']
    catalog=Path(os.environ.get('FORGE_E2E_DEPS',ROOT/'.tests/editor-deps'))/'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    match=re.search(r"\n  sql = \{\s+install_info = \{(?:\s+branch = '[^']+',)?\s+revision = '([^']+)'",catalog.read_text(encoding='utf-8'))
    if not match or match[1]!=grammar['revision']:p.error('SQL grammar не соответствует pinned catalog')
    archive=fetch(grammar);parser=out/'site/parser/sql.so'
    if args.download:
        directory=out/'src/parser';unpack(archive,directory);src=next(directory.glob('*/src/parser.c')).parent
        cc=args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
        if not cc:p.error('Нужен C compiler для SQL parser')
        build=out/'build/parser';build.mkdir(parents=True,exist_ok=True)
        run([cc,'-O2','-shared',*([] if os.name=='nt' else ['-fPIC']),'-I',src,src/'parser.c',src/'scanner.c','-o',build/'sql.so'])
        parser.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(build/'sql.so',parser)
        build_context['parser']={'cc':str(cc),'grammar':grammar['revision']}
    lua='vim.opt.rtp={'+json.dumps((out/'site').as_posix())+",vim.env.VIMRUNTIME};assert(#vim.api.nvim_get_runtime_file('parser/sql.*',true)==1);vim.treesitter.language.add('sql');local r=vim.treesitter.get_string_parser('SELECT 42;','sql'):parse()[1]:root();assert(not r:has_error(),r:sexpr())"
    run([args.nvim,'--headless','-u','NONE','-i','NONE','+lua '+lua,'+qa'])
    versions={'sqls':run([bin_dir/('sqls'+suffix),'-version'],capture_output=True,text=True).stdout.strip(),
              'sqruff':run([bin_dir/('sqruff'+suffix),'--version'],capture_output=True,text=True).stdout.strip()}
    for name,expected in sources['versions'].items():assert expected in versions[name],versions
    if variant=='patched':assert sql_sdk.metadata()['version'] in versions['sqls'],versions
    files={f.relative_to(out).as_posix():sha(f) for f in [parser,*bin_dir.iterdir()] if f.is_file()}
    if not args.download and (previous.get('files')!=files or previous.get('versions')!=versions):p.error('Payload/versions изменились; нужна явная подготовка')
    manifest={'source_sha256':sha(SOURCE),'platform':key,'versions':versions,'files':files,'build_context':build_context,
              'sqls_variant':variant,'sdk_sha256':sha(sql_sdk.META) if variant=='patched' else None}
    if args.download:manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(('Prepared' if args.download else 'Ready')+' SQL tools: '+str(out))
    if check_profile is not None:check_profile.cleanup()

if __name__=='__main__':main()
