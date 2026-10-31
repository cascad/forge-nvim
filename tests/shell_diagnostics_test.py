"""Проверки пассивного отчёта IDE-001 без настоящего HOME, shell и Go."""

import importlib.util
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "shell_diagnostics", ROOT / "nvim_forge/scripts/diagnose-shell.py")
DIAG = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DIAG)


class DiagnosticsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        self.cwd = self.home / "project"
        self.cwd.mkdir()

    def write(self, name, text):
        path = self.home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def report(self, env=None):
        lines = []
        DIAG.report(self.home, self.cwd, env or {}, lines.append)
        return "\n".join(lines)

    def test_go_call_and_source_location_without_profile_secrets(self):
        self.write(".zshrc", 'export API_TOKEN=do-not-share\nsource "$HOME/tools.zsh"\n')
        self.write("tools.zsh", 'export PATH="$(go env GOPATH)/bin:$PATH" # private-note\n')
        result = self.report({"UNRELATED_SECRET": "hidden"})
        self.assertIn("tools.zsh:1 GO_CALL", result)
        self.assertIn(".zshrc:2 SOURCE ->", result)
        for private in ("do-not-share", "private-note", "UNRELATED_SECRET", "hidden"):
            self.assertNotIn(private, result)

    def test_does_not_execute_commands_or_dynamic_sources(self):
        marker = self.home / "must-not-exist"
        self.write(".zshrc", 'touch "' + str(marker) + '"\nsource "$(touch ' + str(marker) + ')"\n')
        result = self.report()
        self.assertIn("SOURCE_DYNAMIC", result)
        self.assertFalse(marker.exists())

    def test_relative_source_uses_current_directory_and_cycle_stops(self):
        self.write(".zshrc", "source ./a.zsh\n")
        self.write("project/a.zsh", 'source "$HOME/.zshrc"\ngo version\n')
        result = self.report()
        self.assertEqual(result.count("a.zsh:2 GO_CALL"), 1)

    def test_custom_zdotdir_and_missing_profiles(self):
        zdot = self.home / "custom"
        self.write("custom/.zshrc", 'eval "$(starship init zsh)"\n')
        result = self.report({"ZDOTDIR": str(zdot)})
        self.assertIn(".zshrc:1 PROMPT", result)

    def test_goenv_and_environment_are_distinguished(self):
        self.write("Library/Application Support/go/env", "GOTOOLCHAIN=go1.26.0\nGOSUMDB=off\nOTHER_SECRET=private\n")
        result = self.report({"GOTOOLCHAIN": "auto"})
        self.assertIn("GOTOOLCHAIN=auto", result)
        self.assertIn("GOTOOLCHAIN=go1.26.0", result)
        self.assertIn("GOSUMDB=off", result)
        self.assertNotIn("OTHER_SECRET", result)

    def test_goenv_off_does_not_read_saved_settings(self):
        self.write("Library/Application Support/go/env", "GOTOOLCHAIN=go9.99.0\n")
        self.assertNotIn("go9.99.0", self.report({"GOENV": "off"}))

    def test_nearest_module_workspace_and_explicit_workspace(self):
        self.write("go.mod", "module secret.example/internal\ngo 1.23.0\n")
        self.write("project/go.mod", "module secret.example/project\ngo 1.26.0\ntoolchain go1.26.1\n")
        work = self.write("somewhere/go.work", "go 1.26.2\nuse ../private\n")
        result = self.report({"GOWORK": str(work)})
        self.assertIn("go 1.26.0", result)
        self.assertIn("toolchain go1.26.1", result)
        self.assertIn("go 1.26.2", result)
        self.assertNotIn("go 1.23.0", result)
        self.assertNotIn("secret.example", result)
        self.assertNotIn("../private", result)

    def test_gowork_off(self):
        self.write("go.work", "go 1.99.0\n")
        self.assertNotIn("go 1.99.0", self.report({"GOWORK": "off"}))

    def test_size_and_number_limits(self):
        self.write(".zshrc", "x" * (DIAG.MAX_BYTES + 1))
        self.assertIn("больше 256 KiB", self.report())
        self.write(".zshrc", '\n'.join('source "$HOME/file' + str(i) + '"' for i in range(50)))
        self.assertIn("LIMIT", self.report())

    def test_starship_config_is_not_claimed_as_cause(self):
        self.write(".config/starship.toml", '[golang]\ndisabled = true\nformat = "private"\n')
        result = self.report()
        self.assertIn("GO_MODULE_DISABLED", result)
        self.assertNotIn('"private"', result)
        self.assertIn("не подтверждение причины", result)

    def test_dynamic_source_is_not_expanded(self):
        for expression in ('"${UNKNOWN}/a"', '`touch missing`', '"$(touch missing)"', '*.zsh', 'a; echo bad'):
            with self.subTest(expression=expression):
                self.assertIsNone(DIAG.source_target(expression, self.home, self.home, self.cwd))

    def test_comment_and_terminal_controls(self):
        self.write(".zshrc", "# go version\n# source /not-real\n")
        result = self.report({"GOTOOLCHAIN": "auto\x1b[31m"})
        self.assertNotIn("GO_CALL", result)
        self.assertNotIn("\x1b", result)


