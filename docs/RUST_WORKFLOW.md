# Rust: Cargo workspace, язык, debug и Tests

Используется общая конфигурация Windows/macOS/Ubuntu. Нужен установленный
Rust SDK с rust-analyzer, rustfmt, clippy и rust-src; редактор сам его не ставит.
Компоненты можно подготовить явно в shell:

```sh
rustup component add rust-analyzer rustfmt clippy rust-src
```

Rust formatter использует rustfmt, затем LSP fallback. Navigation/rename/
completion/diagnostics обслуживает rust-analyzer; на save запускается clippy.
`gd`/`gr`/`F2` — definition/references/rename, `gl` — диагностика строки,
`Space l f`/`Shift Alt f`/`:Format` — форматирование.

F5 предлагает Current Rust file bin и вариант с аргументами. Cargo metadata
определяет target текущего package; перед debug выполняется cargo build (debug)
в Tasks. Для .vscode/launch.json codelldb launch нужен явный program:
VS Code extension-only cargo поле не заменяет его в nvim-dap.
F9 ставит breakpoint, Space d e вычисляет выражение, F5 продолжает исполнение.
Locals/Debug Output/код: Space w d / Space w c / F7 (или Space w 0).

Нужен CodeLLDB в PATH либо явно установленный Mason adapter; на Windows
поддерживается также существующий каталог %LOCALAPPDATA%/codelldb.
Вывод Rust идёт через integrated terminal и остаётся в Debug Output.
После обновления сборки выполнить `:Lazy build neotest-rust` и перезапустить
редактор: это применяет pin/SHA backport paths/argv/JSON и сохранения test output.
Обычный startup исходники plugin не переписывает.

Панель Tests использует neotest-rust и cargo-nextest, поэтому одного cargo
test недостаточно. Cargo-nextest устанавливается явно по
[официальной инструкции](https://nexte.st/docs/installation/pre-built-binaries/).
Tests / Test Output: Space w t / Space w r; nearest / file / debug nearest:
Space T t / Space T f / Space T d. Нужен Rust Treesitter parser, подготовленный
явным :TSInstall rust. Обнаружение тестов и фактический запуск — разные этапы.

## Постоянные E2E

Сначала plugins по [инструкции E2E](../tests/e2e/README.md), затем:

```sh
python -B tests/e2e/prepare_rust.py --download --nvim <nvim>
python -B tests/e2e/prepare_rust.py --nvim <nvim>
<nvim> -l tests/e2e/rust-language.test.lua
```

На macOS/Ubuntu используется python3; host Rust SDK предоставляет машина.
Preparer не устанавливает/обновляет SDK, проверяет compile probe, сохраняет
host versions/sysroot/hash. Pinned tools: CodeLLDB 1.12.2, cargo-nextest 0.9.151,
Rust parser из закреплённого Treesitter catalog. Sources/SHA — rust-tools/sources.json.
Архивы/tool binaries/cache/build/manifest — .tests/rust-deps; повтор без
--download проверяет подготовку. --output/FORGE_E2E_RUST_DEPS задают другой
каталог, на Windows он должен быть на диске checkout.

Private offline workspace содержит два local crates и несколько targets;
отдельные Cargo home/target/temp исключают пользовательский config и сетевые
dependencies. Target не собирается перед UI; F5 обязан выполнить build.
FORGE_RUST_CASE ограничивает запуск по подстроке имени случая. Source/locks/
manifest/logs/snapshots сохраняются, target не копируется в артефакты.

Windows Rust 1.96.1: 8 UI PASS; прежние Python/Node/Go/smoke 37 сценариев,
backport E2E 9 и unit/trace 364 checks PASS. IDE-054 исправляет выбор тестов/
executable, IDE-055 сохраняет debug output. Source RED/GREEN — FIXLOG §114–115,
команды AGENT_COMMANDS §45. Ubuntu image дополнен подготовкой, но не собран:
engine недоступен. macOS/GUI и cross-compile пока не проверены; задачи
verify-rust-language-workflow/fix-rust-test-workspace-paths остаются открытыми
для непроверенных платформ.

В изолированном offline cache отсутствуют registry dependencies исходников
stdlib: этот SDK сообщает warning Cargo metadata про cfg-if и использует
source fallback. Проектные LSP сценарии проверяются настоящим server;
переходы внутрь stdlib этим набором не объявляются проверенными.

FORGE_RUST_CASE=nextest или 'debug nearest' вместе с FORGE_RUST_LEGACY=1
воспроизводит исходный adapter только в private copy. Для отдельного дефекта
output: FORGE_RUST_CASE='debug nearest', FORGE_RUST_OUTPUT_LEGACY=1. Replay
проверяет before/previous SHA; общая подготовка остаётся неизменной. В обычном
режиме debug E2E также проверяет readiness CLI после запуска CodeLLDB без
повторной установки и без изменения manifest; runtime __pycache__ не считается
изменением pinned payload.

Первичные источники: [Cargo test](https://doc.rust-lang.org/cargo/commands/cargo-test.html),
[rust-analyzer installation](https://rust-analyzer.github.io/book/installation.html),
[neotest-rust](https://github.com/rouge8/neotest-rust),
[CodeLLDB 1.12.2](https://github.com/vadimcn/codelldb/releases/tag/v1.12.2).
