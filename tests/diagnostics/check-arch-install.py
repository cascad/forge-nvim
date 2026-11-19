"""IDE-BOOT-53: explicit Arch Default/Core/repeat acceptance; requires prepared artifacts."""
import argparse,atexit,hashlib,json,os,subprocess,tarfile,time
from pathlib import Path,PurePosixPath

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--artifacts',type=Path,required=True)
parser.add_argument('--publisher-container',help='Reuse an exact owned publisher; otherwise create and remove a private test publisher')
parser.add_argument('--publisher-image',default='forge-nvim-tests:ubuntu24.04-nvim0.12.2',help='Prepared local Linux test image with Python; never starts Docker Desktop/WSL')
parser.add_argument('--publisher-prefix',default='omarchy')
parser.add_argument('--nvim',type=Path)
parser.add_argument('--report-dir',type=Path)
parser.add_argument('--resume',type=Path,help='Continue postchecks of an existing kept own cold stand with the same frontend input')
parser.add_argument('--keep',action='store_true')
args=parser.parse_args()
base=args.resume.resolve() if args.resume else args.report_dir.resolve() if args.report_dir else ROOT/'.tests/omarchy'/('acceptance-'+str(time.time_ns()))
assert base.is_relative_to(ROOT/'.tests') and (base.exists() if args.resume else not base.exists()),'Owned report directory required'
base.parent.mkdir(parents=True,exist_ok=True)
own_publisher=None
if not args.publisher_container:
 artifacts=args.artifacts.resolve()
 assert artifacts.is_relative_to(ROOT/'.tests') and artifacts.is_dir(),'Prepared owned artifacts required'
 assert artifacts.name==args.publisher_prefix,'Artifact directory must match --publisher-prefix'
 for name in ('core.tar.gz','terminal.tar.gz','fride-setup','frontend-manifest.json'):assert (artifacts/name).is_file(),name
 ready=subprocess.run(['docker','image','inspect',args.publisher_image],capture_output=True)
 assert ready.returncode==0,'Prepare the local Ubuntu test image: docker compose -f tests/containers/compose.yaml build ubuntu'
 own_publisher=subprocess.check_output(['docker','run','--detach','--rm','--init','--pull=never','--cpus','2','--memory','3g',
  '--label','fride.owner=cold-publisher','--mount','type=bind,source='+str(artifacts.parent)+',target=/artifacts',
  '--entrypoint','sleep',args.publisher_image,'infinity'],text=True).strip()
 args.publisher_container=own_publisher
 def release_publisher():
  state=json.loads(subprocess.check_output(['docker','inspect',own_publisher]))[0]
  assert state['Id']==own_publisher and state['Config']['Labels']['fride.owner']=='cold-publisher'
  base.mkdir(parents=True,exist_ok=True)
  (base/'publisher.json').write_text(json.dumps({'id':own_publisher,'owner':'cold-publisher','image':args.publisher_image,'kept':args.keep}))
  if not args.keep:subprocess.run(['docker','stop','--timeout','10',own_publisher],check=True,timeout=30,stdout=subprocess.DEVNULL)
 atexit.register(release_publisher)
command=[os.sys.executable,'-B',str(ROOT/'tests/diagnostics/check-cold-install.py'),'--os','arch','--artifacts',str(args.artifacts),
 '--publisher-container',args.publisher_container,'--publisher-prefix',args.publisher_prefix,'--report-dir',str(base),'--keep']
if args.nvim:command+=['--nvim',str(args.nvim)]
started=time.monotonic()
if args.resume:
 inputs=json.loads((base/'inputs.json').read_text())
 assert hashlib.sha256((args.artifacts/'fride-setup').read_bytes()).hexdigest()==inputs['artifacts']['fride-setup'],'Resume requires the same frontend input'
 assert 'DEFERRED_SDK_BASELINE_OK' in (base/'deferred-baseline.log').read_text()
 result=subprocess.CompletedProcess(command,0)
else:result=subprocess.run(command,cwd=ROOT)
metadata=base/'container.json';identity=None
def inspect():
 data=json.loads(subprocess.check_output(['docker','inspect',identity]))[0]
 assert data['Id']==identity and data['Config']['Labels']['fride.owner']=='cold-default'
 return data
