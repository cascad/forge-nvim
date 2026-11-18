# Verification — 2026-11-18

## Scope

Observer запускается managed launcher установленного kit. Parent/child используют
настоящие FRIDE_CONFIG/FRIDE_RUNTIME, NVIM_APPNAME=fride и owned profile.
Исходный config не подставляется. Существующий RPC/process cleanup, без второго
runner/setup/SDK install. Проверяются initialized LSP, diagnostics, исправление,
native :Format, save и исчезновение ERROR.

## Initial evidence

Windows1795018447032545100 и Ubuntu1795018457645435183 выявили product gaps
Pyright/Windows ShellCheck, исправленные отдельным change
use-native-managed-tool-entrypoints / FIXLOG §287.

Исправлены также дефекты observer: RPC nil приходит как vim.NIL; прежний90s
timeout ограничивал весь child; принудительный Cargo offline мешал uncached
rust-src metadata. Это не product fixes. Child имеет конечный срок всей матрицы,
каждый этап — отдельный deadline, partial report сохраняется.

## Installed matrix

После actual source archive upgrade Default/Custom (§287):

| Язык / настоящий LSP | Windows, секунды | Ubuntu, секунды |
|---|---:|---:|
| Go / gopls | 0.54 | 0.30 |
| Rust / rust_analyzer | 1.86 | 2.86, affected repeat |
| Python / pyright | 0.65 | 0.42 |
| Node / ts_ls | 1.19 | 1.52 |
| Bash / bashls | 0.95 | 0.86 |
| SQL / sqruff | 0.24 | 0.13 |

Windows весь пакет exit0,6.37s, report:
`.tests/default-acceptance/windows-x64/1795014050793199700/installed-languages/1795020511631048900/observed/report.json`.

Ubuntu1795020355667184771:5 PASS, Rust ERROR не исчезли: Cargo не мог создать
registry cache в read-only image `/opt/forge/cargo`. Для affected Rust-only
1795020460691815744 задан writable CARGO_HOME своего stand; прежние RUSTUP_HOME
и toolchain сохранены. Native Cargo получил std metadata; Rust прошёл,
exit0,3.27s. Продуктовый код ради этого отказа не менялся.
Копии reports/process/cleanup:
`.tests/ubuntu/default-acceptance/linux-x64/fride-default-f3fzzdaq/installed-languages/`.
Все три shutdown.json: ok=true. Initial failures сохранены отдельно.

## Limits

67 pinned Git repos/20 Mason packages подготовлены заранее. Это cached installed
language acceptance, не cold SDK install, не весь installed run/debug/tests
matrix и не GUI/физические хоткеи. Native Mac/Windows WSL/clean-machine/bootstrap/
publication остаются gates. SDK/locks/backports/старый UI не менялись; full не повторён.
