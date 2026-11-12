# Design

## Context

См. proposal. Готовы gopls v0.23.0/Go SDK и Editor native input/RPC. Прежний
single-module go-language тест не доказывает root go.work или implementations.

## Goals / Non-Goals

Goals: gd/gi/gr в двух native модулях, возврат/выбор результата и общий root.
Non-Goals: свой LSP, root cache/resolver, runtime изменение без reproduction,
rename/format повторы прежней матрицы, смешанный проект, Mac/physical.

## Decisions

- Fixture navigation files дополняют прежний workspace; debug E2E копирует
  прежние5 файлов, Tests7. Их inputs не меняются, повторов не требуется.
- Обычные gd/gi/gr/Enter/Ctrl-o через native input; RPC читает state и
  LspRequest events. Нет подмены client responses/handlers/quickfix entries.
- Один interface и конкретная реализация позволяют проверять конечные symbol
  targets; references quickfix выбирается по настоящему filename/lnum.
- Server cmd/root/client identity записываются; переход в shared обязан
  сохранять project cwd и того же workspace client. Dependencies offline.

## Risks / Trade-offs

- Cold gopls load → predicates по реальному attach/query result, без sleeps.
- Порядок references → target ищется по path/lnum, не позиции в списке.
- Known POSIX cleanup → workflow/full verdict отдельно, без зелёных retry.
