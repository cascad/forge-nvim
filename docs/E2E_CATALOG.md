# Учёт E2E

Каталог связывает requirement из OpenSpec с существующим запускаемым E2E.
Он собирается из тех же спецификаций, tasks, tests/registry.lua и native Python
inventory, которые использует общий runner. Второго ручного списка фич нет.

| Состояние | Значение |
|---|---|
| REGISTERED | Файл существует и запускается как E2E; результат на ОС смотреть в отчёте прогона |
| PENDING | Change ещё не завершён, обязательный E2E пока отсутствует |
| MISSING | Готовое либо явно выбранное требование не имеет E2E; gate завершается ошибкой |

Unit/manual не заменяют E2E. Наличие файла не доказывает полноту сценариев,
runtime PASS или проверку macOS. Python installer suites берутся из общего
batch_plan.native_suites, native CLI plan/Core-gate cases находятся в
tests/e2e/test-batch.test.lua. Чистые selection unit остаются отдельно.

## Команды

Из корня, выбранным подготовленным Neovim:

```sh
nvim -l tests/trace.test.lua --catalog-json .tests/e2e-catalog.json
nvim -l tests/trace.test.lua --change CHANGE_NAME
```

`--change` требует E2E до завершения tasks; неизвестный change — ошибка.
Обычный tests/run.lua также сохраняет каталог в report.json → e2e_catalog;
runner каждого пути указан в runners. Проверка metadata не запускает редактор,
SDK, установку или E2E из ссылок. Native CLI self-tests — отдельный сценарий.

В §279 root catalog не имеет MISSING; SQL semantic references IDE-SQL-9 остаются
PENDING. Явная проверка этого change должна дать MISSING/exit1 до реализации;
текстовый поиск не считается semantic references. Native Mac gate открыт.
