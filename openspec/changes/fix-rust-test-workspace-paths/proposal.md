# Proposal

## Why

IDE-054: Windows UI E2E на 047f827 обнаруживает 3 Rust теста, но nearest
запускает 0, integration тоже не PASS; debug nearest завершается без program.
Artifacts 4240005644900/4290858553400/4341546473800. Pinned neotest-rust
смешивает разделители в init.lua и использует unquoted shell/regex JSON
в dap.lua. IDE-TEST-1/2 сейчас описывают Go, Rust требует ADDED IDE-TEST-3/4.
IDE-055 обнаружен после path fix: artifact 5214758329100 получает passed,
но пустой Test Output, потому что translate_results теряет output path.

## What Changes

- Общая canonical path граница для Cargo/package/source и построения Rust
  test names, без отдельного Windows runner.
- Cargo build/debug discovery передаёт argv и читает compiler-artifact JSON,
  сохраняет cwd, пробелы/Unicode и выбирает действительный test executable.
- DAP test result сохраняет путь настоящего stdout для Test Output;
  отдельный source replay после path fix подтверждает IDE-055.
- Pin/SHA backport двух файлов через существующий extra mechanism; только
  явная подготовка, никаких записей/установок в startup.
- Source replay normal/debug RED, реальные UI GREEN и language регресс;
  FIXLOG с причиной/попытками/пределами, docs и команды в том же коммите.

## Capabilities

### New Capabilities

- `test-runner`: ADDED IDE-TEST-3/4 для Rust nearest/file/debug в workspace.
  Capability уже объявлена Go change, её ID-1/2 не меняются.

### Modified Capabilities

Нет.

## Impact

neotest-rust pin остаётся текущим lazy-lock; patches/plugins.json и явный
Lazy build, существующая Rust adapter registration, E2E helper/replay/docs.
Без замены plugins, версий nextest/SDK, отключения тестов или DAP validation.
Windows проверяется нативно; Ubuntu/Mac требуют фактических запусков.
