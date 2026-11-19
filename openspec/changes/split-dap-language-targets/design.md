# Design

## Context

См. proposal. Go helpers независимы от UI. Cargo resolver использует native
async program coroutine; Python helpers читают launch buffer и project roots.
Общие normalize_path/with_launch_buffer/current_launch_path уже существуют.

## Goals / Non-Goals

Goals: ясные языковые границы и неизменные function bodies/native entrypoints.
Non-Goals: новый dispatcher/state manager, новая SDK policy, adapter updates,
рефакторинг панели/session/output, SQL или изменение UI/клавиш.

## Decisions

- Прямые imports и aliases в прежних местах: все публичные DAP configs/keys
  получают те же функции с прежней сигнатурой. Module load определяет только
  helpers, не запускает discovery/SDK/adapter.
- Go module содержит Delve candidates/version/override/info; Rust — Cargo
  root/metadata/bin/example selection/cancel; Python — roots/venv/debugpy/
  native adapter options. Context — три прежние функции без нового состояния.
- Механическое извлечение блоков и обратная source-fidelity проверка к766b775;
  затем existing native E2E после цельной реализации. Не писать зеркальные
  unit tests для простого переноса.
- Один selected native packet на ОС, через явные существующие *_CASE filters:
  batch runner очищает эти filters, поэтому direct native invocation обязательна.

## Risks / Trade-offs

Замыкания/порядок locals → явный context import и source fidelity, native F5
во всех3 языках. Cancel/cwd race → Rust pending/stale controls. Adapter options
и launch.json → реальные late Delve и Python project/pytest sessions.
Нативные Mac/Omarchy/physical keys отдельно; latency не измеряется.
