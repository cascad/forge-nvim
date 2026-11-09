# SQL: язык, подключения и запросы

Общий workflow Windows/macOS/Ubuntu. SQLS обслуживает схему, completion,
definition/hover и alias rename; Sqruff — diagnostics и форматирование.
Открытие SQL не устанавливает tools/SDK и не исполняет SQL из файла.
Другие backend SQLS доступны через native configuration; воспроизводимые
проверки используют настоящие SQLite. Проверка SQLite не подтверждает
работу PostgreSQL/MySQL/TLS/SSH без их сервера.

## Подготовка

Явно подготовь SQLS 0.2.48+forge.1 и Sqruff 0.44.0 в PATH или задай executable через
FORGE_SQLS_EXECUTABLE / FORGE_SQRUFF_EXECUTABLE (Lua g:forge_sqls_executable /
g:forge_sqruff_executable). Forge-вариант исправляет потерю rows после ведущих
комментариев (IDE-066); upstream 0.2.48 сохранён для воспроизведения бага.

```sh
python -B tests/e2e/prepare_sql.py --download --sqls-variant patched --output .tools/sql --go <go-1.25+> --nvim <nvim>
```

Нужны подготовленные editor-deps/catalog, предоставленный Go >=1.25 и C compiler.
На Windows явно готовится portable Zig 0.15.2 для native CGO GNU target;
Linux/macOS используют native CC. --go-cc задаёт свой Go CC command, --cc —
compiler SQL parser. Все Windows caches/build/temp остаются на диске checkout.
Системный PATH не переписывается: добавь `.tools/sql/bin` сам или укажи полный
путь к `sqls[.exe]`/`sqruff[.exe]` в перечисленных overrides. SQL parser можно
подготовить штатным явным `:TSInstall sql`.

Source/patch/before-after SHA — [SDK metadata](../scripts/sdk/sqls.json).
Patch использует уже построенный native SQLS AST для выбора Query/Exec,
БД получает исходный SQL со всеми комментариями/hints/literals. Go SDK
не устанавливается; подготовка source выполняется только по явному --download,
Go -p=2 и GOTOOLCHAIN=local. Открытие SQL не вызывает Go/компилятор.

В корне workspace создай private `.sqls.json`:

```json
{
  "connections": [
    {
      "alias": "Local",
      "driver": "sqlite3",
      "dataSourceName": "file:db/app.sqlite3?mode=rw"
    }
  ]
}
```

