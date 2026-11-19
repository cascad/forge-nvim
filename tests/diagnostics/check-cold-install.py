"""IDE-138: real cold Ubuntu Default. Requires explicitly prepared native IDE artifacts."""
import argparse,hashlib,io,json,os
from pathlib import Path
import shutil,subprocess,tarfile,time

ROOT=Path(__file__).resolve().parents[2]
IMAGE='ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--artifacts',type=Path,required=True,help='core.tar.gz, terminal.tar.gz, native fride-setup + frontend-manifest.json')
parser.add_argument('--publisher-container',required=True,help='Owned fride.owner=cold-publisher container with artifacts mounted at /artifacts')
parser.add_argument('--nvim',type=Path,default=ROOT/'.tools/neovim/windows-x64/bin/nvim.exe' if os.name=='nt' else shutil.which('nvim'))
parser.add_argument('--keep',action='store_true',help='Keep only this owned target for diagnosis; never changes Docker Desktop/WSL')
args=parser.parse_args()
artifacts=args.artifacts.resolve();nvim=args.nvim.resolve()
assert artifacts.is_relative_to(ROOT/'.tests') and nvim.is_file(),'Owned artifacts and prepared native test Neovim required'
for name in ('core.tar.gz','terminal.tar.gz','fride-setup','frontend-manifest.json'):assert (artifacts/name).is_file(),name
digest=lambda raw:hashlib.sha256(raw).hexdigest()
manifest=json.loads((artifacts/'frontend-manifest.json').read_text())
assert manifest['platform']=='linux-x64' and digest((artifacts/'fride-setup').read_bytes())==manifest['sha256']
for name,expected in manifest['sources'].items():assert digest((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==expected,name
base=ROOT/'.tests/cold-install'/str(time.time_ns());base.mkdir(parents=True)
env=os.environ.copy();tmp=base/'tmp';tmp.mkdir()
env.update(TEMP=str(tmp),TMP=str(tmp),TMPDIR=str(tmp),NVIM_LOG_FILE=str(tmp/'nvim.log'),PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1')

def run(command,label,timeout=180,check=True):
    started=time.monotonic()
    with (base/(label+'.log')).open('w',encoding='utf-8') as log:
        result=subprocess.run(list(map(str,command)),cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
    (base/(label+'.json')).write_text(json.dumps({'command':list(map(str,command)),'exit':result.returncode,'seconds':time.monotonic()-started},ensure_ascii=False),encoding='utf-8')
    if check:assert result.returncode==0,str(base/(label+'.log'))
    return result.returncode

def inspect(identity,owner):
    data=json.loads(subprocess.check_output(['docker','inspect',identity]))[0]
    assert data['Id'].startswith(identity) and data['Config']['Labels'].get('fride.owner')==owner,'Own container identity required'
    return data

publisher=inspect(args.publisher_container,'cold-publisher');publisher_id=publisher['Id']
url='http://'+publisher['NetworkSettings']['IPAddress']+':8765'
run(['docker','exec','-d',publisher_id,'python3','-B','-m','http.server','8765','--directory','/artifacts'],'publisher-http')
files=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().strip('\0').split('\0')
replacements={'installer-ui/artifacts.tsv':f'linux-x64\t{url}/fride-setup\t{digest((artifacts/"fride-setup").read_bytes())}\n'.encode(),
 'scripts/runtime/artifacts.tsv':''.join(f'linux-x64\t{name}\t{url}/{name}.tar.gz\t{digest((artifacts/(name+".tar.gz")).read_bytes())}\n' for name in ('core','terminal')).encode()}
with tarfile.open(artifacts/'source.tar.gz','w:gz') as archive:
    for name in files:
        file=ROOT/name
        if not file.is_file():continue
        raw=replacements.get(name,file.read_bytes());info=tarfile.TarInfo('forge-main/'+name);info.mode=file.stat().st_mode&0o777;info.size=len(raw)
        archive.addfile(info,io.BytesIO(raw))
(artifacts/'entry.sh').write_bytes((ROOT/'install.sh').read_bytes())
(base/'inputs.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD']).decode().strip(),
 'image':IMAGE,'publisher':publisher_id,'url':url,'artifacts':{name:digest((artifacts/name).read_bytes()) for name in ('core.tar.gz','terminal.tar.gz','fride-setup','source.tar.gz','entry.sh')}},indent=2))
