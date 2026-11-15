# Проверка IDE-BOOT-21

2026-11-15, Windows + готовый Ubuntu container. Native macOS и настоящие
package installs не выполнялись. Целевая итерация, без полного editor runner.

## Реализация

- Missing-manager ErrorKind::NotFound отделён от ошибок существующего manager.
- WindowsApps alias / standard Homebrew prefix учитываются после PATH.
- Bootstrap confirmation по умолчанию No, затем отдельное SDK confirmation.
- Official WinGet module/provider CurrentUser; reuse existing module, repair
  current user без AllUsers/prerelease. Homebrew official script pinned commit.
- No/error/noop/Escape/retry/cancel/headless доступны без публикации false ready.
- Mac SDK discovery использует standard bin, сохраняет лишь SDK directories.

## Native проверки

| Среда / набор | Результат | Доказательство |
|---|---|---|
| Windows source RED, case02 | ожидаемый1 FAIL30.454s: старый UI не предлагает bootstrap | .tests/sdk-bootstrap-source-red-windows.txt |
| Windows bootstrap v1 | 4 PASS/5 FAIL18.998s, fixture snapshot запрещал разрешённый alias | .tests/sdk-bootstrap-windows-v1.txt |
| Windows адресные5 после fixture fix | 5 PASS20.706s | .tests/sdk-bootstrap-targeted-windows-v2.txt |
| Windows усиленный case02 | 1 PASS16.915s; сам PS script +4 cmdlet scenarios | .tests/sdk-bootstrap-cmdlets-windows-v3.txt |
| Windows SDK actions controls | 12 PASS29.853s | .tests/sdk-bootstrap-actions-windows-v1.txt |
| Ubuntu bootstrap/headless | 1 PASS/8 platform skips3.862s | .tests/ubuntu/sdk-bootstrap-ubuntu-v1.txt |
| Ubuntu SDK actions | 12 PASS7.070s | .tests/ubuntu/sdk-bootstrap-actions-ubuntu-v1.txt |

В совокупности все9 Windows bootstrap cases проверены (8 PTY +1 noninteractive).
Тестовый WinGet имеет отдельный fixture LocalAppData, а guards ordinary nvim,
shell profiles и других foreign files остаются включены. Actual SDK installs
заменены native fixture manager, backend использует настоящий Neovim/private
kit/launcher с fixture init/tools. Это не full release readiness.

Сам Windows PowerShell recipe из UI process trace исполняется через native
PowerShell с локальными cmdlet functions: provider/module missing, existing
module, existing provider, module failure не доходит до repair. Реальные
Install-Module/Install-PackageProvider/Repair commands на host не вызываются.

Homebrew upstream source downloaded read-only в .tests, не запускался;
commit e5b3c5834e3932c8aaa42deef4794076c9b0cbf0, script SHA256
5f333bbe53bc490e51e7ccb1df8779b3dd6ee73a1a7379efda216edb08ccb148.
Native Mac bootstrap требует clean stand без установленного standard brew;
этот gate не подменяется Linux результатами.

## Сохранность и cleanup

SDK binary, Cargo.lock, lazy-lock, backports и сторонний WIP проверяются против
.tests/sdk-bootstrap-baseline.json. Raw журналы имеют прежний byte prefix;
staged normalized journals — прежний HEAD blob prefix. Результат audit.json.
Удалены только собственные runtime/prepared/archive payloads внутри проверенных
.tests/install-isolation roots: 1210544341bytes, 33 paths, 73 metadata references
сохранены. Linux тяжёлые файлы были /tmp и исчезли вместе с контейнером.

## Следующий gate

Release Core/IDE tools inventory и функциональная готовность Default, затем
native Mac acceptance и публикация. Пустой production artifact catalog не
выдаётся за готовую публичную one-line установку.
