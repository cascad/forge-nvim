# Tasks

## 1. Наблюдения

- [x] 1.1 Добавить bounded native code-window probe; пять profiles Windows завершаются без API ошибок/утечек, JSON показывает реальные ids и session-файл.
- [x] 1.2 Повторить пять profiles Ubuntu на уже доступном engine, проверить исходники/exit/scopes; macOS остаётся явным gate.
- [x] 1.3 Сопоставить результаты и source в CODE_WINDOW_REVIEW, обновить ROADMAP/PANEL_OWNERSHIP_REVIEW, новые проблемы, append-only FIXLOG §155 / HISTORY / AGENT_COMMANDS §68; проверить prefix SHA.

## 2. Интеграция

- [x] 2.1 Strict OpenSpec 72/72, diff check и неизменность production Lua/SDK/lock проверены, обзор и probe закоммичены; поведение не менять в этом change.
- [ ] 2.2 Native macOS probe выполнен владельцем и результат добавлен; до этого change не архивировать.
