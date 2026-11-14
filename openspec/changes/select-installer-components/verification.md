# Verification

2026-11-14, IDE-138 / IDE-BOOT-10, base ab2586c. Feature selection,
не complete clean-machine install.

## Финальные результаты

- Windows PowerShell5.1:19 PASS tests/install-profile.test.py.
- Native Ubuntu:18 PASS/1 Windows-only skip того же stand.
- Windows arrows/j/k/Space/Enter/q:2 targeted UI cases PASS после расширения
  ввода стрелками; остальные unchanged cases не повторяли.
- macOS package recipe:3 contract PASS в Ubuntu, не native Mac.
- Existing setup stand: по7 PASS Windows/Ubuntu. Legacy shells:26+127 PASS Ubuntu.

HTTP entry/archive/extraction/cache настоящие; backend transport fixture.
UI: настоящий Neovim --embed с nvim_ui_attach, native PTY PowerShell/Bash,
реальные keys, q/cancel до backend. Core protected, Go снят, остальные
сохранены; Default без UI, explicit CSV/empty/invalid проверены. Canonical
dependencies Python→Node и SQL→Go не включают JS/Go tools и parsers.
Native Lua policy исполняет реальные opts из repo lsp.lua; runtimepath
изолирован от других конфигов. OS package-provider contracts вызывают реальные
installer scripts с fixture winget/apt/brew/nvim; host packages не устанавливаются.
Actual compatible SDK/registry/binary readiness этими cases не подменяется.

## Сохранённые итерации

1. Windows14/6 FAIL: policy probe -uNONE всё равно искал module через runtimepath
   другого профиля, где opts table;4 failures.2 UI failures: Console input
   precheck отвергал initial headless PTY. Repo policy отделён явным runtimepath,
   Windows picker использует public PowerShell Host RawUI.
2. Windows14/2 FAIL: policy проходит, headless host не отдаёт screen updates.
   Menu observer перенесён в UI-attached Neovim (как рабочий editor terminal).
   Timeout/forced termination и оставшиеся staging первых FAIL сохранены,
   не считаются успешным cancel и не очищены ради green.
3. Windows19 PASS с package gates. Далее добавлена настоящая стрелка вниз к
   keyboard flow; targeted2 Windows PASS. Ubuntu использует финальный helper.
4. Первый controls launcher ошибся guest path /workspace/.tests/ubuntu/...,
   exit127 до любого test. Исправлен только путь/копия private driver в overlay;
   выполнены Mac3/setup7/legacy153, исходный launcher log сохранён.

Raw logs .tests/profile-windows{,-v2,-v3,-arrows}.txt, profile-ubuntu.txt,
profile-controls-ubuntu{,-final}.txt; per-case reports/UI/native policy/package
operations в install-bootstrap/<id>, guest equivalents .tests/ubuntu.

## Границы

Native Mac/Bash3.2 не запускался. Full selected SDK delivery, Node/Go compatible
versions, missing package-manager bootstrap, Windows font/config, WSL/Bats/
JS/SQL SDK preparation и readiness registry/actual binaries остаются IDE-138.
Меню и current OS/Mason/parser gates готовы, полная Default installation — нет.
Normal startup/manual catalog без mask сохраняется. Host temp F, ready Docker
28.5.1 без lifecycle/build/pull, Win/Linux serial. SDK/67 pins/backports/frozen
infra drafts прежние; история append-only. Источники новых package IDs —
official Winget repo и Mason registry, ссылки в INSTALLATION_PLAN.md.
