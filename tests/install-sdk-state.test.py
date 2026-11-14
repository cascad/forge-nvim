"""IDE-BOOT-16: actual install/probes/launch; offline native SDK state writes.
Ready SDKs are read-only test inputs, not a complete distributable runtime.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('isolation',ROOT/'tests/install-isolation.test.py')
stand=importlib.util.module_from_spec(spec);spec.loader.exec_module(stand)
KEYS=['GOPATH','GOBIN','GOCACHE','GOMODCACHE','GOENV','CARGO_HOME','CARGO_INSTALL_ROOT','RUSTUP_HOME',
'npm_config_cache','npm_config_prefix','npm_config_userconfig','npm_config_globalconfig','PIP_CACHE_DIR','PIP_CONFIG_FILE',
'PYTHONUSERBASE','PYTHONPYCACHEPREFIX','PIP_TARGET','PIP_PREFIX','PIP_USER','HOME','VIRTUAL_ENV','CARGO_TARGET_DIR','RUSTFLAGS','PATH']
CAPTURE="local result={};for _,key in ipairs("+'{'+','.join(json.dumps(k) for k in KEYS)+'}'+") do result[key]=vim.env[key] end;vim.fn.writefile({vim.json.encode(result)},vim.env.FORGE_SDK_TRACE,'a')"
EXPECTED={'GOPATH':'sdk-state/go','GOBIN':'sdk-state/go/bin','GOCACHE':'cache/go-build','GOMODCACHE':'cache/go-mod','GOENV':'sdk-state/go/env',
'CARGO_HOME':'sdk-state/cargo','CARGO_INSTALL_ROOT':'sdk-state/cargo','RUSTUP_HOME':'sdk-state/rustup','npm_config_cache':'cache/npm',
'npm_config_prefix':'sdk-state/npm','npm_config_userconfig':'sdk-state/npm/user.npmrc','npm_config_globalconfig':'sdk-state/npm/global.npmrc',
'PIP_CACHE_DIR':'cache/pip','PIP_CONFIG_FILE':'sdk-state/python/pip.conf','PYTHONUSERBASE':'sdk-state/python/user','PYTHONPYCACHEPREFIX':'cache/python-bytecode'}

class SDKState(stand.Isolation):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        before=os.environ.get('FORGE_SDK_STATE_SOURCE')
        if before:
            for path in Path(before).iterdir():shutil.copy2(path,cls.source/'scripts'/path.name)
        with (cls.source/'nvim_forge/init.lua').open('a',encoding='utf-8') as file:file.write('\nif vim.env.FORGE_SDK_TRACE then '+CAPTURE+' end\n')
        manifest=cls.runtime/'forge-runtime.json';value=json.loads(manifest.read_text())
        value['probes'].append([value['nvim'],'--headless','-u','NONE','-i','NONE','-c','lua '+CAPTURE,'-c','qa!'])
        manifest.write_text(json.dumps(value),encoding='utf-8')
        cls.node_sdk=Path(os.environ.get('FORGE_E2E_NODE_DEPS',str(ROOT/'.tests/node-deps')))/'sdk'/('node-v24.11.0-'+('win' if stand.WINDOWS else ('darwin' if stand.PLATFORM.startswith('macos') else 'linux'))+'-'+stand.PLATFORM.split('-')[-1])
        cls.node=cls.node_sdk/('node.exe' if stand.WINDOWS else 'bin/node')
        cls.npm=cls.node_sdk/('node_modules/npm/bin/npm-cli.js' if stand.WINDOWS else 'lib/node_modules/npm/bin/npm-cli.js')
        rustc=os.environ.get('FORGE_SDK_TEST_RUSTC') or (str(Path(os.environ['USERPROFILE'])/'.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin/rustc.exe') if stand.WINDOWS else shutil.which('rustc'))
        sdk=Path(subprocess.check_output([rustc,'--print','sysroot'],env=dict(os.environ,RUSTUP_AUTO_INSTALL='0'),text=True).strip())
        cls.rustc=sdk/'bin'/('rustc.exe' if stand.WINDOWS else 'rustc');cls.cargo=sdk/'bin'/('cargo.exe' if stand.WINDOWS else 'cargo')
        cls.rustup=shutil.which('rustup');cls.go=shutil.which('go')
        assert cls.node.is_file() and cls.npm.is_file() and cls.rustup and cls.go,'Prepared SDK inputs required, no downloads'

    def prepared(self,name):
        base,env,target=self.prepare(name)
        external=base/'external-sdk';external.mkdir()
        for key in EXPECTED:
            path=external/key;path.mkdir();(path/'keep').write_text('owner state')
            env[key]=str(path)
        for key in ['GOENV','npm_config_userconfig','npm_config_globalconfig','PIP_CONFIG_FILE']:
            path=external/(key+'.config');path.write_text('owner config\n');env[key]=str(path)
        env.update(NPM_CONFIG_PREFIX=str(external/'upper-prefix'),NPM_CONFIG_CACHE=str(external/'upper-cache'),
            NPM_CONFIG_USERCONFIG=env['npm_config_userconfig'],NPM_CONFIG_GLOBALCONFIG=env['npm_config_globalconfig'],
            PIP_TARGET=str(external/'pip-target'),PIP_PREFIX=str(external/'pip-prefix'),PIP_USER='1',
            APPDATA=str(base/'os-roaming'),FORGE_SDK_TRACE=str(base/'sdk-env.jsonl'),
            VIRTUAL_ENV=str(base/'project/venv'),CARGO_TARGET_DIR=str(base/'project/target'),RUSTFLAGS='-C opt-level=0')
        # Native Windows OS/PowerShell bookkeeping also stays in the stand.
        before=stand.snapshot(external);self.addCleanup(lambda:self.assertEqual(stand.snapshot(external),before,'Existing SDK state changed'))
        (base/'project').mkdir()
        node_bin=self.node.parent
        env['PATH']=str(node_bin)+os.pathsep+env['PATH']
        return base,env,target

    def assert_scope(self,base,env,target):
        values=[json.loads(line) for line in (base/'sdk-env.jsonl').read_text(encoding='utf-8').splitlines()]
        self.assertGreaterEqual(len(values),5,'Probe/setup/launch were not all observed')
        for value in values:
            for key,relative in EXPECTED.items():self.assertEqual(Path(value[key]).resolve(),(target/relative).resolve(),key)
            for key in ['PIP_TARGET','PIP_PREFIX','PIP_USER']:self.assertFalse(value.get(key),key)
            for key in ['HOME','VIRTUAL_ENV','CARGO_TARGET_DIR','RUSTFLAGS']:self.assertEqual(value[key],env[key],key)
            paths=value['PATH'].split(os.pathsep)
            for relative in ['sdk-state/go/bin','sdk-state/cargo/bin','sdk-state/npm' if stand.WINDOWS else 'sdk-state/npm/bin']:
                self.assertIn(str(target/relative).replace('\\','/').lower(),[p.replace('\\','/').lower() for p in paths])

    def installed(self,name):
        base,env,target=self.prepared(name);self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target))
        self.assert_scope(base,env,target);return base,env,target

    def action(self,name,action):
        base,env,target=self.installed(name);project=base/'project'
        request={'action':action,'project':str(project),'go':self.go,'cargo':str(self.cargo),'rustc':str(self.rustc),
                 'rustup':self.rustup,'node':str(self.node),'npm':str(self.npm),'python':sys.executable}
        if action=='rust':
            (project/'src').mkdir();(project/'Cargo.toml').write_text('[package]\nname="forge_sdk_state_bin"\nversion="0.1.0"\nedition="2021"\n')
            (project/'src/main.rs').write_text('fn main(){println!("private cargo bin");}\n')
        elif action=='node':
            package={'name':'forge-sdk-state-node','version':'1.0.0','bin':{'forge-sdk-state-node':'index.js'}}
            archive=project/'node-package.tgz'
            with tarfile.open(archive,'w:gz') as arc:
                for name,data in [('package/package.json',json.dumps(package).encode()),('package/index.js',b'#!/usr/bin/env node\nconsole.log("private npm bin")\n')]:
                    info=tarfile.TarInfo(name);info.size=len(data);info.mode=0o755;arc.addfile(info,io.BytesIO(data))
            request['archive']=str(archive)
        elif action=='python':
            if importlib.util.find_spec('pip') is None:
                python_deps=Path(os.environ.get('FORGE_E2E_PYTHON_DEPS',str(ROOT/'.tests/python-deps')))
                pip_sources=sorted(python_deps.glob('venvs/*/lib/python*/site-packages/pip/__init__.py'))
                assert pip_sources,'Prepared pip module required; stand never installs system pip'
                request['pip_path']=str(pip_sources[0].parent.parent)
            archive=project/'forge_sdk_state_probe-1.0.0-py3-none-any.whl'
            with zipfile.ZipFile(archive,'w') as arc:
                arc.writestr('forge_sdk_state_probe.py','VALUE = "private userbase"\n')
                arc.writestr('forge_sdk_state_probe-1.0.0.dist-info/METADATA','Metadata-Version: 2.1\nName: forge-sdk-state-probe\nVersion: 1.0.0\n')
                arc.writestr('forge_sdk_state_probe-1.0.0.dist-info/WHEEL','Wheel-Version: 1.0\nGenerator: forge-test\nRoot-Is-Purelib: true\nTag: py3-none-any\n')
                arc.writestr('forge_sdk_state_probe-1.0.0.dist-info/RECORD','')
            request['archive']=str(archive)
        (base/'request.json').write_text(json.dumps(request),encoding='utf-8')
        env.update(FORGE_SDK_REQUEST=str(base/'request.json'),FORGE_SDK_RESULT=str(base/'operation.json'))
        command=([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(target/'bin/fride.ps1')] if stand.WINDOWS else [stand.SHELL,str(target/'bin/fride')])
        self.assert_ok(self.run_process(command+['--headless','-u','NONE','-i','NONE','-l',str(ROOT/'tests/diagnostics/sdk-state-actor.lua')],env,base,'operation-driver'))
        return base,env,target,json.loads((base/'operation.json').read_text(encoding='utf-8'))

    def test_01_probes_setup_launch_scope(self):self.installed('scope')
    def test_02_repeat_preserves_config(self):
        base,env,target=self.installed('repeat-state');files={'sdk-state/go/env':'GOPRIVATE=owner.invalid\n','sdk-state/npm/user.npmrc':'fund=false\n','sdk-state/python/pip.conf':'[global]\ndisable-pip-version-check=true\n','sdk-state/cargo/credentials.toml':'fixture opaque owner state\n'}
        for relative,data in files.items():(target/relative).write_text(data)
        self.assert_ok(self.install(base,env,target));self.assert_ok(self.launch(base,env,target));self.assert_scope(base,env,target)
        for relative,data in files.items():self.assertEqual((target/relative).read_text(),data)
    def test_03_go_state(self):
        base,_,target,proof=self.action('go-state','go');value=json.loads(proof[0]['stdout'])
        self.assertEqual(Path(value['GOENV']).resolve(),(target/'sdk-state/go/env').resolve());self.assertIn('GOPRIVATE=forge-state.invalid',(target/'sdk-state/go/env').read_text())
    def test_04_cargo_rustup_state(self):
        base,_,target,proof=self.action('rust-state','rust');self.assertEqual(Path(proof[0]['stdout'].strip()).resolve(),(target/'sdk-state/rustup').resolve())
        self.assertIn('minimal',(target/'sdk-state/rustup/settings.toml').read_text());self.assertIn('private cargo bin',proof[-1]['stdout'])
        bookkeeping=base/'foreign/AppData/Local/Microsoft/Windows/INetCache/IE/container.dat'
        if bookkeeping.exists():
            self.assertEqual(bookkeeping.stat().st_size,0)
            (base/'os-bookkeeping.json').write_text(json.dumps({'path':str(bookkeeping),'bytes':0,'sha256':hashlib.sha256(bookkeeping.read_bytes()).hexdigest()},indent=2))
    def test_05_npm_global_state(self):
        base,_,target,proof=self.action('node-state','node');self.assertEqual(Path(proof[0]['stdout'].strip()).resolve(),(target/'sdk-state/npm').resolve());self.assertIn('private npm bin',proof[-1]['stdout'])
    def test_06_python_user_state(self):
        base,_,target,proof=self.action('python-state','python');self.assertTrue(Path(proof[-1]['stdout'].strip()).resolve().is_relative_to((target/'sdk-state/python/user').resolve()))

    @unittest.skipUnless(stand.WINDOWS,'Stateful PowerShell caller environment')
    def test_07_caller_environment(self):
        base,env,target=self.installed('caller-environment')
        wrapper=base/'caller.ps1'
        keys='@('+','.join("'"+key+"'" for key in KEYS)+')'
        wrapper.write_text("param([string]$Launcher,[string]$Report)\n$keys="+keys+"\n$before=@{};foreach($key in $keys){$before[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}\n& $Launcher --headless -i NONE -c 'cquit 7'\n$exitCode=$LASTEXITCODE\n$after=@{};foreach($key in $keys){$after[$key]=[Environment]::GetEnvironmentVariable($key,'Process')}\n[IO.File]::WriteAllText($Report,(@{before=$before;after=$after;exit=$exitCode}|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))\nif($exitCode -ne 7){exit 1}\n",encoding='utf-8')
        self.assert_ok(self.run_process([stand.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(wrapper),'-Launcher',str(target/'bin/fride.ps1'),'-Report',str(base/'caller.json')],env,base,'caller-driver'))
        proof=json.loads((base/'caller.json').read_text(encoding='utf-8'));self.assertEqual(proof['exit'],7);self.assertEqual(proof['before'],proof['after'])

if __name__=='__main__':
    print('work:',stand.BASE,'artifacts:',stand.ARTIFACTS,flush=True)
    suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:],sys.modules[__name__]) if len(sys.argv)>1 else unittest.TestSuite(SDKState(name) for name in sorted(SDKState.__dict__) if name.startswith('test_'))
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (stand.BASE/'sdk-state-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'platform':stand.PLATFORM,'source':os.environ.get('FORGE_SDK_STATE_SOURCE','current')},indent=2))
    if stand.BASE!=stand.ARTIFACTS:
        def ignore(directory,names):return [n for n in names if n in ('runtime','prepared','.runtime-cache') or n.endswith(('.zip','.tar.gz')) or (Path(directory)/n).is_symlink()]
        shutil.copytree(stand.BASE,stand.ARTIFACTS,ignore=ignore)
    raise SystemExit(0 if result.wasSuccessful() else 1)
