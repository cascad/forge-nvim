# Proposal

## Why

После IDE-GIT-10 этап 5 ещё не проверяет merge/rebase-конфликты. Требуются
сквозные действия выбора версии, stage/continue и abort с сохранностью веток.

## What Changes

- Проверить merge и rebase конфликт, Diffview/result, сохранение/stage/continue
  и отдельную отмену через штатные клавиши Neogit.
- Проверить `Alt+e` именно на редактируемом результате трёхстороннего diff.
  Текущий selector выбирает крайнее правое окно; сначала получить real RED.
- Исправить только подтверждённое нарушение, сохранив общий путь всех ОС.
- Добавить Windows/Ubuntu E2E, историю, команды и инструкции конфликта.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-11, конфликт и завершение/отмена. Продолжение
  unarchived Git capability; основного spec ещё нет.

### Modified Capabilities

Нет.

## Impact

Клавиатурный фокус Diffview, real editor fixtures, registry и документация.
Штатные Git/Neogit/Diffview без отдельного backend. Credentials и IDE-043
не входят. Mac/физические GUI клавиши требуют отдельного прогона владельца.
