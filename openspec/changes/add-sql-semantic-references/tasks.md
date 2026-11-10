# Tasks

Решение 2026-11-10: своё language ядро отменено. References не готовы;
change не архивируется как выполненный и не применяется к main specs.

## 1. Историческое воспроизведение и отмена прототипа

- [x] 1.1 Исходный editor RED forge.1 сохранён в Git 341aba2/FIXLOG §142: raw -32601/provider=false, gr без quickfix, SDK/test/config/screen и штатный shutdown. Это историческое доказательство отсутствующей фичи, не готовый runtime suite.
- [x] 1.2 Сохранить SHA snapshot собственного незакоммиченного prototype на F:, убрать resolver/handler/index и только их tooling/fixtures/registry entry, вернуть SQL test helper. Проверить прежние SQL UI/SDK, unit/trace/strict и неизменные product Lua/pins/SDK; дописать FIXLOG/HISTORY/команды/план.

## 2. Выбор готового backend

- [ ] 2.1 В IDE-080 review сравнить готовые SQL backend по IDE-SQL-9, диалектам/ОС/установке/сопровождению и primary sources. Доставить таблицу capabilities/evidence/ограничений; отсутствие кандидата не закрывает references и не разрешает свой binder/LSP.
- [ ] 2.2 При подтверждённом кандидате сделать изолированную штатную интеграцию и editor E2E gr/quickfix/Enter, names/scopes/CTE/DML, unsaved/closed files, Unicode/workspace boundary. До выбора кандидата задачу не выполнять.

## 3. Интеграция подтверждённого готового решения

- [ ] 3.1 Зафиксировать explicit setup/version/source policy готового backend без private engine, проверить readiness и отсутствие startup install/лишней SQL session; SQL docs/FIXLOG со Спека: IDE-SQL-9 (ADDED).
- [ ] 3.2 Последовательно Windows/доступный Ubuntu: references и прежние query/Tests/panels E2E, cleanup, unit/trace/strict, история/PROBLEMS/матрица/план и commit. Provider flag/unit не закрывают feature.
- [ ] 3.3 На Mac владельца выполнить применимые native/editor/GUI сценарии, сохранить реальные результаты; до запуска Mac/ARM64/GUI/внешние DB непроверены.
