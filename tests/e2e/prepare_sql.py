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
import urllib.request

from prepare_rust import unpack

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
    args=p.parse_args();out=args.output.resolve();sources=json.loads(SOURCE.read_text(encoding='utf-8'))
    if os.name=='nt' and out.drive.lower()!=ROOT.drive.lower():p.error('Windows output/temp/build остаются на диске checkout')
    key=('win32' if os.name=='nt' else platform.system().lower())+'-'+('arm64' if platform.machine().lower() in ('aarch64','arm64') else 'x64')
    if key not in sources['platforms']:p.error('Нет tools для '+key)
    temp=out/'tmp';bin_dir=out/'bin'
    if args.download:temp.mkdir(parents=True,exist_ok=True);bin_dir.mkdir(exist_ok=True)
    elif not temp.is_dir():p.error('Сначала явно prepare_sql.py --download')
    env=dict(os.environ,TEMP=str(temp),TMP=str(temp),TMPDIR=str(temp),NVIM_LOG_FILE=str(temp/'nvim.log'),
             GOTOOLCHAIN='local',GOENV='off',GOCACHE=str(out/'go-build'),GOMODCACHE=str(out/'go-mod'),
             GOTMPDIR=str(temp),GOPATH=str(out/'go'),CGO_ENABLED='1')
    # Изолируем также LSP/stdpath лог, а не только core NVIM_LOG_FILE.
    env['NVIM_APPNAME']='forge_sql_prepare'
    for name in ['HOME','USERPROFILE','LOCALAPPDATA','APPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME']:
        env[name]=str(temp/name.lower())
        if args.download:Path(env[name]).mkdir(exist_ok=True)
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
    if not args.download and previous.get('source_sha256')!=sha(SOURCE):p.error('Sources изменились, нужна явная подготовка')
    suffix='.exe' if os.name=='nt' else ''
    build_context=previous.get('build_context',{})
    for name in ['sqls','sqruff']:
        spec=sources['platforms'][key][name];target=bin_dir/(name+suffix)
        if spec.get('source_build'):
            archive=fetch(sources['sqls_source'])
            if args.download:
                directory=out/'src/sqls';unpack(archive,directory)
                work=next(directory.glob('*/go.mod')).parent
                go=args.go or shutil.which('go');cc=args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
                if not go or not cc:p.error('ARM64 sqls требует предоставленные Go >=1.25 и native C compiler')
                env['CC']=str(cc)
                go_version=run([go,'version'],capture_output=True,text=True).stdout.strip()
                found=re.search(r'go1\.(\d+)',go_version)
                if not found or int(found[1])<25:p.error('Нужен Go >=1.25; GOTOOLCHAIN=local, SDK не скачивается')
                run([go,'build','-mod=readonly','-trimpath','-ldflags','-s -w -X main.version=0.2.48 -X main.revision=7fcf633','-o',target,'.'],cwd=work)
                build_context['sqls']={'go':str(go),'version':go_version,'cc':str(cc),'source_sha256':sha(archive)}
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
    files={f.relative_to(out).as_posix():sha(f) for f in [parser,*bin_dir.iterdir()] if f.is_file()}
    if not args.download and (previous.get('files')!=files or previous.get('versions')!=versions):p.error('Payload/versions изменились; нужна явная подготовка')
    manifest={'source_sha256':sha(SOURCE),'platform':key,'versions':versions,'files':files,'build_context':build_context}
    if args.download:manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(('Prepared' if args.download else 'Ready')+' SQL tools: '+str(out))

if __name__=='__main__':main()