SQLite файл должен уже существовать. Его отсутствие не создаёт пустую БД.
Относительные пути считаются от workspace; пробелы/Unicode поддержаны.
Поиск workspace: ближайший .sqls.json, затем .git. Иной config задаётся
FORGE_SQL_CONFIG / g:forge_sql_config. Конфиг не переписывается редактором.
`.sqls.json` игнорируется Git этого репозитория; в собственных проектах также
добавь его в .gitignore. Не публикуй credentials/рабочие базы.
Поля других drivers — [upstream SQLS](https://github.com/sqls-server/sqls/tree/v0.2.48).

Dialect/style задаются в `.sqruff`, например:

```ini
[sqruff]
dialect = sqlite

[sqruff:indentation]
tab_space_size = 2

[sqruff:rules:capitalisation.keywords]
capitalisation_policy = upper
```

Без project config используется ANSI; явный override — FORGE_SQL_DIALECT /
g:forge_sql_dialect. Sqruff lint работает асинхронно по снимку buffer/stdin с
debounce 500 ms, отменой прежнего процесса и защитой от устаревших ответов.
В Sqruff 0.44.0 LSP теряет parse-errors/dialect flags, поэтому diagnostics
поступают через CLI и публичный vim.diagnostic, без второго LSP процесса.

## Управление

| Действие | Клавиши / команда |
|---|---|
| Completion / definition / hover / alias rename | Ctrl+Space / gd / K / F2 |
| Диагностика под курсором | gl |
| Форматирование | Space l f, Shift+Alt+F, явный :write/Ctrl+S |
| Выполнить весь текущий buffer | Space j q / :SQLRun |
| Выполнить точное выделение | visual Space j q |
| Выполнить выбранные строки | :'<,'>SQLRun |
| Выбрать подключение | Space j c / :SQLConnect |
| Фокус в SQL Results | Space j o / :SQLResults |
| Остановить SQL session/backend workspace | Space j x / :SQLStop |
| Вернуться в код | F7 / Space w 0 |
| Скрыть / развернуть-вернуть / помощь | q или Space w q / Space w z / ? |

SQLRun передаёт неизменяемый снимок в SQLS через in-memory didOpen/executeQuery/
didClose. Свой splitter не используется: `;` внутри literal и Unicode не
меняют точность selection. Run сам не вызывает write. Обычное autosave остаётся
включено; для работы с заведомо несохранённым buffer его можно явно выключить
через :ASToggle. Фоновое autosave сохраняет текст без форматирования (IDE-063).

SQL Results подписывает source/profile/status, сохраняет настоящий output/error.
Повторное открытие, zoom и помощь не запускают запрос заново. Во время query
можно редактировать код; второй query того же workspace требует завершения
либо SQLStop. При смене подключения SQLS client workspace пересоздаётся, схема
completion обновляется, другие workspaces не останавливаются. Picker содержит
только alias и driver. Смена profile не переподписывает старые rows.

SQLStop завершает backend session workspace, следующий Run подключается снова.
Это остановка процесса SQLS; гарантии отмены операции на удалённом DB server
требуют проверки конкретного driver/сервера. Автоматического rollback всего
batch нет: выполненные backend statements могут уже изменить данные.

SQLS 0.2.48 использует codepoint координаты и ошибается на первом символе rename.
Версионный adapter исправляет эту границу; другие версии не патчатся вслепую.
SQLS не предоставляет semantic references; поиск текста их не заменяет.
SQL test framework остаётся отдельным IDE-062, procedural debug требует backend.

Upstream SQLS 0.2.48 классифицирует SELECT с ведущим комментарием как Exec.
Нужен подготовленный forge.1 вариант: `Query OK` старого backend не означает
отсутствия rows. Исходный RED и фикс проверяются отдельным IDE-066 UI.

## Повторяемые проверки

После явной подготовки общих plugins:

```sh
python -B tests/e2e/prepare_sql.py --download --sqls-variant patched --go <go-1.25+> --nvim <nvim>
python -B tests/e2e/prepare_sql.py --nvim <nvim>
<nvim> -l tests/e2e/sql-language.test.lua
<nvim> -l tests/e2e/sql-sdk.test.lua
```

На Ubuntu/Mac — python3. Windows использует Forge SDK и TEMP/TMP/TMPDIR/
NVIM_LOG_FILE на диске checkout. Override tools: --output / FORGE_E2E_SQL_DEPS.
FORGE_SQL_CASE фильтрует case по подстроке. Native tools/parser/SHA закреплены
в [sql-tools](../tests/e2e/sql-tools/README.md), readiness ничего не скачивает.
Private workspace с двумя SQLite, Unicode/space paths, counters и real DB lock
сохраняет source/config/UI grid/LSP log/запущенные PID и shutdown artifacts.
Доставка физических клавиш из GUI проверяется отдельно.

Windows: 20 SQL UI + 2 native SDK CLI checks PASS. Повтор readiness не требует
компилятора/build scratch, использует отдельный временный профиль и сохраняет
manifest/binaries; смена sqls-variant без --download отклоняется (IDE-067).
Официальный вариант для source RED: --sqls-variant upstream --download с
отдельным --output и FORGE_E2E_SQL_DEPS. Readiness существующего output
сохраняет его manifest variant; при миграции укажи patched явно.

`Space j o` выбирает сохранённый результат workspace текущего SQL-файла,
обновляя даже уже видимую панель. Для workspace без запуска будет «Нет
результатов». Переключение не исполняет SQL повторно; поздний ответ другого
workspace остаётся в его кэше (IDE-068, три постоянных UI regression).

Ubuntu при уже работающем engine:

```sh
docker compose -f tests/containers/compose.yaml build ubuntu
docker compose -f tests/containers/compose.yaml run --rm --entrypoint nvim ubuntu -l tests/e2e/sql-language.test.lua
```

Docker Desktop/WSL эти команды не поднимают. Mac/ARM64 build и внешние DB
не считаются проверенными по Windows результатам.
