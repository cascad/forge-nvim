# Tasks

## 1. Файловые вкладки

- [x] 1.1 Добавить реальные editor E2E навигации/picker, safe-close Cancel/Save/Discard/ошибки, split/панелей, alpha/reopen; сохранить red исходника (Windows, tests/e2e/buffers.test.lua).
- [x] 1.2 Объединить модель, подключить старые aliases и Space b r, исправить воспроизведения. Проверить тем же E2E Windows/Ubuntu без plugin/confirm mock.
- [x] 1.3 Выполнить Windows unit/e2e/wezterm/trace и Ubuntu Docker full; strict validate stabilize-buffer-navigation.
- [x] 1.4 Дописать FIXLOG §83–84, HISTORY/PROBLEMS/roadmap/шпаргалку/каталог команд и матрицу тестов с фактическими результатами.
- [ ] 1.5 Владелец: macOS scripts/test.sh e2e, GUI/физические клавиши; здесь Mac/GUI не проверены.

## Результат 2026-11-01

Windows Neovim 0.12.2: 28 файлов PASS, 0 FAIL, 0 SKIP (282.5 с),
.tests/windows-buffers-full.txt. Ubuntu 24.04/Neovim 0.12.2 Docker:
29 PASS, 0 FAIL, 3 SKIP (30 файлов/32 прогона, 132.4 с),
.tests/ubuntu-buffers-full.txt. 8 новых E2E и прежние core/Go/DAP/neotest/
snippet/панели PASS на обеих ОС. SKIP прежние WezTerm/Bash 3.2 ветки.
Strict validate и git diff --check PASS. Прогоны Windows/Ubuntu выполнены
последовательно. Старый FIXLOG сохранён побайтово; история §83–84.
Открытый независимый конфликт terminal Ctrl-\\ зарегистрирован как IDE-023.
