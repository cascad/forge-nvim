# Design

## Context

См. proposal. Source fd6b965 проходит dap-launch-routes на настоящем
Rust/CodeLLDB:3 последовательных запуска и cancel. Space dP раньше не имел
своего editor E2E. Общие флаги и session/PTY backend остаются на месте.

## Goals / Non-Goals

**Goals:** устранить две копии общей последовательности с сохранением порядка.
**Non-Goals:** новый session manager, перенос функций по новым файлам,
изменение adapters/terminal pool, language choice, error policy или focus.

## Decisions

- run_config принимает сам cfg и содержит прежний open/reset до Node guard.
  F5 unwrap choice.config, Space dP передаёт cfg напрямую. Старый return при
  отсутствии cfg сохраняется. Вызов dap.run остаётся внутри with_launch_buffer.
- prepare_debug_action содержит прежние leave_terminal_mode,
  remember_launch_buffer и current-session view. Schedule/picker/continue
  остаются у маршрутов: F5 продолжает активную сессию, Space dP выбирает проект.
- Идентичные helpers не превращаются в service/registry. Новых зависимостей,
  глобального перехвата dap.run и работы при startup не добавляется.

## Risks / Trade-offs

- Смена порядка UI/reset/readiness → сохранить строковый порядок старой цепочки,
  source/target native launch-routes и existing Node missing-tool сценарии.
- Старый PTY/output или потерянный ${file} →3 реальных сессии, args/source,
  разные buf/channel, stdout до/после паузы и отмена без сброса истории.
- Ошибка scheduling → existing Go/Python/Node/Rust debug и late-focus E2E.
