# Проверки законченного блока

Решение владельца 2026-11-18: E2E нужны для каждой фичи и исправления, но
запускаются после цельной реализации, а не после каждого изменения файла.

[Каталог покрытия и проверка готовности change](E2E_CATALOG.md) использует общий
registry/native inventory. Он проверяет наличие E2E, результаты ОС смотрятся
отдельно. Каталог не запускает тяжёлые suites по ссылкам и не заменяет их прогон.

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

## Входы Core acceptance

`regression -Plan` показывает `ready` и `missing_inputs`. Core acceptance
требует подготовленный комплект и его отдельный тестовый профиль, либо
подготовленные native inputs. Без них actual batch возвращает2 **до любых
тестов**; Core suite не пропускается и ничего автоматически не устанавливается.

Для установленного комплекта:

```powershell
$env:FORGE_CORE_TEST_KIT='F:/repo/forge-nvim/.tests/my-kit'
$env:FORGE_CORE_TEST_PROFILE='F:/repo/forge-nvim/.tests/my-kit-profile'
```

Для проверки source configuration:

```powershell
$env:FORGE_E2E_DEPS='F:/repo/forge-nvim/.tests/editor-deps'
$env:FORGE_CORE_TEST_RUNTIME='F:/repo/forge-nvim/.tests/my-prepared-runtime'
```

Runtime должен содержать `treesitter/parser/lua.so`; это подготовленный native
runtime, не просто каталог site. POSIX использует те же env names с `export`.
Оба режима запускают прежний Core suite с его readiness/ownership проверками.
`prepared-native-config` не считается подтверждением installed-kit delivery.
Пути выше — примеры: batch их не создаёт и не загружает.

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

## Shared SDK preflight — IDE-BOOT-40

После developer build frontend (команда выше) native сценарии доступны как
`python -B tests/install-sdk-settings.test.py` (на Linux/macOS — python3).
Нужны готовые Neovim/Node/Go/Rust и Python с venv; SDK тест не устанавливает.
Frontend можно выбрать через `FORGE_INSTALL_UI_BINARY`; по умолчанию используется
подготовленная `.tools/installer-ui/<platform>/fride-setup[.exe]`.
Go root при необходимости задаётся `FORGE_SDK_GO_NEW`.

10 сценариев проверяют реальные SDK/venv, user scope против project/PATH,
относительный/домашний путь и «Авто», ошибки JSON/path/CLI, Core HTTP/cache,
испорченный Core, preview, private setup и запрет SDK внутри заменяемого kit.
Setup stages — fixtures: эти случаи не выдают себя за full Default acceptance.
Ещё1 control проверяет закрытие настоящего HTTP-стенда при ошибке setUpClass:
такая ошибка не должна оставлять suite висеть до внешнего deadline.
Suite автоматически входит в standalone Python inventory `regression` и
выбирается через `-Files` / `--file tests/install-sdk-settings.test.py`.
Для повтора одного случая передайте его имя непосредственно Python suite.

После всего блока запускается один affected batch; повторяются только
failed/affected случаи. Большой checkpoint выполняется отдельно один раз,
с фиксированными SDK/deps и отдельными результатами. Отсутствие prerequisites,
FAIL и неполный прогон нельзя обозначать full PASS. Windows `regression`
содержит POSIX-наборы через WSL и ConPTY; без готового WSL можно проверить
план и native affected batch, это не полный Windows регресс. Mac — отдельно.

## Ошибка POSIX process probe — IDE-117

`scripts/test.sh e2e --file tests/e2e/posix-scope-probe.test.lua` проверяет native
nonzero exit, signal, spawn error и настоящий ps. На Windows этот файл даёт4
platform SKIP; отдельные editor-process/descendants/runtime/project-session и
process-lifecycle проверяют Windows Job backend. Source/target и команды —
[verification](../openspec/changes/capture-posix-scope-probe-failure/verification.md).
В shutdown.json при отказе сохраняется scope.probe_failure: argv, attempt,
elapsed_ms и полный native result либо spawn_error. active_after остаётся
неизвестным, scope.ok=false; повтор stop возвращает то же доказательство.
Это не восстановление причины исторического отказа и не native macOS PASS.

## Go build policy — IDE-BOOT-42

Новый native suite — tests/install-go-toolchain.test.py. Он входит в общий
inventory автоматически; backend и native package fixture разделены в
[verification](../openspec/changes/offer-go-build-toolchain-download/verification.md).
Выбранный developer frontend задаётся FORGE_INSTALL_UI_BINARY. Полный Default
и successful fresh compiler download эти проверки не заменяют. Для повтора
native unittest файла install-ide-tools используйте Tools.test_NAME, для
нового Go suite — короткое test_go_NAME (его main выбирает собственные случаи).


## Версии tools при повторной установке — §281

По умолчанию preserve: установленные Mason tools сохраняются, missing получает
baseline/provider default. Явный --tools-versions baseline возвращает pinned
версии. Go consent независим, receipt/exports обязательны. [Правила](TOOL_VERSIONS.md).
Native tests/install-tool-versions.test.py проверяет8 cases настоящего Mason
с releases native fixture v1/v2; affected batch Windows/Ubuntu выполнен, Mac
отдельно. Это не full Default acceptance; он идёт следующим цельным этапом.


## Завершение процесса подготовки — §282

Ненулевой signal child — отказ установки даже при code0. Runtime probes и
plugins/parsers/tools проверяются общей границей до publication. Ошибка содержит
code/signal/command/log, прежний kit сохраняется. Native regression:
python -B tests/install-process-exit.test.py (POSIX python3). Windows4 PASS8
POSIX SKIP, Ubuntu12 PASS; native Mac отдельно. [Evidence](../openspec/changes/reject-signaled-setup-process/verification.md).
