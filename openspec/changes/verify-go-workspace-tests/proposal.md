# Proposal

## Why

Go.work root без go.mod обнаруживает оба модуля, nearest работает, но Run all
зависает: neotest-golang.runspec.dir вызывает file_upwards('go.mod'), который
вне HOME не завершает обход корня диска. Windows source E2E20672770046900 и
диагностический стек21109013024200 указывают find.lua:37/dir.lua:85. Это пробел
WF-12/общего IDE-TEST-5, теперь выделенный в IDE-TEST-7.

## What Changes

- Два тестовых файла app/shared к прежнему go.work fixture.
- Native E2E: открытая Tests panel обнаруживает оба модуля без открытия shared,
  nearest запускает один test, Run all из корня — все3, file — только shared.
- Реальные side-effect counters подтверждают объём каждого запуска.
- Один fail виден в Output; исправление assertion через редактор и Run all
  даёт3 passed. Обычные тесты не создают DAP session/float.
- Через public adapter build_spec не передавать unsupported container в
  backend: штатный nil fallback Neotest выполняет файлы в native module context.
- Workspace root с go.work и обычные каталоги без enclosing go.mod используют
  этот fallback; nearest/file/module suite остаются native.
- Команды выполняются последовательно штатной настройкой Neotest, ограничивая
  нагрузку fallback без собственной очереди. Private fields/Go parser нет.

## Capabilities

### New Capabilities

- `go-workspace-tests`: IDE-TEST-7, безопасный запуск workspace suite вне HOME.

### Modified Capabilities

IDE-TEST-1/5 не меняются; новый сценарий конкретизирует workspace module context.

## Impact

plugins/tests.lua и небольшой Go adapter context helper, два fixture файла,
один E2E/registry row, docs/история. SDK/pins/backports/общий consumer прежние;
новая штатная policy running.concurrent=false общая для ОС. Windows затем
Ubuntu; native Mac/physical и known POSIX scope gate отдельно.
