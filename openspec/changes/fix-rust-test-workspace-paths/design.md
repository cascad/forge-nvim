# Design

## Context

Симптом и source evidence — proposal.md/IDE-054. Не меняем IDE-DAP-4/5 и
проверку обязательного program: adapter обязан вернуть настоящий executable.
Существующий ide.backports поддерживает companion extra files с предварительной
проверкой всех SHA до записи, поэтому новый patch mechanism не требуется.

## Goals / Non-Goals

Согласовать test identity/package и Cargo binary discovery на границах.
Не заменять archived plugin новым стеком, не менять зависимости/версии,
не использовать заранее собранный binary и не ослаблять результат теста.

## Decisions

1. Canonical realpath/разделители для сравнения и относительных Rust module
   names. Native filesystem paths остаются native для actual I/O/argv;
   namespace/test names используют :: независимо от системы.
2. Shell string убирается из Cargo discovery: vim.system argv + cwd,
   построчный vim.json.decode compiler-artifact, только profile.test/executable,
   source paths сравниваются после нормализации. Ошибка cargo сохраняется.
3. Build_spec normal отдаёт argv, filter expression отдельным аргументом без
   shellescape/-E в одном token. Это общая Neotest граница, не Windows ветка.
4. Pin/SHA init.lua и extra dap.lua через Lazy build/prepare_editor.
   Startup только регистрирует adapter. Source replay восстанавливает оба
   before SHA только в private plugin copy до запуска UI.
5. Runtime source не правится до сохранения окончательного RED; GREEN
   подтверждает выбранные тесты/реальный output и debug, а не наличие session.
6. IDE-055: translate_results добавляет output_path в каждый настоящий result;
   иначе Neotest consumer не читает файл stdout. Промежуточный path-only source
   сохраняется как известный previous SHA и воспроизводится в private copy.
   Это реализация уже запланированного output IDE-TEST-4, без расширения scope.

## Risks / Trade-offs

- Разные Cargo target kinds/module files: source executable mapping сохраняет
  прежний обход modules и добавляет normalized comparison. Проверяется library
  unit и integration; proc-macro/нестандартные harness не объявляются покрытыми.
- JSON/пути/quoted names: parsing данных вместо regex/shell joining;
  workspace Unicode/space fixture и несколько targets исключают простой PASS.
- Upstream archived: точечный проверяемый backport с сохранённым source;
  будущая замена adapter — отдельное решение после функциональной матрицы.
- Ubuntu/Mac пока без запусков: отдельная открытая задача, не PASS.
