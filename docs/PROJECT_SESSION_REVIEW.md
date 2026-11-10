# Project/session: native baseline

2026-11-10. Продолжение IDE-080, runtime HEAD fad809c, 67 plugin pins и выбранный
Windows SDK 0.12.2 прежние. Это coverage перед упрощением, production не менялся.

Старый code-window probe проверял Persistence save/load в одном процессе.
Новый scenario использует настоящий TUI внутри private editor terminal:
Neovim сам обрабатывает restart UI event и подключается к новому backend.
Дочерняя сборка получает те же private config/data/state; host persistence
остановлен, чтобы fixture не перезаписывал сохранение. Observer пишет lifecycle
и readiness; не вызывает restore/restart вместо редактора. Ввод — PTY,
наблюдение — public RPC по native socket/pipe.

| Переход | Что проверено на Windows |
|---|---|
| quit → новый запуск → Space qs | Новый PID; три файла в двух tabpages, cursor 23:7 / 37:5 / 47:3 |
| Служебные окна перед quit | Explorer на первом tabpage, Quickfix на втором; после restore Quickfix нет, Explorer открыт, code windows без panel marker/winfix |
| A→B через config.start | Новый PID и cwd B, буферов A нет, modified строка third.txt записана до входа в B |
| B→A через config.start | Ещё один PID; исходные files/tabpages/cursors и изменённый текст восстановлены, буфера B нет |
| Завершение | Native TUI exit0; host exit/signal0, API errors пусты; scope пуст без helper signals/TerminateJobObject |

Проекты имеют пробелы и Unicode в путях. Lifecycle каждого из четырёх backend
содержит VimEnter/ready/VimLeavePre/PersistenceSavePost/VimLeave; у restore
есть PersistenceLoadPost. Session Vimscript, raw states, terminal screen,
source helpers/config/pins и shutdown сохранены до удаления owned runtime.
Windows Job accounting может обновиться после native exit callback: fixture
наблюдает drain до close, как прежний process-lifecycle E2E. Это не новая
production lifecycle политика и не объяснение Docker IDE-087.

Команды из корня репозитория после обычной явной подготовки plugins:

```powershell
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/project-session.test.lua
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/project-session.lua
```

На Ubuntu/Mac: `nvim -l tests/e2e/project-session.test.lua`. Сценарий входит
в общий `nvim -l tests/run.lua e2e`, scripts/test.ps1 и scripts/test.sh e2e/full.
CLI --id принимает requirement ID, а не SELF labels; для одного этого файла
используется прямая команда выше.
Дополнительные language tools, сеть, Docker/WSL самому тесту не нужны.

Native TUI на Windows проверен. Ubuntu/Mac не запускались; физические клавиши
WezTerm/GUI, branch-specific sessions, Space qd/ql/qS, ошибка записи файла,
удалённый project root и активный DAP при смене проекта остаются отдельными
сценариями. Этот baseline не доказывает их исправность.

Отдельное наблюдение IDE-095: Space qs возвращает код, config.start restore
возвращает Explorer focus. Комментарий PersistenceLoadPost обещает editor
focus, а config.start повторно вызывает project:open. Причинность требует
source RED; baseline не закрепляет нынешний Explorer focus как контракт.
Следующий небольшой шаг — проверить этот дублирующий маршрут и только затем
решать о сокращении session glue. Новое root/session ядро не требуется.

Пилоты не считаются product RED: missing Lua field сначала сравнивался с
vim.NIL; Escape и следующий текст в одном PTY burst распознались как Alt;
naive поиск Quickfix marker в session source нашёл сохранённый statusline,
хотя actual Quickfix window не восстановилось. Raw artifacts не переписаны.
Постоянный тест проверяет actual windows, marker/winfix, buffer text и lifecycle.
