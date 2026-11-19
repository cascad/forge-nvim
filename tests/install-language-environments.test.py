"""IDE-BOOT-50/51: native frontend, real Core transport, controlled tools stage.

No external downloads or host SDK installation. Actual tools are a separate
installed/cold acceptance; this stand asserts scope, ownership and failure paths.
"""
import importlib.util
import json
import os
from pathlib import Path
import sys
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('runtime',ROOT/'tests/install-runtime.test.py')
runtime=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime)
ui,stand=runtime.ui,runtime.stand

class Languages(runtime.Runtime):
    def run_process(self,args,env,base,label):
        result=subprocess.run(args,env=env,cwd=base,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
        (base/(label+'.json')).write_text(json.dumps({'args':args,'exit':result.returncode,'out':result.stdout,'err':result.stderr},ensure_ascii=False,indent=2),encoding='utf-8')
        return result
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        with (cls.source/'nvim_forge/scripts/setup-stage.lua').open('a',encoding='utf-8') as file:
            file.write("\nif vim.env.FRIDE_LANGUAGE_TRACE then vim.fn.writefile({vim.json.encode({stage=arg[1],desired=vim.env.FORGE_NVIM_COMPONENTS,prepared=vim.env.FORGE_PREPARE_COMPONENTS,report=vim.g.forge_setup_sdk_report})},vim.env.FRIDE_LANGUAGE_TRACE,'a') end\n")

    def install(self,name,components='core,node'):
        base,env,target=self.prepare(name)
        env['FRIDE_LANGUAGE_TRACE']=str(base/'stages.jsonl')
        args=self.binary_args(base,target,preview=False,profile='default',components=components)
        if stand.WINDOWS:args+=['--powershell',stand.SHELL]
        self.assert_ok(self.run_process(args,env,base,'install'))
        return base,env,target

    def language(self,base,target,kind='node',result='language.json'):
        return [str(target/'bin'/('fride-setup.exe' if stand.WINDOWS else 'fride-setup')),
            '--prepare-language',kind,'--installed-kit',str(target),'--log-dir',str(base/'language logs'),
            '--result',str(base/result)]

    def test_language_01_default_without_sdks_records_deferred_and_embeds_frontend(self):
        base,env,target=self.install('language-default','core,go,rust,python,node,bash,sql')
        plan=json.loads((base/'result.json').read_text())
        self.assertFalse(plan['prepare_languages'])
        owner=json.loads((target/'.forge-install.json').read_text())
        self.assertEqual(owner['prepared_components'],['core'])
        self.assertEqual(set(owner['deferred_components']),{'go','rust','python','node','bash','sql'})
        frontend=target/owner['maintenance']
        self.assertEqual(frontend.read_bytes(),ui.BINARY.read_bytes())
        for name in ['sdk-preflight.lua','runtime-core.lua','sdk/windows.json']:
            self.assertEqual((target/'config/forge/scripts'/name).read_bytes(),(ROOT/'scripts'/name).read_bytes())
        stages=[json.loads(line) for line in (base/'stages.jsonl').read_text().splitlines()]
        self.assertTrue(stages);self.assertTrue(all(stage['prepared']=='core' for stage in stages))
        self.assertFalse(any((base/'logs').glob('sdk-*-node.log')),'Default probed SDK despite deferral')

    def test_language_02_existing_sdk_prepares_only_language_preserves_kit_and_settings(self):
        base,env,target=self.install('language-ready')
        tools=base/'project/.fride/tools.json';tools.parent.mkdir(parents=True)
        tools.write_text(json.dumps({'tools':{'node':str(self.node_sdk/('node.exe' if stand.WINDOWS else 'bin/node'))},'metadata':{'keep':True}}))
        before=stand.snapshot(target)
        result=self.run_process(self.language(base,target),env,base/'project','prepare')
        self.assert_ok(result)
        after=stand.snapshot(target)
        before.pop('bin/sdk-paths.txt',None);after.pop('bin/sdk-paths.txt',None)
        self.assertEqual(after,before)
        self.assertTrue(json.loads(tools.read_text())['metadata']['keep'])
        data=json.loads((base/'language.json').read_text());self.assertTrue(data['ready'])
        self.assertEqual(data['language'],'node');self.assertEqual(data['sdks'][0]['status'],'ready')
        stage=json.loads((base/'stages.jsonl').read_text().splitlines()[-1])
        self.assertEqual(stage['prepared'],'core,node');self.assertEqual(stage['report']['scope'],'project')

    def test_language_03_invalid_project_sdk_does_not_fallback_or_write_result(self):
        base,env,target=self.install('language-invalid')
        project=base/'project';(project/'.fride').mkdir(parents=True)
        (project/'.fride/tools.json').write_text(json.dumps({'tools':{'node':str(base/'missing-node')}}))
        before=stand.snapshot(target)
        result=self.run_process(self.language(base,target),env,project,'invalid')
        self.assertNotEqual(result.returncode,0);self.assertFalse((base/'language.json').exists())
        self.assertEqual(stand.snapshot(target),before)

    def test_language_04_failed_tools_do_not_publish_ready(self):
        base,env,target=self.install('language-stage-failure');before=stand.snapshot(target)
        env['FORGE_FAIL_STAGE']='tools'
        result=self.run_process(self.language(base,target,'sql'),env,base,'failed-stage')
        self.assertNotEqual(result.returncode,0);self.assertFalse((base/'language.json').exists())
        self.assertEqual(stand.snapshot(target),before)

    def test_language_05_unowned_or_existing_result_is_refused(self):
        base,env,target=self.install('language-owner')
        (base/'language.json').write_text('keep')
        result=self.run_process(self.language(base,target),env,base,'existing-result')
        self.assertNotEqual(result.returncode,0);self.assertEqual((base/'language.json').read_text(),'keep')
        (target/'.forge-install.json').write_text('{"product":"foreign"}')
        result=self.run_process(self.language(base,target,result='second.json'),env,base,'unowned')
        self.assertNotEqual(result.returncode,0);self.assertFalse((base/'second.json').exists())

    @unittest.skipIf(stand.WINDOWS,'Official Go archive provider is Linux-only; Windows uses WinGet')
    def test_language_06_official_provider_reuses_native_go_without_download_or_sdk_change(self):
        base,env,_=self.prepare('language-provider-reuse')
        go=Path(os.environ.get('FORGE_SDK_GO_NEW',str(ROOT/'.tests/dap-tools/go' if stand.WINDOWS else '/opt/go')))
        self.assertTrue((go/'bin/go').is_file(),'Prepared native SDK required')
        env['PATH']=str(go/'bin')+os.pathsep+env['PATH']
        output=base/'sdk.json'
        version=subprocess.check_output([str(go/'bin/go'),'version'],env=dict(env,GOTOOLCHAIN='local'),text=True)
        self.assert_ok(self.run_process([str(stand.NVIM),'--headless','-u','NONE','-i','NONE','-l',
            str(ROOT/'nvim_forge/scripts/install-sdk.lua'),'go',str(output)],env,base,'provider'))
        data=json.loads(output.read_text());self.assertTrue(data['reused']);self.assertTrue(data['ready'])
        self.assertEqual(data['version'],version.strip());self.assertTrue(Path(data['selection']['env']['GOROOT']).is_dir())

    def test_language_07_native_cancel_keeps_kit_and_does_not_publish_result(self):
        base,env,target=self.install('language-cancel');before=stand.snapshot(target)
        empty=base/'empty bin';empty.mkdir();env['PATH']=str(empty)
        env['FORGE_UI_EXPECTED_EXIT']='130'
        self.pty(base,env,self.language(base,target),'sdk-cancel')
        self.assertEqual(stand.snapshot(target),before);self.assertFalse((base/'language.json').exists())

if __name__=='__main__':
    print('work:',stand.BASE,flush=True)
    names=sys.argv[1:] or [name for name in Languages.__dict__ if name.startswith('test_language_')]
    result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(Languages(name) for name in names))
    (stand.BASE/'language-summary.json').write_text(json.dumps({'tests':result.testsRun,'failures':len(result.failures),'errors':len(result.errors)}))
    raise SystemExit(0 if result.wasSuccessful() else 1)
