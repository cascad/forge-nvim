# Явная подготовка SQL tools

```sh
python -B tests/e2e/prepare_sql.py --download --sqls-variant patched --go <go-1.25+> --nvim <nvim>
python -B tests/e2e/prepare_sql.py --nvim <nvim>
```

На macOS/Ubuntu — python3. Нужны подготовленные editor-deps с pinned
Treesitter catalog и C compiler для SQL parser. Windows использует Forge SDK,
TEMP/TMP/TMPDIR/NVIM_LOG_FILE перед прямыми командами задаются в .tests/tmp.
Default output .tests/sql-deps, --output/FORGE_E2E_SQL_DEPS задают другой путь.

Sources.json закрепляет sqls 0.2.48, sqruff 0.44.0 и SQL grammar revision
851e9cb257ba7c66cc8c14214a31c44d2f1e954e. Patched SQLS 0.2.48+forge.1
собирается нативно на каждой ОС из того же pinned source. Нужен предоставленный
Go >=1.25 (PATH или --go), native CC; GOTOOLCHAIN=local, Go SDK не скачивается.
На Windows явно готовится pinned Zig 0.15.2 для CGO GNU target; --go-cc задаёт
свой Go CC command. --cc отдельно выбирает compiler SQL parser. Sqruff имеет
official artifacts/SHA для Windows x64 и Linux/macOS x64/arm64.

--download разрешает fetch/unpack/build; повтор проверяет versions/payload/
sources SHA и загрузку единственного SQL parser без переустановки. Manifest
хранит build context, binaries/parser hashes; caches/build/archives остаются
в output. Это проверка tools, не PASS пользовательского SQL workflow.

Подготовка sqls/sqruff не требует Node/npm. Сравнительный npm sql-language-server
1.7.1 probe не является зависимостью этой сборки. Windows native CLI probes
подтвердили schema/definition/hover/query и sqruff diagnostics/format;
product UI и остальные платформы должны проверяться отдельно.

Вариант patched — default для нового output. Readiness сохраняет вариант
manifest, включая прежние upstream output. Явный --sqls-variant upstream
использует official amd64 binary или исходную ARM64 source build для RED:
известный IDE-066 в нём остаётся. Менять вариант можно только с --download.
Patch/metadata находятся в scripts/sdk/sqls-query-comments.patch и sqls.json:
source/patch/before-after SHA, CGO compiler pin, native -p=2 build, Go locks
без изменений и existing upstream executeQuery tests. Вариант не делает SQL
rewriting в Lua и не меняет SQL-текст, отправленный БД. UI PASS — отдельный шаг.
