"""CLI E2E платформенной границы SDK: настоящие shell и Neovim, частный checkout."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tests/lib'))
import cli_probe


class LauncherFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "SDK проект с пробелами"
        self.root.mkdir()
        self.env = dict(os.environ)
        self.env.pop("FORGE_NVIM", None)
        self.env.update(NVIM_APPNAME="parent_app", XDG_CONFIG_HOME="parent_config")
        self.record = self.root / "record.json"
        self.env["FORGE_SDK_RECORD"] = str(self.record)
        self.probe = self.root / "probe.lua"
        self.probe.write_text('local args={};for _,value in ipairs(arg) do args[#args+1]=value end\nvim.fn.writefile({vim.json.encode({args=args,app=vim.env.NVIM_APPNAME,config=vim.env.XDG_CONFIG_HOME,prog=vim.v.progpath})},vim.env.FORGE_SDK_RECORD)\nos.exit(7)\n', encoding="utf-8")

    def copy(self, name):
        target = self.root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)
        return target

    def call(self, argv):
        return cli_probe.run(argv, cwd=self.root, env=self.env, timeout=10,
                             errors='replace', artifacts=ROOT / '.tests/sdk-cli',
                             context_files=(self.root / name for name in (
                                 'nvim_forge.cmd', 'scripts/launch-forge.ps1',
                                 'scripts/test.ps1', 'scripts/lib/nvim-sdk.ps1',
                                 'scripts/sdk/windows.json')))

    def data(self):
        return json.loads(self.record.read_text(encoding="utf-8"))


@unittest.skipUnless(os.name == "nt", "Windows SDK boundary")
class TestWindowsSDKCLI(LauncherFixture):
    def setUp(self):
        super().setUp()
        for name in ("nvim_forge.cmd", "scripts/launch-forge.ps1", "scripts/test.ps1",
                     "scripts/prepare-windows-sdk.ps1",
                     "scripts/lib/nvim-sdk.ps1", "scripts/sdk/windows.json",
                     "scripts/sdk/neovim-conpty-lifecycle.patch"):
            self.copy(name)
        self.sdk = self.root / ".tools/neovim/windows-x64"
        prepared = ROOT / ".tools/neovim/windows-x64"
        self.assertTrue((prepared / "forge-sdk.json").is_file(), "явно подготовь Windows SDK перед E2E")
        shutil.copytree(prepared / "bin", self.sdk / "bin")
        shutil.copyfile(prepared / "forge-sdk.json", self.sdk / "forge-sdk.json")
        self.env["VIMRUNTIME"] = str(prepared / "share/nvim/runtime")
        self.shell = shutil.which("powershell") or shutil.which("pwsh")
        self.nvim = self.sdk / "bin/nvim.exe"

    def launch(self):
        command = subprocess.list2cmdline([str(self.root / "nvim_forge.cmd"), "--clean", "--headless", "-i", "NONE",
                                          "-l", str(self.probe), "file with spaces.txt", "русский%файл"])
        return self.call(subprocess.list2cmdline([os.environ.get("COMSPEC", "cmd.exe")]) + ' /d /v:off /s /c "' + command + '"')

    def test_launcher_uses_verified_sdk_preserves_argv_and_exit(self):
        result = self.launch()
        self.assertEqual(result.returncode, 7, result.stderr + result.stdout)
        data = self.data()
        self.assertEqual(data["args"], ["file with spaces.txt", "русский%файл"])
        self.assertEqual(data["app"], "nvim_forge")
        self.assertEqual(Path(data["config"]), self.root)
        self.assertEqual(Path(data["prog"]), self.nvim)

    def test_test_entrypoint_uses_same_sdk_and_whole_suite(self):
        runner = self.root / "tests/run.lua"
        runner.parent.mkdir()
        shutil.copyfile(self.probe, runner)
        result = self.call([self.shell, "-NoProfile", "-File", str(self.root / "scripts/test.ps1"), "quick"])
        self.assertEqual(result.returncode, 7, result.stderr + result.stdout)
        self.assertEqual(self.data()["args"], ["unit"])
        self.assertEqual(Path(self.data()["prog"]), self.nvim)

    def test_missing_stale_corrupt_sdk_fails_before_launch(self):
        manifest = self.sdk / "forge-sdk.json"
        original = manifest.read_bytes()
        for failure in ("missing", "stale", "corrupt", "incomplete"):
            with self.subTest(failure=failure):
                manifest.write_bytes(original)
                if failure == "missing":
                    manifest.unlink()
                else:
                    data = json.loads(original)
                    if failure == "stale": data["SourceRevision"] = "old-revision"
                    if failure == "corrupt": data["BinarySHA256"] = "0" * 64
                    if failure == "incomplete": data["Ready"] = False
                    manifest.write_text(json.dumps(data), encoding="utf-8")
                result = self.launch()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("prepare-windows-sdk.ps1 -Download", result.stderr)
                self.assertFalse(self.record.exists(), "ни SDK, ни system fallback не запущены")

    def test_system_override_is_explicit_and_does_not_need_manifest(self):
        (self.sdk / "forge-sdk.json").unlink()
        self.env["FORGE_NVIM"] = "system"
        result = self.launch()
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(Path(self.data()["prog"]), Path(shutil.which("nvim")))

    def test_script_restores_environment_in_same_powershell_process(self):
        parent = self.root / "parent.ps1"
        parent.write_text("$env:NVIM_APPNAME='parent_app'\n$env:XDG_CONFIG_HOME='parent_config'\n& (Join-Path $PSScriptRoot 'scripts/launch-forge.ps1') --clean --headless -i NONE -l (Join-Path $PSScriptRoot 'probe.lua')\n$childExit=$LASTEXITCODE\nif($env:NVIM_APPNAME -ne 'parent_app' -or $env:XDG_CONFIG_HOME -ne 'parent_config'){exit 93}\nexit $childExit\n", encoding="ascii")
        result = self.call([self.shell, "-NoProfile", "-File", str(parent)])
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(self.data()["app"], "nvim_forge")

    def test_preparer_refuses_wrong_source_and_patch_before_build(self):
        source = self.root / ".tests/neovim-native/v0.12.2-src"
        source.mkdir(parents=True)
        def git(*args):
            result = self.call(["git", "-C", str(source), *args])
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.strip()
        git("init")
        git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
            "commit", "--allow-empty", "-m", "private SDK fixture")
        head = git("rev-parse", "HEAD")
        prepare = [self.shell, "-NoProfile", "-File", str(self.root / "scripts/prepare-windows-sdk.ps1")]
        result = self.call(prepare)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SDK source revision mismatch", result.stderr)
        self.assertEqual(git("rev-parse", "HEAD"), head)
        (self.root / "scripts/sdk/neovim-conpty-lifecycle.patch").write_text("corrupt patch", encoding="ascii")
        result = self.call(prepare)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SDK patch hash mismatch", result.stderr)


@unittest.skipIf(os.name == "nt", "POSIX official SDK boundary")
class TestPOSIXSDKCLI(LauncherFixture):
    def test_official_sdk_needs_no_windows_tools_and_preserves_argv(self):
        launcher = self.copy("nvim_forge.sh")
        result = self.call(["bash", str(launcher), "--clean", "--headless", "-i", "NONE", "-l",
                            str(self.probe), "file with spaces.txt", "русский%файл"])
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual(self.data()["args"], ["file with spaces.txt", "русский%файл"])
        self.assertEqual(self.data()["app"], "nvim_forge")
        self.assertEqual(Path(self.data()["prog"]).resolve(), Path(shutil.which("nvim")).resolve())
        self.assertFalse((self.root / ".tools").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
