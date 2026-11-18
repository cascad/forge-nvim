# Verification — 2026-11-18

## RED and implementation

Installed Default Ubuntu: Pyright wrapper `/usr/bin/env node` падал, хотя Node
явно выбран в user settings. Windows BashLS не находил ShellCheck: native
consumer требовал executable за Mason batch export.

Pyright теперь использует существующий Node resolver/настоящий npm entrypoint,
сохраняя native roots/settings/before_init/Python. Shared resolver через публичные
InstallLocation/InstallReceipt API читает только свой receipt и возвращает native
.exe для Windows Mason export. Явные внешние paths не переписываются. BashLS
shellcheckPath/shfmt.path, Conform shfmt, Sqruff используют общую границу.
User Pyright/shfmt/shellcheck keys удовлетворяют setup как остальные ready tools.
Нет registry refresh/install, генерации wrappers, SDK patches или нового LSP.

## Native affected batch

Один пакет/ОС: Windows1795019835358564000, Ubuntu1795019848767004971.
Файлы: managed-entrypoints, Python, Bash, SQL-basic, Node, Go/Rust paths,
missing-tool-errors, trace, install-external-tools. Настоящие prepared tools;
новые exports имеют receipt/native payload и Windows batch traps exit97.

Initial registry каждой ОС49 PASS/2 FAIL/2 info SKIP; external setup16 PASS.
SQL case ожидал uppercase без .sqruff policy — fixture исправлен, продукт прежний.
Ubuntu Pyright один раз не дождался diagnostics; причина первого timeout
не установлена. Added native client/settings/diagnostics/LSP log capture;
affected suite затем3 PASS каждой ОС. Windows existing Python adapter-error
case получил RPC timeout/child SIGTERM; notification exit23 уже присутствовала.
Affected repeat того же case PASS без изменения DAP/helper/deadline. Причина
исходного timeout не установлена. Initial FAIL сохранены; остальные успешные
файлы не повторялись. Latest affected aggregate каждой ОС67 PASS/2 info SKIP.

Новые3 cases: выбранный Node вне PATH, настоящий Pyright и прежний Python;
ShellCheck SC2154/shfmt; Sqruff diagnostics/format и прежний external path.
External setup14→16 cases: Pyright JS+Node и native shfmt/ShellCheck.

## Actual archive upgrade

Source/Core/Terminal inputs и source-matched frontend, настоящие67 Git repos/
20 Mason packages, прежние SDK. Root installer вызван один раз на Default и
Custom Core каждой ОС. Windows16.54s/12.46s, Ubuntu5.19s/3.38s, все exit0;
20 receipts byte-identical. Собственный driver `--resume --upgrade-only` не
повторял initial install/Core workflow. Reports upgrade-acceptance.json в stands
§285, initial acceptance сохранён. Installed six-language workflow прошёл обе
ОС с отдельным Rust-only repeat из-за Cargo cache permissions:
[точные результаты](../verify-installed-language-consumers/verification.md).

## Remaining gates

Native Mac, Windows WSL/Bash debug, cold SDK/bootstrap, весь installed debug/test
matrix и public release не объявлены PASS. Desktop/WSL tests не запускают.
Tmp/cache F; existing image2CPU/3GiB без build/pull; сеть только своего preparation
container. SDK/locks/backports/старый frontend и Rust UI sources не менялись.
Full не повторялся.
