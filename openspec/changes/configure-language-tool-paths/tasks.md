# Tasks

## 1. Пути Python Node Bash

- [x] 1.1 Реализовать bounded JSON user/project settings, resolver и ForgeToolPaths; подключить Python/Node/Bash/Bats/JS adapters без изменения native discovery. Проверка: редакторный tests/e2e/tool-paths.test.lua, Windows; Ubuntu при готовом engine, Mac отдельно.
- [x] 1.2 Добавить E2E настоящих процессов, приоритетов, legacy/venv, invalid paths/config, смены проекта и adapter entrypoints; зарегистрировать без включения чужого WIP. Проверка: один целевой прогон IDE-BOOT-33 и контроль no startup install.
- [x] 1.3 Описать формат/остаток в руководстве и roadmap, записать FIXLOG `Спека: IDE-BOOT-33 (ADDED)`, HISTORY/commands. Проверка: OpenSpec strict, diff/prefix/frozen проверки, локальный commit.
