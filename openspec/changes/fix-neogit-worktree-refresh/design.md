# Design

## Context

См. proposal.md. В pin Neogit d7bb91b M.list сначала запрашивает records через git log, затем ASCII M.graph запускает второй log, используя глобальный текущий repo. status.chdir переключает repo, пока старые coroutine могут ещё исполняться. Несовпавший OID вызывает assert в parse_log. Memoize различает cwd, но не фиксирует контекст между двумя запросами одной coroutine.

## Goals / Non-Goals

**Goals:** безопасный быстрый visit, согласованный снимок истории и графа, минимальное общее изменение и реальный воспроизводимый регресс Windows/Ubuntu.

**Non-Goals:** IDE-027 native terminal crash, новый Git backend, monkey patch/форк Neogit, изменение worktree/commit/push операций, merge/rebase и GUI/Mac проверка без целевой машины.

## Decisions

- Выбрать public graph_style=unicode: штатный renderer строит граф из уже декодированных commit одного запроса. Нет отдельного запроса к изменяемому repo и несогласованного graph lookup; одинаковая настройка всех ОС, на один Git-процесс меньше при построении графа.
- Upstream bf4ace99f убирает assert для отсутствующих commit, но сам по себе не фиксирует два снимка; текущий HEAD содержит ещё 55 commit после pin. Для этой задачи не менять зависимости и не скрывать ошибки через pcall/фильтр notifications. Участие остальных refresh модулей проверяется конечным Head/recent/log, а не объявляется исправленным на основании исчезнувшего assert.
- Прозрачный test-only git_executable wrapper через public config выполняет настоящий log в исходном cwd и задерживает выдачу уже полученных данных до release. Затем status посещает другой worktree. Данные, return code и пользовательские действия настоящие. POSIX использует exec Python через shell; Windows — небольшой native .NET launcher argv, собираемый встроенным Windows PowerShell, без cmd.exe. Простой .cmd probe сохранил %H, но полный Git format содержит %cd%, который cmd раскрывает в текущую папку и повреждает запрос. Первую такую ошибку каркаса не считаем red IDE-028; gate обязан подтвердить реальный exit code 0.
- Независимый сценарий естественных быстрых visit использует настоящий git без proxy. Ожидания относятся к picker/cwd и конечному status; перед следующим visit готовности Head не ждём.
- Сохранить исходный runtime config и append-only FIXLOG в .tests/baselines/neogit-worktree-before. Все Windows temp на F:, профили удаляются штатным editor.stop.

## Risks / Trade-offs

- Граф визуально меняется с ASCII на Unicode → сохранить commit сообщения/ветки/операции и проверить log UI; обычный Unicode уже нужен для остального IDE.
- Начальный refresh может отменяться Neogit при повторном запросе → gate наблюдает реальные запуски/вывод, проверяется незавершённый выбранный status и фактическое продолжение backend; отмена не подменяется успешным результатом.
- Старые callbacks других модулей → конечные cwd/Head/recent/log, неизменность Git/файлов и окно наблюдения поздних ошибок; обнаруженные соседние сбои сохранять отдельно.
- Mac/WezTerm GUI недоступны → команды и явная отметка непроверенной среды.
- Windows launcher с CreateNoWindow требует явных stdout/stderr pipes → копировать бинарные потоки до конца, сохраняя код Python/Git. Вариант без pipes дал пустой log в первом full; повторный focused сценарий с pipe pump прошёл. Это тестовый транспорт, не изменение Neogit.
