# Явная подготовка SQL tools

```sh
python -B tests/e2e/prepare_sql.py --download --nvim <nvim>
python -B tests/e2e/prepare_sql.py --nvim <nvim>
```

На macOS/Ubuntu — python3. Нужны подготовленные editor-deps с pinned
Treesitter catalog и C compiler для SQL parser. Windows использует Forge SDK,
TEMP/TMP/TMPDIR/NVIM_LOG_FILE перед прямыми командами задаются в .tests/tmp.
Default output .tests/sql-deps, --output/FORGE_E2E_SQL_DEPS задают другой путь.

Sources.json закрепляет sqls 0.2.48, sqruff 0.44.0 и SQL grammar revision
851e9cb257ba7c66cc8c14214a31c44d2f1e954e. Для sqls amd64 используются native
official releases, ARM64 собирает тот же pinned source с предоставленными
Go >=1.25 и native CC (GOTOOLCHAIN=local, SDK не скачивается). Sqruff имеет
official artifacts/SHA для Windows x64 и Linux/macOS x64/arm64.

--download разрешает fetch/unpack/build; повтор проверяет versions/payload/
sources SHA и загрузку единственного SQL parser без переустановки. Manifest
хранит build context, binaries/parser hashes; caches/build/archives остаются
в output. Это проверка tools, не PASS пользовательского SQL workflow.

Подготовка sqls/sqruff не требует Node/npm. Сравнительный npm sql-language-server
1.7.1 probe не является зависимостью этой сборки. Windows native CLI probes
подтвердили schema/definition/hover/query и sqruff diagnostics/format;
product UI и остальные платформы должны проверяться отдельно.