name='fride-cold-'+base.name
command=['docker','run','-d','--rm','--init','--name',name,'--label','fride.owner=cold-default','--cpus','2','--memory','3g',
 '--mount',f'type=bind,source={base},target=/stand','--env','HOME=/root','--env','TERM=xterm-256color',
 '--env','TEMP=/stand/tmp','--env','TMP=/stand/tmp','--env','TMPDIR=/stand/tmp','--env','NVIM_LOG_FILE=/stand/tmp/nvim.log',
 '--env','XDG_CONFIG_HOME=/stand/profile/config','--env','XDG_DATA_HOME=/stand/profile/data',
 '--env','XDG_STATE_HOME=/stand/profile/state','--env','XDG_CACHE_HOME=/stand/profile/cache',
 '--env','GOMAXPROCS=2','--env','CARGO_BUILD_JOBS=2','--env','RAYON_NUM_THREADS=2','--env','GIT_TERMINAL_PROMPT=0',IMAGE,'sleep','infinity']
container=subprocess.check_output(command,env=env,text=True).strip()
(base/'container.json').write_text(json.dumps({'id':container,'name':name,'owner':'cold-default'}))
print('Cold stand:',base,'container:',container,flush=True)
code=1
try:
    inspect(container,'cold-default')
    run(['docker','exec',container,'bash','-c','apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl'],'transport',600)
    # Same signed Ubuntu repositories; avoid the environment's stalled plain HTTP.
    run(['docker','exec',container,'sed','-i','s|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g','/etc/apt/sources.list.d/ubuntu.sources'],'transport-https')
    baseline='''set -eu
for tool in git nvim go rustc cargo python3 node npm cargo-nextest; do
 if command -v "$tool"; then printf 'Unexpected preinstalled SDK/tool: %s\n' "$tool"; exit 1; fi
done
test ! -e /root/.cargo; test ! -e /root/.rustup; test ! -e /stand/installed
test ! -e /stand/profile/data; test ! -e /stand/profile/cache
dpkg-query -W; printf '\nCOLD_BASELINE_OK\n'
'''
    run(['docker','exec',container,'bash','-c',baseline],'baseline')
    run(['docker','exec',container,'curl','--fail','--silent','--show-error',url+'/entry.sh','-o','/stand/entry.sh'],'entry-download')
    command=['docker','exec','-it',container,'bash','/stand/entry.sh','--archive-url',url+'/source.tar.gz',
        '--source-root','/stand/source','--install-dir','/stand/installed','--go-toolchain-download','allow']
    env.update(FORGE_INSTALL_UI_COMMAND=json.dumps(command),FORGE_UI_SCENARIO='cold-default',
        FORGE_INSTALL_UI_REPORT=str(base/'ui.json'),FORGE_UI_WAIT_MS='600000',FORGE_UI_EXIT_MS='900000')
    code=run([nvim,'-u','NONE','-i','NONE','-l',ROOT/'tests/diagnostics/install-ui-pty.lua'],'install-ui',1500,False)
    run(['docker','exec',container,'bash','-c','dpkg-query -W; for t in git go rustc cargo python3 node npm; do command -v "$t" || true; done'],'after',check=False)
    if code==0:
        run(['docker','exec',container,'bash','-c','test -f /stand/installed/.forge-install.json; cat /stand/installed/.forge-install.json'],'ready-marker')
        run(['docker','exec',container,'bash','-c','for tool in go rustc cargo python3 node npm; do if command -v "$tool"; then exit 1; fi; done; test ! -e /root/.cargo; test ! -e /root/.rustup; printf "DEFERRED_SDK_BASELINE_OK\\n"'],'deferred-baseline')
        run(['docker','exec',container,'bash','/stand/installed/bin/fride','--headless','-i','NONE','-c','qa!'],'first-launch',120)
    print('Cold install exit:',code,'evidence:',base,flush=True)
finally:
    if not args.keep:
        inspect(container,'cold-default');run(['docker','stop','--timeout','10',container],'target-stop',30)
    else:print('Owned target kept for diagnosis:',container,flush=True)
raise SystemExit(code)
