"""Частный Forge профиль для реального ConPTY; не использует user lazy/data."""
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


@contextmanager
def isolated_forge(repo):
    repo = Path(repo)
    expected = json.loads((repo / "nvim_forge/lazy-lock.json").read_text(encoding="utf-8"))
    deps = Path(os.environ.get("FORGE_E2E_DEPS", str(repo / ".tests/editor-deps")))
    manifest = json.loads((deps / "manifest.json").read_text(encoding="utf-8"))
    if manifest["plugins"] != {k: v["commit"] for k, v in expected.items()}:
        raise RuntimeError("ConPTY: повтори явную подготовку tests/e2e/prepare_editor.py")
    checked = subprocess.run([os.environ.get("FORGE_TEST_NVIM", "nvim"), "-l",
                              str(repo / "nvim_forge/scripts/prepare-plugins.lua"),
                              "--plugin-root", str(deps / "lazy"), "--check"],
                             capture_output=True, text=True, encoding="utf-8", timeout=30)
    if checked.returncode or json.loads(checked.stdout) != manifest.get("backports"):
        raise RuntimeError("ConPTY: повтори prepare_editor.py; backport не подготовлен: " + checked.stderr)
    base = repo / ".tests/tmp"
    base.mkdir(parents=True, exist_ok=True)
    before = (repo / "nvim_forge/lazy-lock.json").read_bytes()
    with tempfile.TemporaryDirectory(prefix="conpty-profile-", dir=base) as folder:
        runtime = Path(folder)
        env = {"NVIM_APPNAME": "nvim_forge", "NVIM_LOG_FILE": str(runtime / "nvim.log")}
        for key in ("HOME", "USERPROFILE", "LOCALAPPDATA", "APPDATA", "TEMP", "TMP", "TMPDIR",
                    "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"):
            path = runtime / key
            path.mkdir()
            env[key] = str(path)
        config = Path(env["XDG_CONFIG_HOME"]) / "nvim_forge"
        shutil.copytree(repo / "nvim_forge", config)
        data = Path(env["XDG_DATA_HOME"]) / "nvim_forge-data/lazy"
        for name in expected:
            shutil.copytree(deps / "lazy" / name, data / name)
        env["FORGE_CONPTY_PROFILE_RECORD"] = str(runtime / "profile.json")
        try:
            yield env
        finally:
            if before != (repo / "nvim_forge/lazy-lock.json").read_bytes():
                raise RuntimeError("ConPTY изменил source lazy-lock.json")
