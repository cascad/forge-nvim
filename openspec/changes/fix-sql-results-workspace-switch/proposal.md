# Proposal

## Why

IDE-068: SQL Results может показывать cached rows другого workspace после
явного Space j o. В d43c094 ide.sql.select меняет root/record, но не buffer;
ide.show пропускает open для уже видимого компонента, где выполняется render.
Нужно подтвердить последовательностью двух настоящих SQLite workspace и
сверить не только client state, но видимые rows/header без повторного SQL.

Связанные требования IDE-SQL-3 находятся в незавершённом change
add-sql-edit-query-workflow; основной каталог specs пока не содержит SQL.

## What Changes

- При явном выборе Results отобразить сохранённый результат выбранного root
  независимо от того, видима панель или скрыта.
- Пустой workspace показывает отсутствие результатов, поздние ответы не
  подменяют явно выбранный root. Навигация не запускает SQL.
- Постоянный real editor E2E, source d43c094 RED, история и docs.

## Capabilities

### New Capabilities

- `sql-workflow`: IDE-SQL-6 — выбор и отображение cached output workspace;
  используется тот же capability path, что в исходном SQL change.

### Modified Capabilities

Нет требований SQL в main specs. IDE-SQL-1–5 исходного change сохраняются.

## Impact

ide/sql.lua и SQL UI E2E/guide/история; без изменения backend/SDK/plugin pins.
Общая логика для Windows/macOS/Ubuntu; Windows проверяется здесь, остальные
среды не объявляются PASS без запуска. Temp/artifacts на F:.
