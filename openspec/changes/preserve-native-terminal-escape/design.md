# Design

## Context

См. proposal. Полный native probe показал t→nt без нового terminal и с тем же живым PID, независимо от загрузки ToggleTerm. Точный echo probe8990083162500 показал nt→новый toggleterm/t. Config.open_mapping не задан, terminal map отсутствует; раннее описание IDE-023 уточняется новой историей.

## Goals / Non-Goals

**Goals:** native escape идемпотентен для terminal buffers, прежние normal aliases вне терминала сохраняются; shared fix на Windows/Ubuntu без новых слоёв.

**Non-Goals:** Terminal/Trouble common controls, смена shell, shortcut C-t/Space tt, UI/layout/DAP/process lifecycle, новые mappings/autocmd/timers, SDK/plugin updates. Физические клавиши Mac/GUI отдельно.

## Decisions

- Существующий normal Ctrl-\\ становится expr mapping: в terminal buffer возвращает native control byte без remap, иначе прежнюю команду ToggleTerm. Только чтение buftype; никаких feedkeys/state/hooks или ожидания второго key через timer.
- Single Ctrl-\\ в terminal-normal является native prefix, не managed toggle. Для toggle из этого контекста остаются Ctrl-t/Space tt; из кода Ctrl-\\ работает как прежде. Это граница самого исправляемого конфликта, а не удаление terminal функции.
- Native E2E: echo уже в nt, live interactive worker с literal input и repeated escape cold/loaded, managed terminal escape, code aliases/reuse, реальный Rust/CodeLLDB breakpoint/PTY. Source6dea7b8 replay через существующий config override до fix; тот же SDK/fixtures/test source. Не считать саму загрузку plugin новым terminal/job.
- Worker — настоящий Python CLI/PTY из явных prerequisites, без mock channel/job/session. Positive cases штатно завершают worker; public DAP получает Continue и настоящий итоговый stdout.

## Risks / Trade-offs

Lazy cold mapping и loaded expr path различаются → оба проверяются настоящими key input. Terminal process может закончиться до escape → native close/nt case выделен отдельно. GUI protocol delivery не доказывается RPC → Mac/GUI gate открыт.
