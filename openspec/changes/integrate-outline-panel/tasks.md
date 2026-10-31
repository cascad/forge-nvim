# Tasks

## 1. Outline и общий маршрут

- [x] 1.1 Добавить настоящий Aerial E2E и сохранить воспроизведение на прежнем конфиге (Windows, IDE-PANEL-3).
- [x] 1.2 Объединить настройки, провести входы через ide.state и подключить controls; проверить символы/Enter/файлы/дерево/zoom/help/пустой файл в tests/e2e/outline.test.lua (Windows).
- [x] 1.3 Прогнать применимый регресс Windows и Ubuntu Docker: nvim -l tests/run.lua unit e2e wezterm trace; docker compose -f tests/containers/compose.yaml run --rm ubuntu full; strict validate change.
- [x] 1.4 Дописать FIXLOG §76/77 (Спека: IDE-PANEL-3 ADDED), HISTORY, проблемы/roadmap/инструкции/каталог команд и матрицу E2E с реальными результатами, включая Neo-tree lifecycle и q после AerialOpen.
- [ ] 1.5 Владелец: scripts/test.sh e2e на macOS; GUI WezTerm и физические клавиши. Здесь Mac/GUI не проверены.

## Результат 2026-10-31

Windows Neovim 0.12.2: 26 файлов PASS, 0 FAIL, 0 SKIP (158.7 с),
.tests/windows-outline-final-regression.txt. Ubuntu 24.04/Neovim 0.12.2 Docker:
27 PASS, 0 FAIL, 3 SKIP, 28 файлов/30 прогонов (96.1 с),
.tests/ubuntu-outline-final-full.txt. Шесть Outline и четыре Debug E2E PASS
на обеих ОС. SKIP — прежние WezTerm/Bash 3.2, Mac/GUI не выполнялись.
Strict validate PASS. Red и уточнения теста/интеграции — FIXLOG §76/77.
