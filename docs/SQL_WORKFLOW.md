# SQL: базовая поддержка

После решения владельца и §300 fride использует подсветку SQL и готовый
upstream Sqruff LSP/formatter. Подключение к БД не требуется.

- SQL выбирается в установщике как обычная языковая поддержка; Sqruff
  устанавливается через Mason. Уже выбранные tools/версии сохраняются.
- Свой executable задаётся через user/project `.fride/tools.json` (`sqruff`),
  либо прежние `forge_sqruff_executable` / `FORGE_SQRUFF_EXECUTABLE`.
  [Общие пути](TOOL_PATHS.md), `:ForgeToolPaths`, `:ForgeLogs`.
- `.sqruff`/`.sqlfluff` задают dialect/style. Явный `forge_sql_dialect` /
  `FORGE_SQL_DIALECT` сохраняется; без конфигурации используется ANSI.
- `gl` раскрывает диагностику. `Space l f` форматирует; явный save сохраняет
  результат штатного форматтера. Открытие файла tools не устанавливает.

Собственные SQLRun/SQLConnect/SQLStop/SQLResults, их `Space j` сочетания,
SQL Results и SQL test adapter удалены. SQLS SDK/patch и собственный Rust
runner больше не входят в поставку. Семантические DB-aware references не
заявляются возможностью Sqruff. Пользовательские БД/config/SDK не удаляются.

Системные CLI доступны в обычной встроенной консоли (`Space w T`). Выделение
можно отправить туда через Visual `Space t e` / `Ctrl+Enter`.

Проверка: `tests/e2e/sql-basic.test.lua` — настоящий Sqruff, tools paths,
диагностика/форматирование и отсутствие удалённой поверхности. Инструкции
подготовки тестов: [SQL test inputs](../tests/e2e/sql-tools/README.md).
История прежнего SQL workflow сохранена в [FIXLOG](../nvim_forge/FIXLOG.md).
