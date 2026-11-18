# Design

## Context

См. proposal. Source installer уже располагает pinned PS/Bash transport и
Core manifest verification. Core содержит Neovim; language choices в sdk.json
и tools.json принадлежат namespace fride. Rust probes уже bounded/no-download.

## Goals / Non-Goals

**Goals:** одна Lua semantics путей, Core-first чистая установка, user scope
preflight/setup, честный report/ошибка без fallback на чужую версию.

**Non-Goals:** новый package manager/Lua VM, перенос SDK в kit, SDK auto-install,
runtime project override в installer, новая compatibility/update policy.

## Decisions

- Prepare-only режим существующих PS/Bash entrypoints получает Core path из
  explicit runtime/catalog, проверяет bootstrap SHA, не создаёт target и не
  запускает setup. Terminal/остальные части доставляются после SDK readiness.
- Общая runtime-core.lua валидирует manifest/platform/pins/tree перед чтением
  SDK; используется и actual installer, и read-only Core preflight.
- Preflight -u NONE/-i NONE читает user namespace fride и экспортирует только
  explicit tools/bin/env/source/errors. Shared SDK selection и setup resolution
  становятся чистыми APIs; Rust не читает sdk.json/tools.json самостоятельно.
- Rust native probes принимают snapshot. Invalid explicit setting не разрешает
  PATH fallback. Git остаётся native и может проверяться до Core.
- Private pre-init всех setup stages задаёт scope=user до init/Mason; SDK init берёт его из setup report.
  Normal editor/legacy setup сохраняют project→user semantics. Empty profiles
  не читают ненужные SDK settings; source/manager cache/auth не меняются.
- Core cache повторно используется actual delivery; SHA/errors до target writes.
  Preview/print-plan/read-only Git checks не требуют Core.

## Risks / Trade-offs

- Core downloads при missing SDK → явное согласие владельца получено; SDK и
  существующий kit не устанавливаются/не меняются до readiness.
- Повреждённый explicit choice → report с источником, исправить/reset choice;
  SDK action menu не должен скрыто отменять saved setting.
- Shared resolver меняется → native frontend/runtime parity cases и controls
  одним batch после цельного кода. Mac отдельно, большой regression checkpoint.
