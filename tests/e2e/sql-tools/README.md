# SQL test inputs: upstream Sqruff и grammar

```sh
python -B tests/e2e/prepare_sql.py --download --nvim <nvim>
python -B tests/e2e/prepare_sql.py --nvim <nvim>
```

На Linux/macOS — python3. Нужны prepared editor-deps, pinned Treesitter catalog
и C compiler только для сборки test parser (`--cc <compiler>`). Пользовательский
installer получает готовые grammar assets через Core; Go/Rust/SQLite не нужны.
Все host Windows TEMP/TMP/TMPDIR/NVIM_LOG_FILE задаются на диске checkout.

sources.json закрепляет upstream Sqruff0.44.0 и grammar revision
851e9cb257ba7c66cc8c14214a31c44d2f1e954e с SHA256. `--download` — явная
подготовка; без него readiness проверяет payload/versions в отдельном profile,
не изменяет SDK/manifest и не требует оставленного build scratch.
Default output `.tests/sql-deps`, `--output` / `FORGE_E2E_SQL_DEPS` — свой путь.

`sql-basic.test.lua` проверяет native Sqruff lint/format/paths и отсутствие
удалённых commands/Results/SQL adapter. Специального SQLS/SQL test SDK больше нет.
