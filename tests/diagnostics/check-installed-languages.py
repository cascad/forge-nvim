"""Explicit acceptance of existing language consumers in an owned installed kit.

No setup, SDK installation or source-config substitution is performed.
"""
import argparse,json,os
from pathlib import Path
import shutil,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--kit',type=Path,required=True)
parser.add_argument('--profile',type=Path,required=True)
parser.add_argument('--stand-root',type=Path,default=ROOT/'.tests')
parser.add_argument('--profile-layout',choices=['env','stand'],default='env')
parser.add_argument('--language',choices=['go','rust','python','node','bash','sql'])
parser.add_argument('--workflow',choices=['language','runtime'],default='language')
parser.add_argument('--output',type=Path)
args=parser.parse_args()
owned=args.stand_root.resolve();kit=args.kit.resolve();profile=args.profile.resolve()
assert kit.is_relative_to(owned) and profile.is_relative_to(owned),'Use an owned test kit/profile'
marker=json.loads((kit/'.forge-install.json').read_text(encoding='utf-8'))
assert marker.get('ready') and marker.get('product')=='forge-nvim' and 'core' in marker.get('components',[]),'Ready installed kit required'
assert args.workflow!='runtime' or args.language not in ('bash','sql'),'Runtime acceptance covers Go/Rust/Python/Node'
base=(args.output or owned/('installed-workflows' if args.workflow=='runtime' else 'installed-languages')/str(time.time_ns())).resolve()
assert base.is_relative_to(owned) and not base.exists(),'Use a new owned output directory'
base.mkdir(parents=True);project=base/'project';project.mkdir()
env=os.environ.copy();original_user=Path(env.get('USERPROFILE',env.get('HOME','')))
locations={'HOME':'home','USERPROFILE':'home','LOCALAPPDATA':'local','XDG_CONFIG_HOME':'config','XDG_DATA_HOME':'data','XDG_STATE_HOME':'state','XDG_CACHE_HOME':'cache'}
for name,relative in locations.items():
    path=profile/(relative if args.profile_layout=='stand' else name)
    assert path.is_dir(),'Prepared native profile path missing: '+str(path)
    env[name]=str(path)
if os.name=='nt':
    for key in list(env):
        if key.upper()=='PSMODULEPATH':env.pop(key)
for name in ('VIM','VIMRUNTIME','VIMINIT','EXINIT','LUA_INIT','LUA_PATH','LUA_CPATH','FRIDE_CONFIG','FRIDE_RUNTIME','FRIDE_SDK_BASE','FRIDE_SDK_PROJECT','FORGE_INSTALLED_LANGUAGE_CASE'):
    env.pop(name,None)
if args.language:env['FORGE_INSTALLED_LANGUAGE_CASE']=args.language
cache=owned/'installed-language-cache';cache.mkdir(exist_ok=True)
env.update(GOTOOLCHAIN='local',RUSTUP_AUTO_INSTALL='0',GOMAXPROCS='2',GOFLAGS='-p=2',GOWORK='off',
    GOCACHE=str(cache/'go'),GOMODCACHE=str(cache/'gomod'),GOPATH=str(cache/'gopath'),GOTELEMETRY='off',
    CARGO_BUILD_JOBS='2',CARGO_TARGET_DIR=str(cache/'cargo-target'),RAYON_NUM_THREADS='2',
    PSModuleAnalysisCachePath=str(base/'powershell-module-cache'),GIT_CONFIG_GLOBAL=str(base/'gitconfig'),GIT_CONFIG_NOSYSTEM='1',GIT_TERMINAL_PROMPT='0')
env.setdefault('RUSTUP_HOME',str(original_user/'.rustup'));env.setdefault('CARGO_HOME',str(original_user/'.cargo'))
(base/'gitconfig').write_text('')
subprocess.run(['git','init','-q',str(project)],env=env,check=True,capture_output=True)
launch=[shutil.which('powershell.exe'),'-NoProfile','-ExecutionPolicy','Bypass','-File',str(kit/'bin/fride.ps1')] if os.name=='nt' else ['bash',str(kit/'bin/fride')]
observer='install-workflow-observe.lua' if args.workflow=='runtime' else 'install-language-observe.lua'
command=launch+['--headless','-i','NONE','-l',str(ROOT/'tests/diagnostics'/observer),str(base)]
print('Installed '+args.workflow+' acceptance:',base,flush=True)
started=time.monotonic()
with (base/'process.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=800)
(base/'process.json').write_text(json.dumps({'exit':result.returncode,'seconds':round(time.monotonic()-started,2),'command':command},ensure_ascii=False,indent=2),encoding='utf-8')
print('Exit:',result.returncode,'seconds:',round(time.monotonic()-started,2),'report:',base/'observed/report.json',flush=True)
raise SystemExit(result.returncode)
