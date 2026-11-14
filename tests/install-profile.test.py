"""IDE-BOOT-10: HTTP/PTY selection и native policy, package handlers изолированы."""
import importlib.util
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('bootstrap',ROOT/'tests/install-bootstrap.test.py')
bootstrap=importlib.util.module_from_spec(spec);spec.loader.exec_module(bootstrap)
NVIM=str(ROOT/'.tools/neovim/windows-x64/bin/nvim.exe') if os.name=='nt' else shutil.which('nvim')

class Profile(bootstrap.Bootstrap):
    def selected(self,name,value,expected):
        key='Components' if bootstrap.WINDOWS else 'components'
        result,_,_,report=self.run_entry(name,options={key:value})
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=dict(line.split('=',1) for line in report.read_text(encoding='utf-8-sig').splitlines())
        self.assertEqual(data['components'].split(','),expected)
        return data['components']
    def policy(self,mask,name):
        folder=bootstrap.BASE/name;folder.mkdir(exist_ok=True)
        script=folder/'policy.lua'
        script.write_text("""local root=...;vim.opt.runtimepath={root..'/nvim_forge',vim.env.VIMRUNTIME};package.path=root..'/nvim_forge/lua/?.lua;'..package.path
local options;for _,s in ipairs(require('plugins.lsp')) do if s[1]=='WhoIsSethDaniel/mason-tool-installer.nvim' then options=s.opts() end end
local profile=require('forge.install_profile')
io.stdout:write(vim.json.encode({tools=options.ensure_installed,parsers=profile.filter({'LEGACY_PARSER'},5)}))
""".replace('local root=...','local root=arg[1]'),encoding='utf-8')
        env=os.environ.copy()
        if mask is None:env.pop('FORGE_NVIM_COMPONENTS',None)
        else:env['FORGE_NVIM_COMPONENTS']=mask
        result=subprocess.run([NVIM,'-u','NONE','-i','NONE','-l',str(script),str(ROOT)],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=20)
        (folder/'policy-result.json').write_text(json.dumps({'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},indent=2),encoding='utf-8')
        self.assertEqual(result.returncode,0,result.stderr)
        return json.loads(result.stdout)
    def test_10_core_only(self):
        mask=self.selected('core-only','core',['core'])
        policy=self.policy(mask,'core-only')
        self.assertEqual(policy['tools'],['lua-language-server'])
        self.assertFalse(set(policy['parsers']) & {'rust','go','python','javascript','typescript','bash','sql'})
    def test_11_python_dependency_without_js(self):
        mask=self.selected('python-only','python',['core','python','node-runtime'])
        policy=self.policy(mask,'python-only')
        self.assertIn('pyright',policy['tools']);self.assertIn('python',policy['parsers'])
        self.assertNotIn('typescript-language-server',policy['tools']);self.assertNotIn('javascript',policy['parsers'])
    def test_12_sql_dependency_without_go_tools(self):
        mask=self.selected('sql-only','sql',['core','sql','go-runtime'])
        policy=self.policy(mask,'sql-only')
        self.assertIn('sqls',policy['tools']);self.assertIn('sql',policy['parsers'])
        self.assertNotIn('delve',policy['tools']);self.assertNotIn('go',policy['parsers'])
    def test_13_empty_explicit_is_core(self):self.selected('empty','',['core'])
    def test_14_unknown_component(self):
        key='Components' if bootstrap.WINDOWS else 'components'
        result,_,target,report=self.run_entry('unknown',options={key:'oops'})
        self.assertNotEqual(result.returncode,0);self.assertIn('Unknown component',result.stdout+result.stderr)
        self.assertFalse(report.exists());self.assertFalse(target.exists())
    def test_15_legacy_catalog_unchanged(self):
        policy=self.policy(None,'legacy')
        self.assertEqual(policy['parsers'],['LEGACY_PARSER'])
        self.assertIn('rust-analyzer',policy['tools']);self.assertNotIn('js-debug-adapter',policy['tools'])
    def test_16_keyboard_toggle(self):
        key='Profile' if bootstrap.WINDOWS else 'profile'
        result,_,_,report=self.run_entry('keyboard',options={key:'Custom' if bootstrap.WINDOWS else 'custom'},ui_action='toggle')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=dict(line.split('=',1) for line in report.read_text(encoding='utf-8-sig').splitlines())
        self.assertIn('core',data['components'].split(','));self.assertNotIn('go',data['components'].split(','))
        self.assertIn('rust',data['components'].split(','))
        ui=json.loads((report.parent/'ui.json').read_text(encoding='utf-8'));self.assertTrue(ui['ok'])
    def test_17_keyboard_cancel(self):
        key='Profile' if bootstrap.WINDOWS else 'profile'
        result,_,target,report=self.run_entry('cancel',options={key:'Custom' if bootstrap.WINDOWS else 'custom'},ui_action='cancel')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr) # PTY observer подтвердил child exit1.
        self.assertFalse(target.exists());self.assertFalse(report.exists())
        ui=json.loads((target.parent/'ui.json').read_text(encoding='utf-8'));self.assertEqual(ui['exit'],1)
    def test_18_default_profile(self):
        result,_,_,report=self.run_entry('default-profile')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=dict(line.split('=',1) for line in report.read_text(encoding='utf-8-sig').splitlines())
        self.assertEqual(data['components'].split(','),['core','go','rust','python','node','bash','sql','terminal','node-runtime','go-runtime'])

    def package_plan(self,name,mask,failed_id=''):
        base=bootstrap.BASE/name;base.mkdir()
        repo=base/'checkout';profile=repo/'nvim_forge'
        (profile/'lua').mkdir(parents=True)
        shutil.copytree(ROOT/'nvim_forge/scripts',profile/'scripts')
        (profile/'init.lua').write_text('-- isolated package contract\n')
        (repo/'nvim_forge.sh').write_text('#!/bin/sh\n');(repo/'wezterm.lua').write_text('-- private\n')
        home=base/'home';home.mkdir();target=base/'new config/nvim';log=base/'packages.txt'
        env=os.environ.copy();env.update(HOME=str(home),LOCALAPPDATA=str(base/'localapp'),
          XDG_CONFIG_HOME=str(base/'ambient'),NVIM_APPNAME='other',FORGE_NVIM_COMPONENTS=mask,
          FORGE_NVIM_INSTALL_DIR=str(target),FORGE_NVIM_USE_LOCAL_SOURCE='1',FORGE_NVIM_SKIP_DEPS='0',
          FORGE_NVIM_SKIP_WEZTERM='1',FORGE_NVIM_DEPS_ONLY='0',FORGE_PROFILE_OPS=str(log),FORGE_PROFILE_FAIL=failed_id)
        if bootstrap.WINDOWS:
            wrapper=base/'package.ps1'
            wrapper.write_text(r'''param([string]$Installer,[string]$Target)
function winget {
 [IO.File]::AppendAllText($env:FORGE_PROFILE_OPS,($args -join ' ')+"`n")
 if ($args[0] -eq 'list') { $global:LASTEXITCODE=1 }
 elseif ($env:FORGE_PROFILE_FAIL -and $args -contains $env:FORGE_PROFILE_FAIL) { $global:LASTEXITCODE=7 }
 else { $global:LASTEXITCODE=0 }
}
function nvim { $global:LASTEXITCODE=0 }
. $Installer -UseLocalSource -InstallPath $Target
''',encoding='utf-8')
            args=[bootstrap.SHELL,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(wrapper),'-Installer',str(profile/'scripts/install-windows.ps1'),'-Target',str(target)]
            backend='windows'
        else:
            backend=os.environ.get('FORGE_PROFILE_PACKAGE_BACKEND','macos' if platform.system()=='Darwin' else 'linux')
            bindir=base/'bin';bindir.mkdir()
            for command in ['apt-get','brew','nvim','sudo']:
                path=bindir/command
                path.write_text('''#!/bin/sh
name="${0##*/}"
[ "$name" != sudo ] || exec "$@"
printf '%s %s\n' "$name" "$*" >> "$FORGE_PROFILE_OPS"
if [ "$name" = brew ] && [ "$1" = list ]; then exit 1; fi
exit 0
''',encoding='utf-8');path.chmod(0o755)
            env['PATH']=str(bindir)+os.pathsep+env['PATH']
            args=[bootstrap.SHELL,str(profile/('scripts/install-'+backend+'.sh'))]
        result=subprocess.run(args,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=30)
        (base/'package-result.json').write_text(json.dumps({'backend':backend,'system':platform.system(),'mask':mask,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
        return result,log.read_text(encoding='utf-8') if log.exists() else ''
    def test_20_core_package_gates(self):
        result,log=self.package_plan('core-packages','core')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        for forbidden in ['GoLang.Go','Rustlang','Python.Python','OpenJS','SQLite.SQLite','wez.wezterm','golang-go','rustc','nodejs','python3','sqlite3','brew install node','brew install go','brew install python','font-caskaydia']:
            self.assertNotIn(forbidden,log)
    def test_21_python_package_dependency(self):
        result,log=self.package_plan('python-packages','core,python,node-runtime')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('OpenJS.NodeJS.LTS' if bootstrap.WINDOWS else ('brew install node' if 'brew ' in log else 'nodejs npm'),log)
        self.assertNotIn('Rustlang',log);self.assertNotIn('rustc',log);self.assertNotIn('golang-go',log)
    def test_22_sql_package_dependency(self):
        result,log=self.package_plan('sql-packages','core,sql,go-runtime')
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        if bootstrap.WINDOWS:self.assertIn('GoLang.Go',log);self.assertIn('SQLite.SQLite',log)
        elif 'brew ' in log:self.assertIn('brew install go',log);self.assertIn('brew install sqlite',log)
        else:self.assertIn('golang-go',log);self.assertIn('sqlite3',log)
        self.assertNotIn('Python.Python',log);self.assertNotIn('python3',log);self.assertNotIn('rustc',log)
    @unittest.skipUnless(bootstrap.WINDOWS,'Windows package CLI exit contract')
    def test_23_package_cli_failure(self):
        result,log=self.package_plan('package-error','core,python,node-runtime','OpenJS.NodeJS.LTS')
        self.assertNotEqual(result.returncode,0);self.assertIn('Package install failed',result.stdout+result.stderr)
        self.assertNotIn('forge-nvim installed:',result.stdout)

if __name__=='__main__':
    print('artifacts: '+str(bootstrap.BASE),flush=True)
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Profile))
    (bootstrap.BASE/'profile-summary.json').write_text(json.dumps({'system':bootstrap.SYSTEM,'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors)},indent=2),encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
