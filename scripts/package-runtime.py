"""IDE-BOOT-11: пакет подготовленного native runtime; ничего не устанавливает в host.

Компоненты/paths/probes задаёт recipe JSON. Это упаковка, а не доказательство
полноты SDK: native E2E и полный Default acceptance выполняются отдельно.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import zipfile


def package(source, recipe, output):
    source, output = Path(source).resolve(), Path(output).resolve()
    if source == output or source in output.parents:
        raise ValueError('Output must be outside runtime source')
    meta = json.loads(Path(recipe).read_text(encoding='utf-8'))
    if meta.get('schema') != 1 or not meta.get('components') or 'core' not in meta['components']:
        raise ValueError('Recipe requires schema1 and core component')
    expected = 'bin/nvim.exe' if meta['platform'] == 'windows-x64' else 'bin/nvim'
    if meta.get('nvim') != expected or not (source/expected).is_file():
        raise ValueError('Unsupported/missing native Neovim')
    for value in meta.get('paths', []) + [p[0] for p in meta.get('probes', [])]:
        if not value or '\\' in value or ':' in value or any(c in value for c in '\r\n\t') or value.startswith('/') or any(p in ('.','..') for p in value.split('/')):
            raise ValueError('Invalid relative path: '+value)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Staging на диске output; materialize только внутренние ссылки, циклы отклоняются.
    with tempfile.TemporaryDirectory(prefix='.runtime-', dir=output.parent) as temporary:
        stage=Path(temporary)/'runtime'
        def copy_tree(src, dst, active=frozenset()):
            real=src.resolve()
            if (real != source and source not in real.parents) or real in active:
                raise ValueError('External/cyclic runtime link: '+str(src))
            if real.is_dir():
                dst.mkdir()
                for child in src.iterdir(): copy_tree(child,dst/child.name,active|{real})
            else: shutil.copy2(real,dst)
        copy_tree(source,stage)
        (stage/'forge-runtime.json').unlink(missing_ok=True)
        (stage/'nvim.sha256').write_text(hashlib.sha256((stage/expected).read_bytes()).hexdigest()+'\n',encoding='ascii')
        meta['files']={p.relative_to(stage).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                       for p in sorted(stage.rglob('*')) if p.is_file()}
        (stage/'forge-runtime.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        if output.suffix == '.zip':
            with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(stage.rglob('*')):
                    if path.is_file(): archive.write(path,path.relative_to(stage).as_posix())
        elif output.name.endswith('.tar.gz'):
            with tarfile.open(output,'w:gz') as archive: archive.add(stage,arcname='.')
        else: raise ValueError('Use .zip or .tar.gz')
    record={'archive':output.name,'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
            'platform':meta['platform'],'components':meta['components']}
    output.with_name(output.name+'.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    return record


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True);parser.add_argument('--recipe',required=True)
    parser.add_argument('--output',required=True)
    options=parser.parse_args()
    print(json.dumps(package(options.source,options.recipe,options.output),indent=2))
