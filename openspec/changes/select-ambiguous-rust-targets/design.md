# Design

## Context

См. proposal. В последней ветке rust_current_program уже собраны executable
candidates; текущий выбор предупреждает и возвращает candidates[1].
Закреплённый nvim-dap eval_option поддерживает coroutine как значение option.

## Goals / Non-Goals

Заменить только неоднозначный fallback на vim.ui.select и штатный DAP ABORT.
Cargo roots/metadata/build policy, adapters, SDK и launch.json прежние.
Сборка examples/особые flags вне этого шага и задаются проектным preLaunchTask.

## Decisions

- Возвращать coroutine из program resolver, по native nvim-dap API; выбор
  возобновляет DAP coroutine с executable либо ABORT. Новый manager не нужен.
- Сохранить ранние return текущего target/package bin/единственной цели.
- Дополнить existing rust-language тест одной offline fixture с двумя bins,
  общей library функцией, marker реального запуска, breakpoint/eval/output.
- Отмена проверяется до первого запуска; обычный и alternate/project debug
  остаются прежними controls. Один Windows прогон Rust suite + launch-routes.

## Risks / Trade-offs

Async callback/cancel проверяются реальным Telescope/CodeLLDB; первичный FAIL
сохраняется без повторов. Windows suffix/native paths — существующий helper.
Ubuntu/macOS/physical GUI отдельно непроверены; новых загрузок SDK нет.
