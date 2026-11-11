# Design

## Context

См. proposal и docs/PANEL_FRAME_DESIGN.md. Native dapui.float_element —
временный popup, закрывающийся при уходе фокуса. Он не подходит для панели.

## Goals / Non-Goals

Проверить один opt-in layout без собственного backend и polling. Не менять
default, не распространять рамки на другие панели, не переписывать FSM/Edgy.
Другие sidebar и native layout команды возвращают обычную раскладку.

## Decisions

- Публичный dapui.open показывает native Scopes; буфер получаем из его окна,
  затем закрываем layout1 публичным dapui.close. Native renderer продолжает
  обновлять тот же буфер. Приватные dapui.elements не используются.
- Один пустой native root обязателен Neovim; два рабочих float Code/Locals
  занимают его прямоугольник. Root не содержит копию code/scopes. Bottom остаётся
  Edgy; root resize задаёт оставшуюся область, без второго владельца этих floats.
- Кодовый float явно считается main в ide.state; существующие controls получают
  узкую opt-in делегацию focus/direction/zoom. Обычный путь прежний.
- WinResized/VimResized, WinEnter и закрытие вместо таймера. Tab/session выход
  останавливает эксперимент. Минимальный размер проверяется до изменения окон.
- Раскрытие/шаги/вывод — реальные DAP UI/Delve и штатные клавиши, без подмены
  действий тестовыми maps. Нельзя засчитать frame prototype overlay как пилот.

## Risks / Trade-offs

- Floating code меняет ожидания backend → E2E шага и следующего breakpoint;
  приватный fork/постоянные shadow splits не принимаются.
- Новая интеграция controls/main → отдельные исходные regression и существующие
  panel E2E. До широкой миграции оценить число строк и специальных веток.
- Не все layout поддержаны → пилот ограничен одной code group и Locals;
  переключение tab/session завершает его, остальные панели ещё без рамок.
- Физический WezTerm/Mac → отдельная проверка, headless RGB не заменяет её.

## Migration Plan

Явная команда ForgeFramePilot. Повторная команда возвращает обычную раскладку.
Удаление пилота не требует миграции данных. Default не меняется этим change.
