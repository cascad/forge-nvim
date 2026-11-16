"""IDE-BOOT-23: publisher SQL part from verified native builds, no SDK installs.

End users receive this part through the ordinary runtime catalog. Build inputs
are produced by the existing native SQL preparation, outside the installation.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]

def digest(path,canonical=False):
    data=Path(path).read_bytes()
    return hashlib.sha256(data.replace(b'\r\n',b'\n') if canonical else data).hexdigest()

def package(sqls_root,runner_root,output):
    sqls_root,runner_root,output=map(lambda p:Path(p).resolve(),(sqls_root,runner_root,output))
    sql=json.loads((sqls_root/'manifest.json').read_text(encoding='utf-8'))
    runner=json.loads((runner_root/'manifest.json').read_text(encoding='utf-8'))
    policy=json.loads((ROOT/'nvim_forge/scripts/native-tools.json').read_text(encoding='utf-8'))
    sdk=json.loads((ROOT/'scripts/sdk/sqls.json').read_text(encoding='utf-8'))
    platform=sql['platform']
    if platform!=runner['platform']:raise ValueError('Native SQL build platforms differ')
    if platform not in ('win32-x64','linux-x64','linux-arm64','darwin-x64','darwin-arm64'):raise ValueError('Unsupported SQL platform')
    if sdk['version']!=policy['sqls'] or digest(ROOT/sdk['patch'])!=sdk['patch_sha256']:raise ValueError('SQLS patch/policy mismatch')
    context=sql.get('build_context',{}).get('sqls',{})
    if sql.get('sqls_variant')!='patched' or context.get('sdk_sha256')!=digest(ROOT/'scripts/sdk/sqls.json') or context.get('patch_sha256')!=sdk['patch_sha256']:
        raise ValueError('SQLS requires the verified patched build manifest')
    source=ROOT/'scripts/sdk/sql-test'
    expected={name:digest(source/name,True) for name in ('Cargo.toml','Cargo.lock','src/main.rs')}
    if runner.get('sources')!=expected:raise ValueError('SQL test runner source/lock mismatch')
    version=re.search(r'^version\s*=\s*"([^"]+)"',(source/'Cargo.toml').read_text(),re.M)[1]
    if version!=policy['forge-sqltest']:raise ValueError('SQL test runner policy mismatch')
    suffix='.exe' if platform.startswith('win32') else ''
    inputs={}
    for name,base,meta,flag in [('sqls',sqls_root,sql,'-version'),('forge-sqltest',runner_root,runner,'--version')]:
        relative='bin/'+name+suffix;binary=base/relative
        if meta.get('files',{}).get(relative)!=digest(binary):raise ValueError('Native SQL binary SHA mismatch: '+name)
        if not os.access(binary,os.X_OK):raise ValueError('Native SQL binary is not executable: '+name)
        result=subprocess.run([str(binary),flag],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=10)
        actual=result.stdout+result.stderr
        expected='Version:'+policy[name]+',' if name=='sqls' else name+' '+policy[name]+' '
        if result.returncode or expected not in actual:raise ValueError('Native SQL version mismatch: '+name)
        inputs[name]=binary
    module=importlib.util.spec_from_file_location('sql_runtime_packager',ROOT/'scripts/package-runtime.py')
    packager=importlib.util.module_from_spec(module);module.loader.exec_module(packager)
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.sql-part-',dir=output.parent) as temporary:
        temp=Path(temporary);stage=temp/'stage';bin_dir=stage/'sql/bin';bin_dir.mkdir(parents=True)
        for name,binary in inputs.items():shutil.copy2(binary,bin_dir/(name+suffix))
        metadata={'schema':1,'versions':policy,'sqls_sdk_sha256':digest(ROOT/'scripts/sdk/sqls.json'),
            'sqls_patch_sha256':sdk['patch_sha256'],'runner_sources':runner['sources']}
        (stage/'sql/prepared.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
        recipe={'schema':1,'platform':platform.replace('win32-','windows-').replace('darwin-','macos-'),
            'components':['sql'],'paths':['sql/bin'],'probes':[['sql/bin/sqls'+suffix,'-version'],['sql/bin/forge-sqltest'+suffix,'--version']]}
        path=temp/'recipe.json';path.write_text(json.dumps(recipe),encoding='utf-8')
        return packager.package(stage,path,output,'sql')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sqls',required=True,type=Path);parser.add_argument('--runner',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();print(json.dumps(package(args.sqls,args.runner,args.output),indent=2))
