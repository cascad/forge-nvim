# Verification — 2026-11-17

IDE-BOOT-37. Реализация и целевые native проверки Windows/Ubuntu завершены.
macOS требует отдельного прогона владельцем; полный Default этим не закрыт.

## Реализованное поведение

- Space l S / ForgeSdk: native vim.ui.select/input, Go/Rust, async discovery,
  проверенные версия/executable/источник, manual path/refresh/cancel.
- User/project sdk.json, project priority и explicit Auto. Atomic save,
  source-aware errors, invalid/corrupt config не заменяется молча.
- Early filesystem-only selection без CLI scans; Auto восстанавливает baseline
  только затронутых ключей. SDK homes/cache/auth/system settings сохраняются.
- Native Neovim restart с прежним session/layout; target environment применяется
  до plugins. Active DAP/Neotest/Overseer/terminal запрещают SDK apply.
- Public Neotest client.running_positions дополняет отстающие UI counts.
  Probe Go отключает GOENV/GOWORK/GOFLAGS только у своего read-only subprocess.

## Целевые E2E

На каждой ОС **2 новых PASS + 2 controls PASS** отдельными целевыми запусками,
без полного регресса. Go1.23.3/1.26.0, Rust1.91.1/1.96.1; настоящий native TUI,
восемь backend process instances. Discovery/manual paths с пробелами/user/project/Auto,
invalid/cancel/corrupt/active work, отсутствие installs, LSP environment,
реальные go/cargo run, Neotest, Delve/CodeLLDB pause/continue/output и compiler
versions. Project switch и курсор first.txt23,7 сохранены.

Raw logs в `.tests/toolchain-research/`:

| Проверка | Windows | Ubuntu |
|---|---|---|
| Настоящее меню | sdk-selector-menu-final-windows.txt | sdk-selector-menu-final-ubuntu.txt |
| Native SDK workflows | sdk-selector-native-identity-windows.txt | sdk-selector-native-accepted-ubuntu.txt |
| GoToolchain IDE-BOOT-4 | sdk-selector-go-passive-accept-windows.txt | sdk-selector-go-passive-control-ubuntu.txt |
| Project session IDE-PANEL-15 | sdk-selector-session-ready-windows.txt | sdk-selector-session-ready-ubuntu.txt |

Native artifacts: `.tests/editor-e2e/45158312111400` и
`.tests/ubuntu/editor-e2e/15151893534568`. Menu artifacts: 42991074780600 /
14245511087037. Final session control: 44694273354600 / 15812807029530.
sdk-selection.json фиксирует фактические SDK/PIDs/output; shutdown.json — exit0,
signal0, hard_kill=false и scope.active_after=0.

## Найденные причины и исправления

- Observer uv.spawn сначала обращался к vim.env в fast event; использует
  uv.os_getenv. Ввод native picker синхронизирован с readiness, выбор — Ctrl+n;
  Rust test fixture использует обычный mod tests, DAP configs имеют name.
  Это исправления проверяющего кода, результаты tools не подменяются.
- Active Neotest уже работал до обновления UI counts: guard использует
  существующий consumer и public client API. Persistent Go GOENV/GOROOT мог
  отвечать версией другой установки: read-only probe изолирует только свой env.
- Windows native functional scenario прошёл, но строгий Job drain обнаружил
  MSVC VCTIP.EXE. QueryInformationJobObject возвращает точные принадлежащие
  тесту PID; проверяется executable path VC/Tools/MSVC/.../VCTIP.EXE. Только
  SDK case явно разрешает этот compiler helper после завершения всех native
  редакторов, затем закрывает собственный Job. Неизвестный остаток — FAIL;
  общий session control требует естественного drain без разрешения helper.
  Ошибочная гипотеза conhost проверена и отвергнута; detach/FreeConsole/transport
  эксперименты отменены. Системные SDK/VS settings/чужие процессы не менялись.
- Existing Windows IDE-PANEL-15 дважды поймал замену first.txt на third.txt.
  Снимок before-switch уже содержал подмену: тест вводил команды после
  появления файлов, пока async session views ещё переключали вкладки.
  Observer отмечает штатный session_loading(false); диагностика ждёт именно
  завершение views и выбор второй вкладки. Layout/cursor assertions не ослаблены.
  После изменения Windows/Ubuntu controls PASS; production restore не менялся.
- Последний Windows повтор получил PID ранее завершившегося backend. Lifecycle
  показывал новый VimEnter/ready после VimLeave; глобальная уникальность PID
  ошибочно отвергала штатное переиспользование ОС. Теперь проверяются восемь
  native process instances, смена предыдущего PID и возрастающий ready timestamp.
  Промежуточный счётчик не включал initial launch (7 вместо8); bookkeeping
  исправлен. Финальный Windows native identity run PASS, включая shutdown guard.
  Ubuntu native PASS относится к предыдущему запуску; новый observer/count
  проверен Windows, сами product code/SDK workflows после Ubuntu не менялись.

## Подготовка и границы

Windows использовал существующие native SDK; Ubuntu — существующий offline
image, source RO, private prepared plugin copy. Отдельный явный
prepare-sdk-selection.sh скачал официальные тестовые Go1.23.3/Rust1.91.1 через
Go/rustup в `.tests/ubuntu/sdk selection` на F. Это тестовый home/cache, не
startup/install feature; системные SDK/image/Desktop/WSL не менялись.
После подготовки product E2E выполнялись без сети. Failed owned controller
был остановлен после проверки его точного PID/command line; его Job закрыл
собственных потомков. Общих завершений процессов по имени не было.

OpenSpec strict, diff/staged checks, baseline frozen25, raw/staged append-only
журналы и exact owned index проверяются перед локальным коммитом. Registry
получает только SDK entry; посторонние WIP entries остаются вне коммита.
Native Mac/physical keys/publication/полный Default остаются открытыми.
