# Design

## Context

См. proposal.md. В контролируемом real Git repro начальный `show <blob>` уже успешно завершён, доставка результата задержана; настоящий `worktree remove` удаляет linked, но его callback тоже задержан. Возврат blob возобновляет initial update, который запускает следующий `show HEAD:file` с отсутствующим cwd. Artifact 1783013359300: ENOENT в git/cmd.lua → manager.lua:366 → attach.lua:445, hit-enter. Обычный быстрый repro может пройти, поэтому он не доказывает отсутствие гонки.

Приватный вариант четырёх строк прошёл тот же gate (2079365207200). Исследованный официальный Gitsigns main `1e9d0fb…` сохраняет процессный spec.cwd в git/cmd.lua; обновление debounce восстанавливает flags после ошибки, но повторно выбрасывает саму ошибку. Это анализ исходников, не заявление о выполненном upstream E2E.

## Goals / Non-Goals

**Goals:** корректная граница Git process при исчезнувшем пути, реальная воспроизводимая проверка и единая явная подготовка уже принятым механизмом.

**Non-Goals:** ожидать завершения всех signs перед удалением, глобально перехватывать vim.system/notify, свой Git backend, обновить весь Gitsigns на 40 commits, лечить IDE-031/036 или удалять worktree, занятый чужим процессом.

## Decisions

1. В Git command builder перенести запрошенный cwd в глобальную опцию `git -C`, убрать только process cwd. Git остаётся настоящим: отсутствующая папка даёт обычный nonzero/stderr. Путь не заменяется main при поиске репозитория; ошибочный запрос не должен случайно прочитать main. Семантика `-C` описана официально: https://git-scm.com/docs/git.
2. Минимальный временный backport pinned Gitsigns через существующий `patches/plugins.json`, Lazy build и общий hash applier. Никакой модификации приватных Lua функций в рантайме. Добавить `--plugin <name>` к явному CLI; default all сохраняется, но тестовые fixtures одного плагина выбирают его явно.
3. Gate работает через argv proxy/PATH только внутри private editor. Он задерживает доставку уже вычисленных real stdout/stderr/code, не синтезирует результаты. Test launcher освобождает свой cwd до ожидания, иначе Windows сам не даст удалить папку. Опциональный env для этого не меняет старые Neogit gates.
4. Два UI E2E: удаление между index/HEAD reads с последующим stage main; dirty cancel с последующим stage linked и сохранностью main. Публичные signs status, реальные index/HEAD и уведомления — наблюдения. Repro variant явно возвращает только private Gitsigns в upstream bytes и требует старого config source без нового guard.

## Risks / Trade-offs

- Меняется запуск всех Gitsigns Git commands → проверить initial diff, оба worktree, stage/unstage, прежние Git/deleted-file/refresh E2E Windows/Ubuntu.
- Другой текущий каталог при запуске Git → `-C` сохраняет адресацию относительно исходного пути, тестом проверяется отсутствие stage в main вместо linked.
- Два локальных backports → один существующий applier, pin/SHA, явное снятие перед обновлением. Не добавлять бессрочный fork; убрать после подтверждённого upstream fix.
- macOS не доступен → та же реализация и native команда, результат непроверено.

## Migration Plan

Повторить явную prepare_editor/Docker build. На установленном Forge выполнить `:Lazy build gitsigns.nvim`, затем перезапустить редактор; Neogit сохраняет свой существующий backport. Для отдельной подготовки/проверки/отмены CLI получает `--plugin gitsigns.nvim`. После upstream fix отменить известный патч, обновить pin/декларацию и повторить тот же регресс.