def run(argv,name,timeout=300):
 with (base/(name+'.log')).open('w',encoding='utf-8') as log:
  result=subprocess.run(argv,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 assert result.returncode==0,name+' failed; see '+str(base)
 print('PASS',name,flush=True)
try:
 assert result.returncode==0,'Cold Default failed; original evidence preserved'
 data=json.loads(metadata.read_text());identity=data['id'];inspect()
 work,kit,profile=data['workdir'],data['kit'],data['profile']
 source=data['source']+'/'+json.loads((base/'inputs.json').read_text())['artifacts']['source.tar.gz']
 # Test-harness updates are recorded separately; deployed product config is untouched.
 helpers={}
 for name in ('tests/install-core-acceptance.test.py','tests/diagnostics/install-core-observe.lua','tests/diagnostics/install-preservation-observe.lua'):
  helpers[name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
  run(['docker','cp',str(ROOT/name),identity+':'+source+'/'+name],'copy-'+Path(name).stem)
 (base/'postcheck-inputs.json').write_text(json.dumps({'cold_source':source,'helpers':helpers},indent=2))
 # Python is only an explicit test harness AFTER the no-SDK Default proof.
 run(['docker','exec',identity,'pacman','-S','--needed','--noconfirm','python'],'test-harness-python',300)
 run(['docker','exec',identity,'mkdir','-p',profile+'/home',profile+'/local',profile+'/tmp'],'test-profile-dirs')
 run(['docker','exec','-e','FORGE_CORE_TEST_ROOT='+work,identity,'python3','-B',source+'/tests/install-core-acceptance.test.py',
      '--kit',kit,'--profile',profile,'--profile-layout','stand'],'actual-core-workflow',600)
 # Existing ordinary SDK is created explicitly by the harness, after the cold
 # no-SDK baseline. It is not injected into Default or copied from a cache.
 existing_sdk=work+'/ordinary Python SDK'
 run(['docker','exec',identity,'python3','-m','venv','--without-pip',existing_sdk],'ordinary-sdk-test-preparation')
 native_path=next(value[5:] for value in inspect()['Config']['Env'] if value.startswith('PATH='))
 sdk_exec=['docker','exec','--env','PATH='+existing_sdk+'/bin:'+native_path,identity]
 custom=work+'/custom kit/nested path'
 run(sdk_exec+[kit+'/bin/fride-setup','--source',source,'--install-dir',custom,'--components','core',
      '--profile','default','--system-deps','check','--log-dir',work+'/custom-logs'],'custom-missing-path',600)
 run(['docker','exec',identity,'bash','-c','mkdir -p "$XDG_CONFIG_HOME/fride"; printf "USER_PREFERENCES_KEEP\\n" > "$XDG_CONFIG_HOME/fride/guard-preserve.txt"'],'preferences')
 observer=source+'/tests/diagnostics/install-preservation-observe.lua'
 run(sdk_exec+[kit+'/bin/fride','--headless','-i','NONE','-l',observer,kit,'/stand/preserve-before.json'],'preserve-before')
 run(sdk_exec+[kit+'/bin/fride-setup','--source',source,'--install-dir',kit,'--profile','default',
      '--system-deps','check','--log-dir',work+'/repeat-logs'],'repeat',600)
 run(sdk_exec+[kit+'/bin/fride','--headless','-i','NONE','-l',observer,kit,'/stand/preserve-after.json'],'preserve-after')
 assert json.loads((base/'preserve-before.json').read_text())==json.loads((base/'preserve-after.json').read_text()),'Repeat changed existing state'
 run(['docker','exec',identity,'sha256sum','--check','/stand/ordinary-before.sha256'],'ordinary-preserved-final')
 run(['docker','exec',identity,'bash',source+'/scripts/test-omarchy.sh','--kit',kit,'--project',work,'--output','/stand/native-info.json','--versions','--quick'],'native-report-and-quick',300)
 (base/'arch-result.json').write_text(json.dumps({'schema':1,'ready':True,'os':'arch','desktop':'not checked','seconds':time.monotonic()-started,
  'source':source,'kit':kit,'custom':custom,'image':json.loads((base/'inputs.json').read_text())['image'],'container':identity},indent=2))
 print('Arch CLI acceptance PASS; native Omarchy O1-O8 remain manual:',base,flush=True)
finally:
 if identity is None and metadata.exists():identity=json.loads(metadata.read_text())['id']
 if identity:
  inspect()
  # Small regular records only, excluding all SDK/runtime/plugin payloads.
  stream=subprocess.Popen(['docker','exec',identity,'tar','--ignore-failed-read','-C',work,'-cf','-','core-acceptance','custom-logs','repeat-logs','installed/log'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
  destination=base/'native-records';count=size=0
  with tarfile.open(fileobj=stream.stdout,mode='r|') as archive:
   for member in archive:
    path=PurePosixPath(member.name);assert not path.is_absolute() and '..' not in path.parts
    if not member.isfile() or member.size>4*1024*1024 or path.suffix not in ('.json','.log','.txt','.jsonl'):continue
    if any(part in ('project','config','runtime','lazy','mason','data','vendor') for part in path.parts):continue
    target=destination.joinpath(*path.parts);target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(archive.extractfile(member).read());count+=1;size+=member.size
    assert size<100*1024*1024
  error=stream.stderr.read().decode(errors='replace');code=stream.wait(timeout=30)
  (base/'export.json').write_text(json.dumps({'files':count,'bytes':size,'exit':code,'stderr':error}))
  if not args.keep:
   inspect();subprocess.run(['docker','stop','--timeout','10',identity],check=True,timeout=30)
  else:print('Kept exact own target:',identity,flush=True)
