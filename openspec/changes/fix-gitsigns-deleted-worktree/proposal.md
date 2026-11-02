# Proposal

## Why

IDE-035: незавершённый initial diff Gitsigns после удаления worktree запускает следующий Git из исчезнувшего cwd. `vim.system` выбрасывает ENOENT, async traceback блокирует ввод. IDE-BUF-4 сохраняет удалённый буфер после готового diff, но не покрывает этот промежуток; добавляется IDE-GIT-8. Управляемый real Git repro: artifact 1783013359300; Gitsigns manager → get_show_text_at_revision → git/cmd.lua.

## What Changes

- Передавать рабочую папку Gitsigns через штатный `git -C`, сохраняя ошибки Git обычным результатом процесса при исчезновении пути. Никаких retry, задержек или перехвата глобальных ошибок редактора.
- Использовать существующий явный механизм временных backports с pin/SHA для Gitsigns; Neogit backport IDE-034 сохраняется.
- Добавить постоянный E2E с задержкой настоящих результатов Git: initial show → успешное удаление → следующий show; сохранить текст и проверить последующий hunk stage. Отдельно проверить отказ force и stage в правильном linked worktree.
- Дополнить явный CLI подготовки выбором одного плагина; проверить обе декларации и отсутствие записи при обычной загрузке.
- Записать причину, A/B, проверки Windows/Ubuntu и ограничения Mac в FIXLOG/HISTORY/roadmap.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-8, незавершённые Git signs при исчезновении worktree; продолжение неархивированных Git changes, основной Git spec ещё не создан.

### Modified Capabilities

Нет.

## Impact

Gitsigns pinned source `dd3f588bacbeb041be6facf1742e42097f62165d`, общий backport CLI, test Git proxy и editor E2E. Реализация общая для Windows/macOS/Linux. SDK, Neogit UI, shell startup и диагностика IDE-036 не меняются.
