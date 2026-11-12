# Design

## Context

См. proposal. Штатный filesystem navigate имеет debounce и async IO:
focus_main после open не является концом открытия окна. Существующий
forge.neo_tree_lifecycle уже получает rendered и обрабатывает позднее окно.

## Goals / Non-Goals

**Goals:** закончить пассивное восстановление в том же lifecycle callback,
сохранить последующий явный фокус общих команд.
**Non-Goals:** новый window manager, глобальные input hooks/таймеры, замена
backend/show/scan, изменения dependency patches/SDK, DAP/session lifecycle.

## Decisions

- При общем restore state передаёт optional open context focus=false.
  Остальные вызовы сохраняют обычное открытие. Другие wrappers могут
  игнорировать context; Neo-tree адаптер передаёт его existing lifecycle.
- Lifecycle хранит только ожидаемый возврат по штатному source state.
  По rendered получает public prior window и в прежнем scheduled callback
  возвращает фокус, только если курсор всё ещё в открывшемся дереве.
- Явный focus компонента отменяет ожидаемый возврат; default FT finder
  сохраняет прежний порядок окон. Новое обычное open тоже отменяет ожидание.
- Отвергнут дополнительный timeout/focus_main timer: он перекрывает более
  поздний выбор. Простой backend show хранит старое окно до async navigate,
  поэтому не покрывает последующий выбор Logs. Backend не переписывается.
- Permanent E2E удерживает настоящий callback native navigate после штатного
  debounce. Сам backend/scan/renderer получает исходные аргументы и данные.
  Первый вариант с удержанием EOF оказался слишком поздним: окно уже было
  создано до удержания. Source5 PASS не считается воспроизведением IDE-116.

## Risks / Trade-offs

- Отмена явного Files focus → отдельный control до release IO.
- Отмена позднего Logs focus → выбор Logs при удержанном IO, затем release.
- Неполный callback barrier → real rows/ready и scheduled queue barrier;
  fixed sleep в тесте не используется.
- Остальные источники/вкладки → existing source/tab/Outline/work/frame/session
  regression; Windows/Ubuntu по очереди, Mac отдельно.
