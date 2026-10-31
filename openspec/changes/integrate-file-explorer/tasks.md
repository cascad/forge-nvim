# Tasks

## 1. Файлы и общий маршрут дерева

- [x] 1.1 Добавить настоящий editor E2E создания/rename/move/cut-paste/отмены/конфликта и управления панелью; сохранить red исходной сборки (Windows, tests/e2e/file-explorer.test.lua).
- [x] 1.2 Подключить Space w e, источник/слот, фокус/help/q/Esc/zoom с сохранением selector; исправить воспроизведённые файловые сбои. Проверка тем же E2E на Windows/Ubuntu.
- [x] 1.3 Выполнить регресс Windows unit/e2e/wezterm/trace и Ubuntu Docker full; strict validate integrate-file-explorer.
- [x] 1.4 Дописать историю FIXLOG §78–82, HISTORY, roadmap/PROBLEMS/шпаргалку/каталог команд и матрицу покрытия с реальными результатами и ограничениями.
- [ ] 1.5 Владелец: macOS scripts/test.sh e2e, GUI WezTerm и физические сочетания; здесь Mac/GUI не проверены.

## Результат 2026-10-31

Windows Neovim 0.12.2: 27 файлов PASS, 0 FAIL, 0 SKIP (260.5 с),
.tests/windows-files-complete-regression.txt. Ubuntu 24.04/Neovim 0.12.2:
28 PASS, 0 FAIL, 3 SKIP, 29 файлов/31 прогон (72.9 с),
.tests/ubuntu-files-complete-recheck-full.txt. Все 7 новых, 6 Outline и 4 Debug
E2E PASS на обеих ОС. SKIP — прежние WezTerm/Bash 3.2 ветки, Mac/GUI не запускались.
Strict validate и git diff --check PASS. История/границы — FIXLOG §78–82.

Предыдущий Ubuntu full после Esc-fix имел один unit FAIL из-за 30s timeout
nvim_keymaps при успешных editor E2E; причина не установлена. Отдельный набор
дал 46 PASS, затем полный Ubuntu recheck выполнен без параллельного Windows.
Лимиты/код ради таймаута не менялись, исходный лог сохранён отдельно.
