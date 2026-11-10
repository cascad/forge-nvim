# Tasks

## 1. Постоянное воспроизведение

- [x] 1.1 Добавить tests/e2e/go-passive.test.lua и registry: настоящий offline Go future-module, явная версия, поздний реальный результат/смена контекста, GoToolchain и late Delve override; сохранить исходный Windows RED и source/artifacts до изменения runtime.

## 2. Пассивная metadata и поздний debug

- [x] 2.1 Сделать label/version только чтением, refresh с callback/контекстом и защитой старых результатов; проверить metadata/GoVersion/GoToolchain cases нового native E2E на Windows.
- [x] 2.2 Перенести Delve resolution на публичный DAP callback без изменения resolver/приоритетов и upstream closure; проверить late override настоящим F5/breakpoint/stdout Windows E2E.
- [x] 2.3 Обновить пользовательские docs и PROBLEMS/roadmap, дописать FIXLOG со строкой Спека: IDE-BOOT-4 (ADDED), HISTORY/commands и точными RED/GREEN/платформенными границами; проверить raw prefix и git diff.

## 3. Интеграция

- [x] 3.1 Прогнать Windows новый native suite и прежние go-language, dap-output, dap-discovery, test-runner, debug-panels; завершения/scopes/artifacts проверить фактически, а не по stdout PASS.
- [x] 3.2 Прогнать те же новые/прежние suites Ubuntu в уже доступном engine последовательно с Windows, без управления Docker/WSL; сохранить фактические exit/scopes/results.
- [x] 3.3 Выполнить unit/trace и strict OpenSpec validation, сверить implementation с задачами/spec, проверить history/явный staged diff и самостоятельно закоммитить завершённый Windows/Ubuntu шаг.
- [ ] 3.4 Прогнать native Mac те же применимые suites/команды; до реального запуска оставлять gate непроверенным и не архивировать change как полностью завершённый.

Windows: final go-passive 5 + прежние 22 PASS, 21 native profile/scopes проверены.
Ubuntu: окончательные 5 + прежние 22 PASS, diagnostic 2 PASS; настоящий gopls
restart/default-label проверены. Владелец включил временно недоступный Desktop,
агент lifecycle не менял. Mac 3.4 не запускался; change до native gate не архивируется.
