"""IDE-BOOT-17: native install/launch and SDK queries; no SDK installation."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('isolation',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)
SDK_KEYS=['GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOENV','CARGO_HOME','CARGO_INSTALL_ROOT','RUSTUP_HOME',
 'npm_config_cache','npm_config_prefix','npm_config_userconfig','npm_config_globalconfig',
 'PIP_CACHE_DIR','PIP_CONFIG_FILE','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','PIP_TARGET','PIP_PREFIX','PIP_USER']
KEYS=SDK_KEYS+['HOME','USERPROFILE','VIRTUAL_ENV','CARGO_TARGET_DIR','RUSTFLAGS','PATH',
 'XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME']
CAPTURE="local v={};for _,k in ipairs({"+','.join(json.dumps(k) for k in KEYS)+"}) do v[k]=vim.env[k] end;v.app=vim.env.NVIM_APPNAME;v.data=vim.fn.stdpath('data');v.config=vim.env.FRIDE_CONFIG;vim.fn.writefile({vim.json.encode(v)},vim.env.FORGE_SDK_TRACE,'a')"

def put(env,key,value=None):
    for existing in list(env):
        if (existing.lower()==key.lower() if stand.WINDOWS else existing==key):del env[existing]
    if value is not None:env[key]=value

class SDKState(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        if before:=os.environ.get('FORGE_SDK_STATE_SOURCE'):
            for path in Path(before).iterdir():shutil.copy2(path,cls.source/'scripts'/path.name)
        for path in [cls.source/'nvim_forge/init.lua',cls.source/'nvim_forge/scripts/setup-stage.lua']:
            with path.open('a',encoding='utf-8') as file:file.write('\n'+CAPTURE+'\n')
        manifest=cls.runtime/'forge-runtime.json';value=json.loads(manifest.read_text())
        value['probes'].append([value['nvim'],'--headless','-u','NONE','-i','NONE','-c','lua '+CAPTURE,'-c','qa!'])
        manifest.write_text(json.dumps(value),encoding='utf-8')

    def prepared(self,name,defaults=False):
        base,env,target=self.prepare(name)
        # fride and SDK defaults may create files only in this controlled profile.
        profile=base/'native-profile';profile.mkdir(exist_ok=True)
        env.update(HOME=str(profile),USERPROFILE=str(profile),LOCALAPPDATA=str(profile/'local'),APPDATA=str(profile/'roaming'),
            XDG_CONFIG_HOME=str(profile/'config'),XDG_DATA_HOME=str(profile/'data'),
            XDG_STATE_HOME=str(profile/'state'),XDG_CACHE_HOME=str(profile/'cache'),
            FORGE_SDK_TRACE=str(base/'sdk-env.jsonl'),PYTHONDONTWRITEBYTECODE='1',
            VIRTUAL_ENV=str(base/'project/venv'),CARGO_TARGET_DIR=str(base/'project/target'),RUSTFLAGS='-C opt-level=0')
        for key in SDK_KEYS:put(env,key)
        if not defaults:
            external=base/'external-sdk';external.mkdir()
            configs={'GOENV':'GOPRIVATE=owner.invalid\n','npm_config_userconfig':'fund=false\n',
                'npm_config_globalconfig':'audit=false\n','PIP_CONFIG_FILE':'[global]\ndisable-pip-version-check=true\n'}
            for key in SDK_KEYS:
                if key=='PIP_USER':put(env,key,'1');continue
                value=external/key
                if key in configs:value.write_text(configs[key])
                else:value.mkdir();(value/'keep').write_text('owner state')
                put(env,key,str(value))
        put(env,'npm_config_update_notifier','false');put(env,'npm_config_logs_max','0')
        (base/'project').mkdir()
        return base,env,target

    def assert_scope(self,base,env,target):
        values=[json.loads(line) for line in (base/'sdk-env.jsonl').read_text(encoding='utf-8').splitlines()]
        self.assertGreaterEqual(len(values),8,'Probe/3 setup stages/init/launch not all observed')
        for value in values:
            for key in KEYS:
                if key!='PATH':self.assertEqual(value.get(key),env.get(key),key)
            paths=value['PATH'].split(os.pathsep);original=env['PATH'].split(os.pathsep)
            self.assertEqual(paths[1:1+len(original)],original,'Caller PATH order changed')
            # Neovim itself appends its executable directory on Windows.
            for path in paths[1+len(original):]:
                self.assertTrue(stand.WINDOWS and (Path(path).is_relative_to(target) or Path(path).is_relative_to(self.runtime)),path)
            self.assertNotIn('sdk-state',value['PATH']);self.assertEqual(value['app'],'fride')
            self.assertTrue(Path(value['data']).is_relative_to(Path(env['XDG_DATA_HOME'])))
        self.assertFalse((target/'sdk-state').exists())

    def installed(self,name,defaults=False):
        base,env,target=self.prepared(name,defaults)
        external=base/'external-sdk';before=stand.snapshot(external) if external.exists() else {}
        self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target))
        self.assert_scope(base,env,target)
        self.assertEqual(stand.snapshot(external) if external.exists() else {},before,'Setup/launch changed existing SDK state')
        return base,env,target

    def test_01_probes_setup_launch_scope(self):self.installed('scope')
    def test_02_defaults_remain_unset(self):self.installed('defaults',True)

    def test_03_repeat_preserves_legacy_state(self):
        base,env,target=self.installed('repeat')
        legacy=target/'sdk-state';legacy.mkdir();(legacy/'credentials.keep').write_text('legacy owner state')
        (target/'data').mkdir();(target/'data/keep').write_text('old IDE data')
        before=stand.snapshot(legacy);self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target))
        for value in [json.loads(line) for line in (base/'sdk-env.jsonl').read_text(encoding='utf-8').splitlines()]:
            for key in SDK_KEYS:self.assertEqual(value.get(key),env.get(key),key)
        self.assertEqual(stand.snapshot(legacy),before);self.assertEqual((target/'data/keep').read_text(),'old IDE data')
        self.assertFalse((target/'bin/sdk-environment.tsv').exists())

    def queries(self,base,env,target):
        node_sdk=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))/'sdk'/('node-v24.11.0-'+('win' if stand.WINDOWS else ('darwin' if stand.PLATFORM.startswith('macos') else 'linux'))+'-'+stand.PLATFORM.split('-')[-1])
        node=node_sdk/('node.exe' if stand.WINDOWS else 'bin/node')
        npm=node_sdk/('node_modules/npm/bin/npm-cli.js' if stand.WINDOWS else 'lib/node_modules/npm/bin/npm-cli.js')
        rustc=os.environ.get('FORGE_SDK_TEST_RUSTC') or (str(Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe') if stand.WINDOWS else shutil.which('rustc'))
        rustup=shutil.which('rustup');go=shutil.which('go')
        self.assertTrue(node.is_file() and npm.is_file() and rustc and rustup and go,'Prepared SDKs required')
        sysroot=subprocess.check_output([rustc,'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip()
        compiler=Path(sysroot)/'bin'/('rustc.exe' if stand.WINDOWS else 'rustc')
        python=shutil.which('python',path=env['PATH']) or sys.executable
        commands=[[go,'env','-json','GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOENV'],[rustup,'show','home'],
            [str(compiler),'--version'],[str(node),str(npm),'prefix','--global'],[str(node),str(npm),'config','get','userconfig'],
            [python,'-c','import json,sys,site;print(json.dumps(dict(exe=sys.executable,prefix=sys.prefix,base=sys.base_prefix,user=site.getuserbase())))']]
        env.update(GOTOOLCHAIN='local',GOPROXY='off',RUSTUP_AUTO_INSTALL='0')
        expected=[]
        for command in commands:
            result=self.run_process(command,env,base,'outside-'+str(len(expected)));self.assert_ok(result);expected.append(result.stdout.strip())
        (base/'request.json').write_text(json.dumps({'commands':commands,'project':str(base/'project')}),encoding='utf-8')
        env.update(FORGE_SDK_REQUEST=str(base/'request.json'),FORGE_SDK_RESULT=str(base/'operation.json'))
        launcher=([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        self.assert_ok(self.run_process(launcher+['--headless','-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/sdk-state-actor.lua')],env,base,'inside'))
        observed=json.loads((base/'operation.json').read_text(encoding='utf-8'))
        self.assertEqual([r['code'] for r in observed],[0]*len(commands));self.assertEqual([r['stdout'].strip() for r in observed],expected)
        return json.loads(expected[-1])

    def test_04_native_sdk_defaults(self):
        base,env,target=self.installed('native-defaults',True);self.queries(base,env,target)

    def test_05_native_sdk_settings_and_project_venv(self):
        base,env,target=self.installed('native-settings');venv=Path(env['VIRTUAL_ENV'])
        self.assert_ok(self.run_process([sys.executable,'-m','venv','--without-pip',str(venv)],env,base,'create-venv'))
        env['PATH']=str(venv/('Scripts' if stand.WINDOWS else 'bin'))+os.pathsep+env['PATH']
        python=self.queries(base,env,target)
        self.assertEqual(Path(python['prefix']).resolve(),venv.resolve());self.assertNotEqual(python['prefix'],python['base'])

    @unittest.skipUnless(stand.WINDOWS,'PowerShell caller restoration')
    def test_06_caller_environment(self):
        base,env,target=self.installed('caller');wrapper=base/'caller.ps1'
        keys=KEYS+['FRIDE_CONFIG','NVIM_APPNAME','NVIM_LOG_FILE','TEMP','TMP','TMPDIR']
        wrapper.write_text("param([string]$Launcher,[string]$Report)\n$keys=@("+','.join("'"+k+"'" for k in keys)+")\n$before=@{};foreach($k in $keys){$before[$k]=[Environment]::GetEnvironmentVariable($k,'Process')}\n& $Launcher --headless -i NONE -c 'cquit 7'\n$code=$LASTEXITCODE\n$after=@{};foreach($k in $keys){$after[$k]=[Environment]::GetEnvironmentVariable($k,'Process')}\n[IO.File]::WriteAllText($Report,(@{before=$before;after=$after;exit=$code}|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))\nif($code -ne 7){exit 1}\n",encoding='utf-8')
        self.assert_ok(self.run_process([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(wrapper),'-Launcher',str(target/'bin/fride.ps1'),'-Report',str(base/'caller.json')],env,base,'caller-driver'))
        value=json.loads((base/'caller.json').read_text(encoding='utf-8'));self.assertEqual(value['exit'],7);self.assertEqual(value['before'],value['after'])

    def test_07_native_lazy_keeps_kit_config(self):
        base,env,target=self.installed('native-lazy');config=target/'config/forge'
        (config/'lua/config').mkdir(parents=True)
        shutil.copy2(ROOT/'nvim_forge/lua/config/lazy.lua',config/'lua/config/lazy.lua')
        shutil.copy2(ROOT/'nvim_forge/lazy-lock.json',config/'lazy-lock.json')
        (config/'lua/forge_sdk_fixture.lua').write_text('return {loaded=true}\n')
        deps=Path(os.environ.get('FORGE_E2E_DEPS',str(ROOT/'.tests/editor-deps')))
        lazy=deps/'lazy/lazy.nvim';self.assertTrue((lazy/'lua/lazy/init.lua').is_file(),'Prepared Lazy required')
        before=(config/'lazy-lock.json').read_bytes()
        env.update(FORGE_SDK_LAZY=str(lazy),FORGE_SDK_RESULT=str(base/'lazy.json'))
        launcher=([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        self.assert_ok(self.run_process(launcher+['--headless','-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/sdk-lazy-actor.lua')],env,base,'lazy'))
        self.assertEqual((config/'lazy-lock.json').read_bytes(),before)
        self.assertTrue((base/'lazy.json').is_file())

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:],sys.modules[__name__]) if len(sys.argv)>1 else unittest.TestSuite(SDKState(name) for name in sorted(SDKState.__dict__) if name.startswith('test_'))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (stand.BASE/'sdk-state-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM,'source':os.environ.get('FORGE_SDK_STATE_SOURCE','current')},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
