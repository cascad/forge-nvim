"""Явная pinned подготовка неизменённого bash-debug; Node/WSL не устанавливает."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
SHA = "7fc154642bf3fcfa27a903fd44235bc902d93e737939c7b411ece6fe10f5f458"
URL = "https://open-vsx.org/api/rogalmic/bash-debug/0.3.9/file/rogalmic.bash-debug-0.3.9.vsix"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / ".tests/bash-dap-deps")
    args = parser.parse_args()
    out = args.output.resolve()
    if os.name == "nt" and out.drive.lower() != ROOT.drive.lower():
        parser.error("Windows output/cache должны оставаться на диске checkout")
    manifest = out / "manifest.json"
    if args.download or args.archive:
        out.mkdir(parents=True, exist_ok=True)
        archive = args.archive or out / "bash-debug-0.3.9.vsix"
        if not archive.is_file():
            if not args.download:
                parser.error("Archive не найден")
            urllib.request.urlretrieve(URL, archive)
        if sha(archive) != SHA:
            parser.error("VSIX SHA256 не совпал; payload не изменён")
        with ZipFile(archive) as source:
            for item in source.infolist():
                if item.is_dir() or not item.filename.startswith("extension/"):
                    continue
                target = (out / item.filename).resolve()
                if out not in target.parents:
                    parser.error("Некорректный путь в archive")
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read(item))
                if os.name != "nt":
                    target.chmod((item.external_attr >> 16) & 0o777 or 0o644)
        files = {p.relative_to(out).as_posix(): sha(p)
                 for p in (out / "extension").rglob("*") if p.is_file()}
        manifest.write_text(json.dumps(dict(version="0.3.9",archive_sha256=SHA,
                                            url=URL,files=files),indent=2)+"\n",encoding="utf-8")
    if not manifest.is_file():
        parser.error("Нужна явная подготовка --download или --archive")
    expected = json.loads(manifest.read_text(encoding="utf-8"))
    if expected["archive_sha256"] != SHA:
        parser.error("Неизвестный pinned manifest")
    actual = {p.relative_to(out).as_posix(): sha(p)
              for p in (out / "extension").rglob("*") if p.is_file()}
    if actual != expected["files"]:
        parser.error("Payload изменился; нужна явная подготовка")
    assert (out / "extension/out/bashDebug.js").is_file()
    print("Prepared bash-debug0.3.9: " + str(out))


if __name__ == "__main__":
    main()
