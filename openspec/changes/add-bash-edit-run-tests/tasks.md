# Tasks

## 1. Явная подготовка и fixtures

- [x] 1.1 Pinned npm lock/LSP/shfmt/ShellCheck/Bats/parser, host Bash/Node manifest/hash и F: caches; Windows prepare --download и repeat без установки, пользовательские команды подготовки.
- [x] 1.2 Private Unicode/space Git workspace со sourced library, format/run/pass/fail scripts и артефактами без tool cache; реальный Bash/Bats CLI probe и E2E README.

## 2. Общий runtime и UI

- [x] 2.1 IDE-SH-1/2 guarded Bash-LSP и Conform, настоящие navigation/rename/completion/diagnostics/format/save UI E2E Windows; baseline source RED, docs и история причины новых failures.
- [x] 2.2 IDE-SH-3 BashRunFile/Space j b native argv/cwd/stdout/stderr/status, отсутствующий Bash без WSL/profile/install; реальные UI E2E Windows и guide.
- [x] 2.3 IDE-SH-4 Bats Neotest public adapter, nearest/file/pass/fail/output и соседний marker без DAP popup; реальные UI E2E Windows и guide, DAP остаётся IDE-057.

## 3. Интеграция

- [ ] 3.1 Registry/Ubuntu image и последовательный Bash/language/smoke регресс с уже работающим engine; при отсутствии engine оставить открытым, Mac/Bash 3.2/GUI не PASS.
- [x] 3.2 Windows Rust/Python/Node/Go/smoke/backports, unit/trace/strict и source/hash audit; append FIXLOG/HISTORY/PROBLEMS/матрица/roadmap/команды, проверенный commit и продолжение полного плана.

Windows: 8 Bash + 45 прежних UI + 9 backports, 365 unit/trace checks PASS.
Baseline LSP/format и промежуточный rename воспроизведены теми же UI tests.
Evidence: .tests/bash-language-evidence.json; FIXLOG §116–118 / AGENT_COMMANDS §46.
3.1 остаётся открытой: engine 2026-11-09 09:40:46 UTC недоступен, image не
build/run; Mac/Bash 3.2/GUI не проверены. DAP — отдельный IDE-057.
