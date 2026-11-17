# Design

## Context

Runtime §267 уже использует upstream Sqruff. Language tools готовятся Mason;
native parsers входят в Core. Frontend ошибочно приравнивает каждую language
feature к native archive. Source and explicit runtime bundle APIs независимы.

## Goals / Non-Goals

**Goals:** базовые profiles/setup/catalog/inventory согласованы, старые явно
переданные bundles и ручная подготовка advanced tools работают.

**Non-Goals:** удаление advanced кода/данных, SDK packaging, новая установка
SDK/версий, публичный release или автоматический Docker/WSL lifecycle.

## Decisions

- Runtime catalog выбирает только physical IDE parts Core/Terminal.
  Language flags сохраняются для parsers/Mason и native SDK discovery.
- Basic Bash TSV исключает debug adapter; no-mask catalog исключает sqls.
  Известный pin Bash adapter остаётся для явной ручной подготовки.
- Tools setup не патчит Bash DAP. Native SQL readiness применяется только
  при фактическом наличии optional bundled SQL executable, не по флагу sql.
- Inventory использует тот же Core/Terminal состав; явно переданный optional
  SQL archive учитывается отдельно с его source/licenses.
- Прямые legacy install scripts не добавляют SQLite/Bats ради basic профиля.
- Transport fixture использует Terminal как физический part, отдельно от
  Node prerequisite. Optional SQL delivery передаёт полный bundle явно.

## Risks / Trade-offs

- Старые catalogs содержат языковые rows → они валидируются, но не скачиваются
  по базовому language flag; явный runtime-path остаётся совместимым.
- Basic tools всё ещё требуют готовности providers/SDK → no success без
  существующего setup readiness, никакие проверки готовности не отключаются.
- Нет full Default публикации/Mac → отдельные gates остаются явно в плане.
