# Проверки законченного блока

Решение владельца 2026-11-18: E2E нужны для каждой фичи и исправления, но
запускаются после цельной реализации, а не после каждого изменения файла.

## Когда запускать

1. Во время реализации — чтение кода, syntax/diff и быстрые проверки. Native
   воспроизведение нужно при расследовании бага, когда без него нет доказательства.
2. Когда код и тесты всего блока готовы — один пакет затронутых файлов на каждой
   доступной ОС. Список и ожидаемые проверки записать до запуска.
3. Если пакет упал — разобрать лог, поправить причину и повторить failed case
   либо affected files. Уже прошедшие несвязанные suites не повторять.
4. Большой `regression` — после завершения крупного этапа, перед выпуском или
   рефакторингом общей основы. Не добавлять его к каждой локальной правке.

Native macOS прогон отдельно выполняет владелец. Запуск на Windows не доказывает
работу macOS. Команды не устанавливают и не перенастраивают Docker/WSL.

## Команды блока

Из корня репозитория, после отдельной подготовки зависимостей:

```powershell
./scripts/test.ps1 quick
./scripts/test.ps1 e2e -Files @('tests/e2e/setup-sdk-paths.test.lua','tests/install-setup.test.py') -Plan
./scripts/test.ps1 e2e -Files @('tests/e2e/setup-sdk-paths.test.lua','tests/install-setup.test.py')
```

При вызове через `powershell -File` из другого shell передача массива зависит
от shell; переносимый вариант — прямой Python с повторяемым `--file`:

```sh
python3 -B scripts/test-batch.py --nvim nvim --mode e2e --file tests/e2e/setup-sdk-paths.test.lua --file tests/install-setup.test.py --plan
bash scripts/test.sh e2e --file tests/e2e/setup-sdk-paths.test.lua --file tests/install-setup.test.py
```

Windows прямой Python: `python -B ... --nvim .tools/neovim/windows-x64/bin/nvim.exe`.
Список может смешивать зарегистрированные Lua/shell тесты и native
`tests/*.test.py` (installer/release). Неизвестные/повторённые имена отклоняются до E2E.
Выбор через `--file` запускает целые файлы независимо от inherited case filters.
Для отдельного failed case остаётся прямой запуск файла с его documented filter.

## Полный regression

```powershell
./scripts/test.ps1 regression -Plan
./scripts/test.ps1 regression
```

```sh
bash scripts/test.sh regression --plan
bash scripts/test.sh regression
```

`regression` = весь прежний `full` для ОС + все native Python suites из корня
tests/, включая установщик и release inventory.
`full` сохранён для совместимости и охватывает только прежний registry: ранее
он не включал отдельные installer Python suites. На Windows полный registry
также содержит ConPTY и POSIX shell-наборы; последним нужен уже подготовленный
WSL. Старый runner вызывает `wsl.exe` и может запустить установленный дистрибутив;
если он недоступен, будет SKIP. Для блока без POSIX suites этот вызов не нужен.
Команда не устанавливает зависимости, не запускает Docker Desktop и не меняет
WSL configuration. Plan ничего из этого не вызывает.

PASS с SKIP не означает проверку отсутствующей среды; список SKIP надо читать
в `.tests/report.json`. Physical GUI/горячие клавиши на машине владельца —
отдельная проверка. `--plan` выполняет только лёгкое чтение Lua registry.

## Время и результаты

Пакет идёт последовательно. Сохраняются plan.json, report.json, exit codes,
время и отдельный log каждой команды в `.tests/batches/<stamp>/`. Для registry
используется прежний tests/run.lua с его таймаутами и `.tests/report.json` /
`.tests/logs`; его отчёт содержит длительность каждого файла. Standalone installer
suite имеет deadline30 минут; timeout прекращает дальнейший batch с ошибкой.
Унаследованные `FORGE_TEST_ID`/`FORGE_*_CASE` очищаются, их имена видны в плане.

Основная цена editor E2E — свежий профиль, копирование prepared plugins и запуск
настоящих LSP/debug/tests, иногда несколько restart. Пока не меняем их изоляцию
и не распараллеливаем тяжёлые suites. Сначала получаем времена большого прогона,
потом отдельно оптимизируем самые дорогие fixtures с сохранением регрессов.

В существующем Ubuntu driver `tests/containers/tool-paths.sh --batch ...`
тяжёлые installer runtime-копии находятся в `/tmp` контейнера через уже
поддержанный FORGE_INSTALL_STAND_ROOT. На Windows host temp остаётся на диске
репозитория. На bind mount сохраняются доказательства, без повторного копирования
бинарных SDK/архивов. Это не уменьшает состав тестов.