class DiagnosticsCLITest(unittest.TestCase):
    """Граница e2e — настоящий публичный CLI, без импорта реализации."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        self.project = self.home / "project"
        self.project.mkdir()
        self.env = dict(os.environ)
        for key in (*DIAG.ENV_KEYS, "STARSHIP_CONFIG", "XDG_CONFIG_HOME", "PYTHONHOME", "PYTHONPATH"):
            self.env.pop(key, None)
        self.env.update(HOME=str(self.home), USERPROFILE=str(self.home))

    def run_cli(self, *args):
        return subprocess.run([
            sys.executable, "-X", "utf8", "-B", str(ROOT / "nvim_forge/scripts/diagnose-shell.py"),
            "--home", str(self.home), *args,
        ], cwd=self.project, env=self.env, capture_output=True, text=True, encoding="utf-8", timeout=10)

    def test_report_from_problem_directory_without_executing_or_writing(self):
        marker = self.home / "must-not-exist"
        (self.home / ".zshrc").write_text(
            'touch "' + str(marker) + '"\nexport PRIVATE_TOKEN=never-in-report\n'
            'export PATH="$(go env GOPATH)/bin:$PATH"\n', encoding="utf-8")
        (self.project / "go.mod").write_text("module private.example/project\ngo 1.26.0\n", encoding="utf-8")
        self.env.update(GOTOOLCHAIN="auto", GOSUMDB="off")
        before = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("GO_CALL", result.stdout)
        self.assertIn("go 1.26.0", result.stdout)
        self.assertIn("GOSUMDB=off", result.stdout)
        self.assertNotIn("never-in-report", result.stdout)
        self.assertNotIn("private.example", result.stdout)
        self.assertFalse(marker.exists())
        after = {str(p.relative_to(self.home)): p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_dynamic_source_is_reported_without_execution(self):
        (self.home / ".zshrc").write_text('source "$(go version)"\n', encoding="utf-8")
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SOURCE_DYNAMIC", result.stdout)
        self.assertNotIn("downloading", result.stderr)

    def test_empty_home_without_go_or_shell(self):
        self.env["PATH"] = str(self.home / "no-tools")
        result = self.run_cli()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("IDE-001", result.stdout)

    def test_bad_directory_is_actionable_error(self):
        result = self.run_cli("--cwd", str(self.home / "missing"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("HOME", result.stderr)
        self.assertNotIn("Traceback", result.stderr)


class TestEntryPointsCLI(unittest.TestCase):
    """CLI обёртки → настоящий дочерний nvim-stub с проверкой argv/exit code."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        (self.root / "scripts").mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        self.env["PATH"] = str(self.bin) + os.pathsep + self.env.get("PATH", "")
        if os.name == "nt":
            self.shell = shutil.which("powershell") or shutil.which("pwsh")
            self.script = self.root / "scripts/test.ps1"
            shutil.copyfile(ROOT / "scripts/test.ps1", self.script)
            (self.bin / "nvim.cmd").write_text('@echo off\necho argv:%*\nexit /b 0\n', encoding="ascii")
            self.prefix = [self.shell, "-NoProfile", "-File", str(self.script)]
        else:
            self.shell = shutil.which("bash")
            self.script = self.root / "scripts/test.sh"
            shutil.copyfile(ROOT / "scripts/test.sh", self.script)
            stub = self.bin / "nvim"
            stub.write_text('#!/bin/sh\nprintf "argv:"\nprintf "<%s>" "$@"\nprintf "\\n"\n', encoding="ascii")
            stub.chmod(0o755)
            self.prefix = [self.shell, str(self.script)]
        if not self.shell:
            self.skipTest("нет системного shell для CLI entrypoint")

    def call(self, mode):
        return subprocess.run(self.prefix + [mode], cwd=self.root, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_quick_and_e2e_forward_whole_suite_argument(self):
        # Регресс: PowerShell scalar-splat превращал 'unit' в u/n/i/t.
        for mode, suite in (("quick", "unit"), ("e2e", "e2e")):
            with self.subTest(mode=mode):
                result = self.call(mode)
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = "argv:-l tests/run.lua " + suite if os.name == "nt" else "argv:<-l><tests/run.lua><" + suite + ">"
                self.assertIn(expected, result.stdout)

    def test_unknown_mode_does_not_run_tests(self):
        result = self.call("unknown-mode")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("argv:", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
