# Tasks

## 1. Native readiness и fallback

- [x] 1.1 Добавить явный prepare_fzf поверх pinned editor SDK и поздний Ubuntu image слой; проверить Windows CMake build, source/artifact SHA в manifest и документировать команду подготовки.
- [x] 1.2 Добавить постоянный native E2E: готовая библиотека без CMake, missing с/без CMake, corrupt; проверить реальный поиск/переход/scoring и получить Windows source RED.
- [x] 1.3 Убрать runtime build-tool cond, сохранять фактический load result для read-only health; проверить весь новый Windows E2E, health до/после picker и отсутствие startup builds.
- [x] 1.4 Обновить docs/roadmap/review/PROBLEMS, FIXLOG со строкой `Спека: IDE-BOOT-5 (FIX)`, HISTORY и команды; проверить append-only prefixes и Git diff.

## 2. Интеграция

- [x] 2.1 Построить только новые Ubuntu image слои, прогнать новый suite, editor/buffers/work-panels Windows/Ubuntu последовательно; проверить native C calls, manifests/config/exit/scopes и реальный F5 launch.json picker (go-passive late Delve case).
- [x] 2.2 Прогнать unit/trace и strict OpenSpec; выполнить review, сохранить evidence и закоммитить шаг.
- [ ] 2.3 Выполнить native macOS/ARM64 проверки и записать результат; до реального запуска gate открыт, change не архивировать.
