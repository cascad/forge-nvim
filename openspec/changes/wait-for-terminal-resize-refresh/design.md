# Design

## Context

См. proposal. В pinned Neovim terminal.c resize меняет vterm geometry и ставит pending refresh через refresh_timer; наличие нового окна ещё не доказывает обновление buffer rows. Capture первого Ubuntu отказа показывает window13→10 при13 buffer rows; следующий snapshot того же буфера уже9 rows.

## Goals / Non-Goals

**Goals:** устранить неоднозначность window-ready/buffer-ready в настоящей resize fixture, оставить строгий raw padding regression на обеих ОС.

**Non-Goals:** менять production/predicate/SDK, добавлять OS branches, sleep/timer/большие timeout, переписывать raw stdout или пропускать неисполненный regression.

## Decisions

- В существующем diagnostic input wrapper после nvim_ui_try_resize и до отправки q ждать actual меньшей высоты окна и buffer line count, равного новому видимому viewport через public getwininfo. Winbar занимает строку: nvim_win_get_height не равен vterm text height. В этой fixture лишь2 stdout marker lines, нет wraps/scrollback и topline1; сохранить geometry/IDs в artifact. Это наблюдаемое native предусловие, не задержка по времени.
- Не менять output_policy.reopen/state/history_preserved. E2E по-прежнему требует raw substring mismatch, сохранение markers/buffer/channel/pause/native cleanup и дополнительно подтверждает actual shrink/refresh.
- Первичный Ubuntu FAIL/source bytes72cb336 сохранены до edit. Тот же сценарий Windows/Ubuntu после исправления, затем оставшиеся portable gates. Исходные debugger/engine failures не считаются исправленными новым GREEN.

## Risks / Trade-offs

Если fixture начнёт выводить scrollback, equality rows/viewport перестанет быть корректным предусловием → явный FAIL вместо ложного PASS; не применять это правило к обычному Output или общему helper. Mac без запуска остаётся непроверенным.
