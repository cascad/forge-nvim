# Проверка remove-sql-extras

Source: `4cf845b`. Runtime проверки — 2026-11-19; итоговые metadata и документация —
2026-11-20. Это целевые проверки затронутого поведения с повторами failed/affected
cases, а не полный regression всей сборки.

## Изменение

По явному решению владельца удалены подключения к БД, выполнение запросов,
Results, SQLS SDK/patch, собственные SQL adapter/runner и их dedicated tests.
Удалено36 tracked файлов, в том числе6 Lua modules. Подсветка и upstream Sqruff
LSP/formatter сохранены; пути разрешаются существующим общим tool_paths.
Prepare/container/setup/inventory больше не требуют дополнительных SQL tools.
Пользовательские БД, конфигурация и установленные SDK не удаляются.

## Нативные проверки

| Проверка | Windows | Ubuntu |
|---|---|---|
| SQL baseline: реальный Sqruff, LSP/formatter, override и отсутствие extras | 3 PASS | 3 PASS |
| Managed entrypoints, mixed project, настоящий Go output | 5 PASS | 5 PASS, aggregate |
| Общий Tests All: Python+Go без SQL adapter | 1 PASS | 1 PASS |
| Installer/profile/setup/tool versions/debug tools/inventory/runtime | 79 выполнено:77 PASS/2 SKIP | 79 выполнено:76 PASS/3 SKIP |
| Spec index / trace self-test / project trace | 7 / 5 / 9 PASS | 7 / 5 / 9 PASS |

Всего по9 editor E2E PASS на ОС. Python suites: profile22, setup7, Go11,
tool versions8, debug tools5, inventory9, runtime17. Пропуски явно объявлены
тестами: OS/network cases и неподготовленный старый Go. Пропуски не считаются PASS.
Fresh preparation/readiness обеих ОС использовали прежние SHA-checked upstream
archives: Sqruff0.44.0 и grammar851e9cb257ba. Manifest содержит2 payload files;
повтор readiness сохранил их bytes и manifest. Новые SQL SDK не устанавливались.

Новый absence case до удаления runtime на source дал RED: SQLRun существует
(2 вместо0). Target проверяет реальные команды, maps, modules, registry,
открытие native Tests и редактирование/сохранение SQL. Общие IDE-TEST-5/6
сохранены; удалённые SQL-only All cases заменены настоящим Python+Go control.

## Первичные отказы и повторы

- Первоначальный выбор installer frontend был устаревшим. Использованы уже
  готовые текущие binaries: Windows SHA prefix c7d8b10e88e9, Linux9664c9b15659.
  Frozen `.tools` не обновлялся.
- В test fixtures исправлены fixed67 вместо сравнения с lock, поздний Go policy
  перед Mason, неполный forge module graph и старое ожидание downloads перед
  missing Terminal. Product SDK/installer код ради результатов не менялся.
- Mixed fixture получил явный Pyright path. Ubuntu managed Pyright timeout
  не повторился на source и target controls; причина не установлена.
- Installer group на Windows bind mount достиг480s. Повтор с теми же SDK,
  текущим frontend и native guest `/tmp` stand/cache прошёл, включая CodeLLDB.
  Низкоуровневая причина разницы FS не установлена; таймауты продукта не повышались.
- Trace self-test Ubuntu сначала дал1 PASS/4 FAIL из-за прав на temporary fixture.
  Использован существующий FORGE_TEST_TMPDIR; финальный короткий повтор дал5 PASS.

Первичные failures сохранены. После исправлений повторялись затронутые cases,
а не весь пакет. Сводка проверяет все финальные exit codes, включая trace self-test.

## Где лежат результаты

- `.tests/sql-removal/final-summary.json` и `final-summary.py` — агрегат со ссылками
  на первичные отчёты и failed/affected повторы.
- `.tests/sql-removal/windows-source-red.txt`, `windows-packet/report.json`,
  `windows-retry/report.json`, `windows-setup-final/report.json`,
  `windows-all-adapters.txt`, `trace-self-windows-final.txt`.
- `.tests/ubuntu/sql-removal/ubuntu-packet/report.json`, `ubuntu-retry/report.json`,
  `ubuntu-installer-final/report.json`, `pyright-source-control.txt`,
  `pyright-target-repeat.txt`, `debug-native-root-control.txt`, `all-adapters.txt`,
  `trace-self-final.txt`. Экспорт regular guest records — `native-records/`.
- Финальные дешёвые gates: `.tests/sql-removal/final-gates.json`,
  `strict-final.txt`, `trace-final.txt`, `catalog-final.json`.
- История причины/решения — FIXLOG300; команды и устройство стенда — commands208.

Финальные gates:19 Lua loadfile,7 Python AST,1 JSON; source search не нашёл
runtime imports снятых modules. Сверены66 pins,6 backports,4 frozen `.tools`
files (включая private Neovim binary), protected SDK/installer/main specs и
append-only prefixes журналов. Strict validation PASS с описанной ниже
archive оговоркой. Итоговый global trace9 PASS; каталог156 REGISTERED,
0 PENDING/0 MISSING. Это регистрация проверок, а не156 runtime PASS.

## Границы результата

REMOVED IDE-SQL-1…9 учитываются trace как снятые контракты; исторические ID
сохраняются, чужие отсутствующие E2E продолжают выявляться self-test.
ADDED IDE-SQL-10 доказывает baseline без extras. MODIFIED IDE-BOOT-23/35
согласованы с текущим runtime. Main IDE baseline ещё не принят: strict validation
отдельно предупреждает, что archive откажет для MODIFIED target, отсутствующего
в main specs. Main WezTerm/macOS specs не меняются, change не архивируется.

Остальные66 plugin pins, plugin sources,6 backports, прочие языковые SDK,
installer UI и frozen `.tools` сверяются отдельно; журналы проверяются append-only
от source. Собственные тестовые контейнеры завершены, Desktop/WSL не менялись.
Временный metadata контейнер2026-11-20: network none,2 CPU/3GiB, auto-remove.

Нативные macOS/реальная Omarchy, физические клавиши/clipboard, оценка рамок,
полный рабочий цикл владельца и публикация однострочных команд остаются отдельными
пунктами. Данный результат не объявляет их проверенными и не означает полный
regression PASS.
