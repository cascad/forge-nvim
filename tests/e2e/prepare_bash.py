"""Явная pinned подготовка Bash tools; host Bash/Node SDK не устанавливаются."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import urllib.error
import urllib.request

from prepare_rust import unpack

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'tests/e2e/bash-tools'
def sha(path):
    digest=hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):digest.update(chunk)
    return digest.hexdigest()

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download',action='store_true')
    p.add_argument('--output',type=Path,default=ROOT/'.tests/bash-deps')
    p.add_argument('--node-deps',type=Path,default=ROOT/'.tests/node-deps')
    p.add_argument('--bash')
    p.add_argument('--nvim',default=os.environ.get('FORGE_TEST_NVIM','nvim'))
    p.add_argument('--cc')
    args=p.parse_args();out=args.output.resolve()
    if os.name=='nt' and out.drive.lower()!=ROOT.drive.lower():p.error('Windows output/temp/build должны оставаться на диске checkout')
    sources=json.loads((SOURCE/'sources.json').read_text(encoding='utf-8'))
    key=('win32' if os.name=='nt' else platform.system().lower())+'-'+('arm64' if platform.machine().lower() in ('aarch64','arm64') else 'x64')
    if key not in sources['platforms']:p.error('Нет pinned tools для '+key)
    temp=out/'tmp'
    if args.download:temp.mkdir(parents=True,exist_ok=True)
    elif not temp.is_dir():p.error('Нужна явная подготовка --download')
    env=dict(os.environ,TEMP=str(temp),TMP=str(temp),TMPDIR=temp.as_posix(),npm_config_cache=str(out/'npm-cache'),
             npm_config_audit='false',npm_config_fund='false',npm_config_update_notifier='false')
    def run(command,**kwargs):
        if kwargs.get('text'):kwargs.setdefault('encoding','utf-8')
        return subprocess.run([str(x) for x in command],env=env,check=True,**kwargs)
    bash=args.bash
    if not bash and os.name=='nt':
        git=shutil.which('git')
        choices=[Path(git).parent.parent/'bin/bash.exe'] if git else []
        choices += [Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Git/bin/bash.exe']
        bash=next((str(v) for v in choices if v.is_file()),None)
    bash=bash or shutil.which('bash')
    if not bash:p.error('Нужен подготовленный native Bash; WSL/SDK автоматически не запускаются')
    bash=Path(bash).resolve()
    windows=Path(os.environ.get('WINDIR','C:/Windows'))
    if os.name=='nt' and str(bash).lower() in {str(windows/'System32/bash.exe').lower(),str(windows/'Sysnative/bash.exe').lower()}:
        p.error('WSL launcher не является native test Bash; укажи --bash <Git Bash>')
    version=run([bash,'--noprofile','--norc','--version'],capture_output=True,text=True).stdout.splitlines()[0]
    node_manifest=json.loads((args.node_deps/'manifest.json').read_text(encoding='utf-8'))
    node=(args.node_deps/node_manifest['node']).resolve()
    sdk=node.parent if os.name=='nt' else node.parent.parent
    npm=sdk/('node_modules/npm/bin/npm-cli.js' if os.name=='nt' else 'lib/node_modules/npm/bin/npm-cli.js')
    if not node.is_file() or not npm.is_file():p.error('Сначала явно подготовь Node SDK: prepare_node.py --download')
    manifest_path=out/'manifest.json'
    previous=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.is_file() else {}
    locks={name:sha(SOURCE/name) for name in ['package-lock.json','sources.json']}
    if not args.download and (previous.get('locks')!=locks or previous.get('bash')!=str(bash)):p.error('Нужна явная подготовка --download для этого lock/Bash')
    env['PATH']=str(node.parent)+os.pathsep+env['PATH']
    tools=out/'tools'
    if args.download:
        tools.mkdir(exist_ok=True)
        for name in ['package.json','package-lock.json']:shutil.copyfile(SOURCE/name,tools/name)
        for name in ['user','global']:
            config=temp/(name+'.npmrc');config.write_text('',encoding='utf-8')
            env['NPM_CONFIG_'+name.upper()+'CONFIG']=str(config)
        run([node,npm,'ci','--ignore-scripts','--no-audit','--no-fund'],cwd=tools)
    def fetch(spec):
        target=out/'archives'/spec['archive']
        if not target.is_file():
            if not args.download:p.error('Нет archive: '+target.name)
            target.parent.mkdir(exist_ok=True)
            for attempt in range(3):
                url=spec['url']+('?download='+str(attempt) if attempt else '')
                try:
                    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'forge-nvim-e2e'}),timeout=60) as response:
                        target.write_bytes(response.read())
                    break
                except urllib.error.HTTPError as error:
                    if error.code<500 or attempt==2:raise
                    print('Retry official archive HTTP '+str(error.code),flush=True)
        if sha(target)!=spec['sha256']:p.error('SHA не совпал: '+target.name)
        return target
    suffix='.exe' if os.name=='nt' else ''
    bin_dir=out/'bin';unit=out/'bats/bats-core-1.14.0/bin/bats'
    for name in ['shfmt','shellcheck']:
        archive=fetch(sources['platforms'][key][name]);target=bin_dir/(name+suffix)
        if args.download:
            bin_dir.mkdir(exist_ok=True)
            if name=='shfmt':shutil.copyfile(archive,target)
            else:
                directory=out/'shellcheck';unpack(archive,directory)
                files=list(directory.rglob('shellcheck'+suffix));assert len(files)==1
                shutil.copyfile(files[0],target)
            if os.name!='nt':target.chmod(0o755)
        if not target.is_file():p.error('Отсутствует '+name)
    archive=fetch(sources['bats'])
    if args.download:unpack(archive,out/'bats')
    grammar=sources['grammar']
    catalog=Path(os.environ.get('FORGE_E2E_DEPS',ROOT/'.tests/editor-deps'))/'lazy/nvim-treesitter/lua/nvim-treesitter/parsers.lua'
    match=re.search(r"\n  bash = \{\s+install_info = \{\s+revision = '([^']+)'",catalog.read_text(encoding='utf-8'))
    if not match or match[1]!=grammar['revision']:p.error('Grammar не соответствует pinned catalog')
    archive=fetch(grammar);parser=out/'site/parser/bash.so'
    if args.download:
        directory=out/'src'/grammar['revision'];unpack(archive,directory)
        src=next(directory.glob('*/src/parser.c')).parent
        cc=args.cc or os.environ.get('CC') or shutil.which('cc') or shutil.which('clang') or shutil.which('gcc')
        if not cc:p.error('Нужен C compiler для Bash parser')
        build=out/'build/parser';build.mkdir(parents=True,exist_ok=True)
        run([cc,'-O2','-shared',*([] if os.name=='nt' else ['-fPIC']),'-I',src,src/'parser.c',src/'scanner.c','-o',build/parser.name])
        parser.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(build/parser.name,parser)
    lua='vim.opt.rtp={'+json.dumps((out/'site').as_posix())+",vim.env.VIMRUNTIME};assert(#vim.api.nvim_get_runtime_file('parser/bash.*',true)==1);vim.treesitter.language.add('bash');assert(vim.treesitter.get_string_parser('answer=42','bash'):parse()[1]:root():type()=='program')"
    run([args.nvim,'--headless','-u','NONE','-i','NONE','+lua '+lua,'+qa'])
    versions={'bash':version,'node':run([node,'--version'],capture_output=True,text=True).stdout.strip(),
              'shfmt':run([bin_dir/('shfmt'+suffix),'--version'],capture_output=True,text=True).stdout.strip(),
              'shellcheck':run([bin_dir/('shellcheck'+suffix),'--version'],capture_output=True,text=True).stdout.strip(),
              'bats':run([bash,'--noprofile','--norc',unit.as_posix(),'--version'],capture_output=True,text=True).stdout.strip()}
    assert versions['node']=='v24.11.0' and sources['versions']['shfmt'] in versions['shfmt']
    assert sources['versions']['shellcheck'] in versions['shellcheck'] and sources['versions']['bats'] in versions['bats']
    entry=tools/'node_modules/bash-language-server/out/cli.js'
    assert json.loads((entry.parent.parent/'package.json').read_text(encoding='utf-8'))['version']==sources['versions']['language_server']
    files={str(f.relative_to(out)):sha(f) for f in [parser,*bin_dir.iterdir(),*tools.rglob('*'),*(out/'bats').rglob('*')]
           if f.is_file() and '__pycache__' not in f.parts}
    host={str(bash):sha(bash),str(node):sha(node)}
    if not args.download and (previous.get('files')!=files or previous.get('host_files')!=host):p.error('Payload/host files изменились; нужна явная подготовка')
    manifest={'bash':str(bash),'node':str(node),'versions':versions,'locks':locks,'files':files,'host_files':host}
    if args.download:manifest_path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('Prepared Bash workflow tools: '+str(out),flush=True)

if __name__=='__main__':main()
