# Проверка

2026-11-17. Подготовленные native Windows/Ubuntu SDK, без downloads и обновления
плагинов. Ubuntu — existing image, network none, --rm/--no-deps/--pull never;
backports подготовлены офлайн только в private copy через tool-paths.sh.

| Проверка | Windows | Ubuntu |
|---|---|---|
| IDE-BOOT-36 Go/Rust tools, 7 editor E2E | 7 PASS в целевых запусках | 7 PASS в целевых запусках |
| go.work gd/gi/gr между модулями | 1 PASS | 1 PASS |
| Rust disabled before project / late metadata delivery | 2 PASS | 2 PASS |
| Rust warmup до открытия файла, UI/reuse | 1 PASS | 1 PASS |
| DAP missing adapter / passive startup | 3 PASS | 3 PASS |
| Late Delve override, F5/breakpoint/output | 1 PASS | 1 PASS |
| Go formatter native LSP fallback | 1 PASS | 1 PASS |

Новый набор использует настоящие gopls/rust-analyzer, golines/gofumpt/rustfmt,
Go tests и Delve/CodeLLDB. Часть Go tools копируется в путь с пробелами;
Rust executables сохраняют исходные SDK/bundle DLL. PATH shadows не подменяют
работу инструмента: если override проигнорирован, запуск должен провалиться.
User priority проверяется для всех семи executables, фоновой Conform format
реально работает при другом cwd; неверный explicit formatter прерывает format
до запуска fallback. DLV/CodeLLDB invalid paths видны в passive report, который
не запускает процессы. Неизменность SDK env и installs0 проверяются в E2E.

Первый целевой прогон:4 PASS/1 FAIL на ОС — наблюдатель uv.spawn не видел
Neotest jobstart. При разборе pinned adapter найдено более существенное
ограничение: gotestsum fallback по PATH выполняется до публичного RunSpec и
меняет глобальный runner. Его частичный override убран; финальный native Go
test — контроль прежней интеграции, не обещание custom gotestsum path.

Go workspace control сначала отказал при RPC serialization cmd function;
два Go observers приведены к уже существующему Rust/Python формату. Навигация
после этого прошла. CodeLLDB test сначала повторно останавливался на macro
line; fixture использует обычное присваивание, затем снимает breakpoint перед
continue. Нативные pause/adapter path/exit/stdout проверены после исправления.
Повторялись затронутые/новые случаи; общего полного регресса не было.

Raw logs: .tests/toolchain-research/go-rust-*.txt; UI snapshots/state/process
evidence — .tests/editor-e2e и .tests/ubuntu/editor-e2e. У host TEMP на F;
guest — собственный /tmp. Docker Desktop/WSL lifecycle не менялся.
Native macOS/physical keys/full Default не проверялись. Отдельный SDK path
во всех Go/Cargo адаптерах остаётся за рамками этого среза.
