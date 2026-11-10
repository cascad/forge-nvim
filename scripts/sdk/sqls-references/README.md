# SQL semantic resolver — незавершённый overlay

Источник scope/binding модели для `add-sql-semantic-references`, IDE-SQL-9.
`resolve.go` использует AST закреплённого SQLS, существующий lexer/parser не
копируется в Lua и не заменяется поиском строк. Metadata schema передаётся
снимком, SQL resolver не выполняет.

Сейчас это **не включённая в SDK библиотека**, не готовый references provider.
Проверены native unit случаи table/column identity, aliases, nested/correlated
SELECT, shadowing/ambiguity, includeDeclaration и Unicode. CTE/derived outputs,
projection alias usages, DML, workspace index, quoting/dialect policy, handler
и immutable SDK integration ещё не завершены. Неподдержанный statement даёт
ошибку, а не успешный частичный индекс. Полный критерий — specs/tasks change;
зелёные unit не закрывают редакторский E2E или IDE-062.

После явной подготовки SQL SDK (нужен его проверенный source archive):

```powershell
python -B tests/e2e/check_sql_references.py --go .tests/dap-tools/go/bin/go.exe
```

На Linux/macOS та же команда с `python3` и `--go /путь/к/go` либо подготовленным
Go в PATH. Скрипт создаёт частную копию AST/parser и overlay в
`.tests/sql-references-native`, проверяет Go locks, запускает реальные Go tests,
сохраняет SHA исходников/stdout/stderr/result.json. SDK manifest/binary и
пользовательский профиль не изменяются. Native platform verification фиксируется
только после реального запуска на соответствующей ОС.

Редакторский acceptance case (на forge.1 ожидается целевой RED):

```powershell
& $forgeNvim -l tests/e2e/sql-references.test.lua
```

`$forgeNvim` выбирается через `scripts/lib/nvim-sdk.ps1`, как в E2E README.
Перед Windows запуском TEMP/TMP/TMPDIR/NVIM_LOG_FILE направляются в `.tests/tmp`.
