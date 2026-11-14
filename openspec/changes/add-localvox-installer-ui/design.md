## Context

См. proposal.md. Референс D:/rust_repo/localvox-light4514678 разделяет cliclack frontend и installer backend. Source entry Forge уже доставляет source без Git, private backend проверяет runtime и stages. Native UI нужен до подготовки Neovim; поэтому Lua/плагины не подходят для самого мастера.

## Goals / Non-Goals

Goals: один готовый native fride-setup, Custom wizard/Default auto/preview, проверяемая доставка и native PTY, общий существующий backend.

Non-Goals: SDK assembler/публикация полного Default, OS package managers, Ollama/модели, миграция nvim/data, новый test framework. Cliclack — presentation зависимость, не дополнительный компилятор у пользователя.

## Decisions

- Небольшой отдельный Rust crate installer-ui с cliclack0.5.6/console0.16.6, заимствованными темой и Back/Cancel pattern LocalVox с MIT notice. Backend остаётся PS/sh/Lua. Компоненты читаются из прежней TSV; frontend не содержит нового package inventory.
- Source entry для UI-capable source вызывает готовый fride-setup. Источники binary: явный InstallerUIPath, developer .tools receipt или artifacts.tsv с platform/URL/SHA256. Windows .exe/POSIX executable скачивается атомарно в source cache, проверяется до запуска; Cargo на install не вызывается. Legacy source без installer-ui/Cargo.toml сохраняет advanced flow.
- CLI frontend принимает обычные argv paths/flags, создаёт Command с argument arrays и env FORGE_NVIM_COMPONENTS, без eval/JSON shell parsing. Default/explicit components — auto; standalone preview показывает профиль/план, Custom — компоненты/папки/команду/план.
- Подтверждённые значения живут в Draft и стеке шагов. Interrupted открывает меню навигации; отсутствие истории отменяет. Preview заканчивается до backend; только явно заданный developer result file может быть сохранён.
- Backend отдаёт opt-in event lines runtime/plugins/parsers/tools. Frontend собирает stdout/stderr в собственный лог, показывает один текущий stage; без TTY — plain lines. Actual exit/Launch/Registered launcher сохраняются; internal traceback не заполняет обычный экран.
- Builder использует готовый явный Rust SDK, private Cargo/target/temp. Windows artifact статически связывает CRT. Артефакт/receipt публикуется отдельно, в Git binary не добавляется. Linux/macOS команды те же; публикация и native Mac — отдельные gates.

## Risks / Trade-offs

- [UI artifacts ещё не опубликованы] → developer ready binary/preview и localhost delivery stand; не выдавать готовность UI source за готовый public one-liner.
- [API/presentation cliclack] → закреплённая версия/lock, реальный PTY на Windows/Linux, screenshots и отдельный Mac gate.
- [Backend внутренние package failures без exit] → UI не заменяет actual readiness; эта граница IDE-139/138 остаётся явной.

## Migration Plan

Backend args и переносимость сохраняются. Новый source требует prepared UI, старый source идёт прежним advanced путём. Из пользовательских каталогов UI ничего не пишет до подтверждения; preview не запускает backend.
