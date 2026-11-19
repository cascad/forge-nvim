# Tasks

## 1. Core и deferred environments

- [x] 1.1 Отделить desired components от prepared tools/SDK mask; Default без SDK готовит Core/parsers/plugins/Terminal и показывает deferred. Сохранить explicit eager/direct/check modes; добавить installer regression cases и описать новый результат.
- [x] 1.2 Добавить current native frontend и canonical preflight/runtime-policy helpers в atomic kit staging; SDK selection/locks/старый .tools UI прежние. Проверить fixture ownership/reinstall и installed payload hashes.

## 2. Native language preparation

- [x] 2.1 Реализовать --prepare-language/--installed-kit без замены работающего kit; shared Core/settings/preflight, native SDK/nextest actions, selected tools stage/result. Добавить source/installed SDK-mode success/cancel/error tests и команды.
- [x] 2.2 Official Go + rustup worker для новой Ubuntu, preserve/report/fallback paths; APT debconf noninteractive внутри sudo. Добавить regression native recipe/error/preserve controls; реальные installs в cold stand, SDK host не меняются.

## 3. Runtime hub и первый файл

- [x] 3.1 Реализовать «Языки и инструменты» Space l S/command: SDK/version/path/source, tools status, existing/manual/prepare/recheck/logs/Mason; ForgeSdk остаётся. Добавить E2E scopes/selection/status/manual path и руководство.
- [x] 3.2 FileType local-only notice + per-root/language dedup, Later и persistent user/project disable/reset в hub. Добавить E2E no-download/edit/save/disable/reopen/reset/invalid override.
- [ ] 3.3 Async native prepare в стандартной terminal/task панели, последовательность/cleanup/retry/result и явное SDK apply/busy semantics. Добавить E2E real prepared SDK reuse, cancellation/missing backend/edit and actual installed flow.

## 4. Единый итоговый checkpoint

- [ ] 4.1 После всей реализации один affected/regression пакет Windows/Ubuntu, только failed/affected repeats; новый cold Core без SDK→первый Go/Rust файл→prepare→LSP/format/run/debug/tests→repeat. Сохранить original failures и honest native limits.
- [x] 4.2 FIXLOG291/commands199/HISTORY/roadmap/guides, strict/trace/syntax/frozen/journal/index checks и local commit; export evidence и cleanup exact own containers. Native Mac/WSL/GUI/publication отдельно без fake PASS.

## Точка остановки — 2026-11-19

7/9 tasks complete. Native async protocol/editor failure/cancel and shared SDK
provider reuse verified; actual installed cold language flow in3.3/4.1 remains
open. Default failed on Terminal OS library; IDE-142 awaits dependency policy
choice. No full cold PASS, no archive/all_done. See verification.md.
