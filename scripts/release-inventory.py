"""IDE-BOOT-29: read-only publisher inventory of declared roots and supplied evidence.

No setup/SDK probes. --strict checks metadata gaps, not runtime or legal acceptance.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LICENSE = re.compile(r'(^|[-_.])(unlicen[cs]e|licen[cs]e|copying|notice|copyright)([-_.]|$)', re.I)


def license_name(name):
    return bool(LICENSE.search(name)) and PurePosixPath(name).suffix.lower() in ('','.txt','.md','.rst','.html','.xhtml')


def sha(data): return hashlib.sha256(data).hexdigest()
def read_json(path): return json.loads(Path(path).read_text(encoding='utf-8-sig'))
def file_sha(path):
    with Path(path).open('rb') as stream:return stream_sha(stream)
def stream_sha(stream):
    result=hashlib.sha256()
    for chunk in iter(lambda:stream.read(1024*1024),b''):result.update(chunk)
    return result.hexdigest()


def relative(name):
    path=PurePosixPath(name)
    if not name or '\\' in name or ':' in name or any(ord(c)<32 for c in name) or path.is_absolute() or any(p in ('.','..') for p in name.split('/')):
        raise ValueError('Invalid evidence path: '+name)
    return path


def documents(root, recursive=False):
    root=Path(root).resolve()
    if not root.is_dir():return []
    result=[]
    for path in (root.rglob('*') if recursive else root.iterdir()):
        if path.is_file() and license_name(path.name):
            if path.is_symlink() or not path.resolve().is_relative_to(root):raise ValueError('External license link')
            result.append((path.relative_to(root).as_posix(),path.read_bytes()))
    return sorted(result)


class Inventory:
    def __init__(self, stage):
        self.stage=stage;self.items=[];self.gaps=[]

    def item(self, kind, name, **data):
        result={'id':kind+':'+name,'kind':kind,'name':name,'licenses':[],**data}
        self.items.append(result);return result

    def gap(self, item, code, detail=''):
        self.gaps.append({'item':item['id'],'code':code,'detail':detail})

    def notices(self, item, docs, origin='provided source'):
        for name,data in docs:
            relative(name)
            path=PurePosixPath('licenses')/item['kind']/item['name']/name
            destination=self.stage/path;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(data)
            item['licenses'].append({'path':str(path),'sha256':sha(data),'origin':origin})
        if not docs:self.gap(item,'license_documents_missing')


def inspect(args, stage):
    env=os.environ.copy()
    for key in ['HOME','USERPROFILE','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME','TEMP','TMP','TMPDIR']:
        path=stage/'inspection'/key;path.mkdir(parents=True,exist_ok=True);env[key]=str(path)
    env['NVIM_LOG_FILE']=str(stage/'inspection/nvim.log');env['NVIM_APPNAME']='fride'
    catalog=stage/'inspection/catalog.json'
    subprocess.run([str(args.nvim),'--headless','-u','NONE','-i','NONE','-l',str(ROOT/'scripts/inspect-release-catalog.lua'),
        str(ROOT/'nvim_forge'),str(args.editor_deps/'lazy/nvim-treesitter'),str(catalog)],env=env,capture_output=True,check=True,timeout=30)
    result=subprocess.run([str(args.frontend),'--source',str(ROOT),'--components',args.components,'--print-plan',
        '--install-dir',str(stage/'inspection/prospective-kit')],env=env,capture_output=True,check=True,timeout=10)
    return read_json(catalog),json.loads(result.stdout)


def parser_license(source):
    url=source['source'].removesuffix('.git')
    if not url.startswith('https://github.com/'):return []
    repo=url.removeprefix('https://github.com/')
    if len(repo.split('/'))!=2 or not re.fullmatch('[A-Za-z0-9._-]+',source['revision']):return []
    base='https://raw.githubusercontent.com/'+repo+'/'+urllib.parse.quote(source['revision'],safe='')+'/'
    for name in ['LICENSE','LICENSE.md','LICENSE.txt','COPYING','LICENCE','LICENCE.md']:
        try:
            with urllib.request.urlopen(base+name,timeout=10) as response:data=response.read(2*1024*1024+1)
            if not data or len(data)>2*1024*1024:raise ValueError('Invalid parser license size')
            return [(name,data)]
        except urllib.error.HTTPError as error:
            if error.code!=404:raise
    return []


def collect_plugins(report,args):
    lock=read_json(ROOT/'nvim_forge/lazy-lock.json');manifest=args.editor_deps/'manifest.json'
    prepared=read_json(manifest) if manifest.is_file() else {}
    sources=read_json(ROOT/'tests/e2e/plugin-sources.json')
    for name,entry in sorted(lock.items()):
        relative(name)
        item=report.item('plugin',name,revision=entry['commit'],source='https://github.com/'+sources[name],scope='locked plugin catalog')
        if prepared.get('plugins',{}).get(name)!=entry['commit']:
            report.gap(item,'prepared_revision_mismatch' if manifest.is_file() else 'prepared_manifest_missing');continue
        report.notices(item,documents(args.editor_deps/'lazy'/name))
    for name,entry in sorted(read_json(ROOT/'nvim_forge/patches/plugins.json').items()):
        item=report.item('backport',name,revision=entry['revision'],patch=entry['id'],files={},
            source='repo:nvim_forge/patches/plugins.json',license_evidence='plugin:'+name)
        for patch in [entry,*entry.get('extra',[])]:
            path=relative(patch['file']);file=args.editor_deps/'lazy'/name/path
            actual=file_sha(file) if file.is_file() else None
            item['files'][str(path)]={'sha256':actual,'expected_sha256':patch['after_sha256']}
            if actual!=patch['after_sha256']:report.gap(item,'prepared_patch_mismatch',str(path))


def collect_parsers(report,args,catalog,names):
    cache={}
    if args.license_cache:
        cache={i['id']:i for i in read_json(args.license_cache/'inventory.json')['items'] if i['kind']=='parser'}
    fetched={}
    if args.fetch_parser_licenses:
        with ThreadPoolExecutor(max_workers=4) as pool:
            jobs={name:pool.submit(parser_license,catalog['grammars'][name]) for name in names
                if not (cache.get('parser:'+name,{}).get('source')==catalog['grammars'][name]['source']
                    and cache.get('parser:'+name,{}).get('revision')==catalog['grammars'][name]['revision']
                    and cache.get('parser:'+name,{}).get('licenses'))}
            for name,job in jobs.items():
                try:fetched[name]=job.result()
                except (OSError,ValueError) as error:fetched[name]=str(error)
    for name in names:
        source=catalog['grammars'][name];item=report.item('parser',name,**source,revision_kind='commit' if re.fullmatch('[a-f0-9]{40}',source['revision']) else 'configured-ref')
        binary=args.site/'parser'/(name+'.so');revision=args.site/'parser-info'/(name+'.revision')
        item['binary_sha256']=file_sha(binary) if binary.is_file() else None
        if not binary.is_file():report.gap(item,'native_library_missing')
        if not revision.is_file() or revision.read_text().strip()!=source['revision']:report.gap(item,'native_revision_mismatch')
        docs=[];old=cache.get(item['id'])
        if old and old.get('source')==source['source'] and old.get('revision')==source['revision']:
            for doc in old['licenses']:
                path=args.license_cache/relative(doc['path'])
                if path.is_symlink() or not path.resolve().is_relative_to(args.license_cache.resolve()):raise ValueError('External license cache link')
                data=path.read_bytes()
                if sha(data)!=doc['sha256']:raise ValueError('License cache SHA mismatch: '+name)
                docs.append((path.name,data))
        if not docs and name in fetched:
            if isinstance(fetched[name],str):report.gap(item,'license_fetch_failed',fetched[name])
            else:docs=fetched[name]
        report.notices(item,docs,origin=source['source']+'@'+source['revision'])


def collect_mason(report,args,catalog,names):
    for name in names:
        item=report.item('mason',name,expected_version=catalog['pins'].get(name))
        candidates=[]
        for root in args.mason_root:
            file=root/'packages'/name/'mason-receipt.json'
            if file.is_file():
                try:
                    data=read_json(file)
                    if not isinstance(data,dict):raise ValueError('Receipt must be an object')
                    candidates.append((file,data))
                except (ValueError,OSError):report.gap(item,'receipt_invalid')
        if not candidates:
            if not any(g['item']==item['id'] and g['code']=='receipt_invalid' for g in report.gaps):report.gap(item,'package_not_prepared')
            continue
        identities={json.dumps({'source':d.get('source'),'links':d.get('links'),'version':d.get('install_options',{}).get('version')},sort_keys=True) for _,d in candidates}
        if len(identities)>1:report.gap(item,'conflicting_receipts');continue
        path,data=candidates[0];package=path.parent
        item.update(source=data.get('source',{}).get('id'),version=data.get('install_options',{}).get('version'),receipt_sha256=file_sha(path),entrypoints={})
        if not item['source']:report.gap(item,'source_id_missing')
        if not item['version']:report.gap(item,'version_missing')
        if item['expected_version'] and item['version']!=item['expected_version']:report.gap(item,'version_mismatch')
        for alias,target in sorted(data.get('links',{}).get('bin',{}).items()):
            target=target.replace('\\','/');relative(target);file=package/target
            if file.is_symlink():
                if not file.resolve().is_relative_to(package.resolve()):raise ValueError('External Mason entrypoint')
            item['entrypoints'][alias]={'path':target,'sha256':file_sha(file) if file.is_file() else None}
            if not file.is_file():report.gap(item,'entrypoint_missing',alias)
        if not item['entrypoints']:report.gap(item,'entrypoints_missing')
        report.notices(item,documents(package,True))


def collect_archive(report,path,item,platform):
    expected=item['name'];item['archive_sha256']=file_sha(path)
    archive=zipfile.ZipFile(path) if path.name.endswith('.zip') else tarfile.open(path,'r:gz')
    with archive:
        members={}
        for entry in (archive.infolist() if isinstance(archive,zipfile.ZipFile) else archive.getmembers()):
            name=(entry.filename if isinstance(archive,zipfile.ZipFile) else entry.name).removeprefix('./')
            if not name or name=='.':continue
            if entry.is_dir() if isinstance(archive,zipfile.ZipFile) else entry.isdir():continue
            if isinstance(archive,zipfile.ZipFile) and (entry.external_attr>>16)&0o170000==0o120000:raise ValueError('Linked archive member')
            if not isinstance(archive,zipfile.ZipFile) and not entry.isfile():raise ValueError('Unsupported archive member')
            relative(name)
            if name in members:raise ValueError('Duplicate archive member')
            members[name]=entry
        def open_member(name):return archive.open(members[name]) if isinstance(archive,zipfile.ZipFile) else archive.extractfile(members[name])
        manifest='forge-runtime.json' if expected=='core' else 'forge-component.json'
        with open_member(manifest) as file:raw=file.read(16*1024*1024)
        meta=json.loads(raw);item['manifest_sha256']=sha(raw)
        if meta.get('schema')!=1 or meta.get('platform')!=platform or meta.get('components')!=[expected]:raise ValueError('Archive platform/components mismatch')
        if set(members)!=set(meta['files'])|{manifest}:raise ValueError('Untracked/missing archive files')
        suffix='.exe' if platform.startswith('windows-') else ''
        required={'core':['bin/nvim'+suffix,'search/bin/rg'+suffix,'search/prepared.json','treesitter/prepared.json'],
            'sql':['sql/bin/sqls'+suffix,'sql/bin/forge-sqltest'+suffix,'sql/prepared.json']}
        if expected=='terminal':
            policy=read_json(ROOT/'scripts/sdk/terminal.json')
            required['terminal']=['terminal/prepared.json','terminal/'+policy['wezterm']['platforms'][platform]['executable']]
        for name in required.get(expected,[]):
            if name not in meta['files']:report.gap(item,'declared_runtime_file_missing',name)
        docs=[];item['prepared_metadata']={}
        for name,digest in sorted(meta['files'].items()):
            with open_member(name) as file:
                if stream_sha(file)!=digest:raise ValueError('Archive payload SHA mismatch: '+name)
            if name.endswith('/prepared.json'):item['prepared_metadata'][name]=digest
            if license_name(PurePosixPath(name).name) or name.endswith('/doc/uganda.txt'):
                with open_member(name) as file:docs.append((name,file.read()))
        item['files']=len(meta['files']);report.notices(item,docs,'supplied hash-checked archive')


def generate(args):
    output=args.output.resolve()
    inputs=[args.editor_deps,args.site,*args.mason_root,*([args.license_cache] if args.license_cache else [])]
    if output.exists():raise ValueError('Output already exists; choose a new report directory')
    if any(output==p.resolve() or p.resolve() in output.parents for p in inputs):raise ValueError('Output must be outside inventory inputs')
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.release-inventory-',dir=output.parent) as temporary:
        stage=Path(temporary);catalog,plan=inspect(args,stage);report=Inventory(stage)
        selected=plan['components'];unknown=set(selected)-set(catalog['components'])
        if unknown:raise ValueError('Unknown selected components')
        names=lambda field:sorted({name for id in selected for name in catalog['components'][id][field]})
        collect_plugins(report,args);collect_parsers(report,args,catalog,names('parsers'));collect_mason(report,args,catalog,names('mason'))
        windows=read_json(ROOT/'scripts/sdk/windows.json')
        report.item('runtime','neovim',source='https://github.com/neovim/neovim',version='0.12.2',license_evidence='artifact:core',
            windows_patch_policy_sha256=file_sha(ROOT/'scripts/sdk/windows.json'),windows_source_revision=windows.get('SourceRevision'))
        search=read_json(ROOT/'scripts/sdk/ripgrep.json')
        report.item('runtime','ripgrep',source='https://github.com/BurntSushi/ripgrep',version=search['version'],license_evidence='artifact:core',policy_sha256=file_sha(ROOT/'scripts/sdk/ripgrep.json'))
        if 'sql' in selected:
            for name,version in sorted(catalog['native_tools'].items()):
                report.item('native-tool',name,version=version,source='repo:scripts/sdk/'+('sql-test' if name=='forge-sqltest' else 'sqls.json'),license_evidence='artifact:sql')
        if 'terminal' in selected:
            policy=read_json(ROOT/'scripts/sdk/terminal.json')
            report.item('runtime','wezterm',version=policy['wezterm']['version'],source='https://github.com/wezterm/wezterm',license_evidence='artifact:terminal',policy_sha256=file_sha(ROOT/'scripts/sdk/terminal.json'))
            report.item('font','CaskaydiaCove',version=policy['font']['version'],source=policy['font']['url'],source_sha256=policy['font']['sha256'],license_evidence='artifact:terminal')
        supplied={}
        for value in args.archive:
            id,path=value.split('=',1)
            if id in supplied or id not in selected:raise ValueError('Duplicate/unselected archive: '+id)
            supplied[id]=Path(path)
        for id in selected:
            item=report.item('artifact',id)
            if id not in supplied:report.gap(item,'archive_not_supplied');continue
            try:collect_archive(report,supplied[id],item,catalog['platform'])
            except (OSError,ValueError,KeyError,zipfile.BadZipFile,tarfile.TarError) as error:
                report.gap(item,'archive_invalid',error.strerror if isinstance(error,OSError) else str(error))
        report.items.sort(key=lambda i:i['id']);report.gaps.sort(key=lambda g:(g['item'],g['code'],g['detail']))
        result={'schema':1,'platform':catalog['platform'],'components':selected,'native_sdks':plan['native_sdks'],
            'external_prerequisites':['git']+(['bash','wsl2' if catalog['platform'].startswith('windows-') else 'posix-shell'] if 'bash' in selected else []),
            'nvim_version':catalog['nvim_version'],'metadata_complete':not report.gaps,'full_release_ready':False,
            'scope':'Declared direct roots and provided license documents; transitive coverage and native workflow acceptance remain separate.',
            'inputs':{'lazy_lock_sha256':file_sha(ROOT/'nvim_forge/lazy-lock.json'),'components_sha256':file_sha(ROOT/'nvim_forge/scripts/components.tsv'),'tool_catalog_sha256':file_sha(ROOT/'nvim_forge/lua/forge/tool_catalog.lua'),
                'producer_sha256':file_sha(ROOT/'scripts/release-inventory.py'),'inspector_sha256':file_sha(ROOT/'scripts/inspect-release-catalog.lua')},
            'items':report.items,'gaps':report.gaps}
        (stage/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
        lines=['# Inventory fride','',f"Платформа: {result['platform']}; компоненты: {', '.join(selected)}.",
            f"Обычные SDK (не копируются): {', '.join(plan['native_sdks']) or 'не нужны'}.",
            '','Scope: direct roots/provided license documents. Full release/native/transitive acceptance отдельно.','',
            '| Item | Version / revision | Source | License docs |','|---|---|---|---|']
        for item in report.items:lines.append('| '+item['id']+' | '+str(item.get('revision',item.get('version','—')))+' | '+str(item.get('source','—'))+' | '+str(len(item['licenses']))+' |')
        lines+=['','## Незакрытые входы','']+[f"- {g['item']}: {g['code']} {g['detail']}" for g in report.gaps]
        (stage/'INVENTORY.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
        with (stage/'THIRD_PARTY_NOTICES.txt').open('wb') as file:
            file.write(b'Provided upstream documents; no transitive/legal completeness assertion.\n')
            for item in report.items:
                for doc in item['licenses']:
                    file.write(('\n=== '+item['id']+' / '+doc['path']+' / SHA256 '+doc['sha256']+' ===\n').encode())
                    file.write((stage/doc['path']).read_bytes());file.write(b'\n')
        shutil.rmtree(stage/'inspection')
        assert stage.resolve().parent==output.parent
        stage.rename(output)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--editor-deps',required=True,type=Path);parser.add_argument('--site',required=True,type=Path)
    parser.add_argument('--nvim',type=Path,default=ROOT/'.tools/neovim/windows-x64/bin/nvim.exe' if os.name=='nt' else shutil.which('nvim'))
    parser.add_argument('--frontend',type=Path,required=True);parser.add_argument('--components',default='core,go,rust,python,node,bash,sql,terminal')
    parser.add_argument('--mason-root',type=Path,action='append',default=[]);parser.add_argument('--archive',action='append',default=[],metavar='COMPONENT=FILE')
    parser.add_argument('--license-cache',type=Path);parser.add_argument('--fetch-parser-licenses',action='store_true')
    parser.add_argument('--output',required=True,type=Path);parser.add_argument('--strict',action='store_true')
    args=parser.parse_args()
    try:
        result=generate(args)
        print(json.dumps({'output':str(args.output),'items':len(result['items']),'gaps':len(result['gaps']),'metadata_complete':result['metadata_complete'],'full_release_ready':False}))
        raise SystemExit(2 if args.strict and result['gaps'] else 0)
    except (ValueError,OSError,subprocess.SubprocessError) as error:parser.exit(1,str(error)+'\n')
