# Design

## Context

См. proposal. Neogit предоставляет native commit selector, gitrebase buffer и
клавиши gk/gj/f/Submit/Abort. Прежний IDE-GIT-11 покрывает конфликты, но не todo.

## Goals / Non-Goals

Goals: reorder/fixup/submit и отмена изменённого todo с подтверждением реального
Git graph/tree. Non-Goals: новый Git backend, private state mutations, production
remote/credentials/history, GUI/Mac, развитие test runner.

## Decisions

- Два private Git repo: baseline и три независимых commit A/B/C. Подготовка
  CLI создаёт fixture; interactive rebase запускается только из native Neogit UI.
- Из status: r→i→native commit selector→A, затем gitrebase keyboard. C движется
  перед B и становится fixup A; Submit оставляет A+C и B при том же конечном tree.
- Во втором case редактируется todo и выполняется native Abort; HEAD/refs/tree/
  рабочие файлы должны совпасть с исходными, rebase directories отсутствовать.
- RPC читает UI/buffer state, Git CLI проверяет graph/tree после. Не подменяются
  editor/Neogit actions/todo file через RPC или внешнюю запись.
- Последовательные Windows и Ubuntu прогоны. Известные native quit/POSIX gates
  сохраняются отдельно от workflow; без green retry или SDK/deadline изменений.

## Risks / Trade-offs

- Асинхронный editor RPC → predicates по filetype/готовым mappings и Git state.
- Prompt подтверждения Abort → ответ только на ожидаемый prompt, raw UI сохраняется.
- Docker недоступен → Windows продолжается, Ubuntu явно pending до готового engine.

## Source IDE-123 и узкая граница

Submit1923603547100 PASS, abort1972523353100 FAIL из-за ложного ERROR. Native
exit0/scope ok; snapshot Git refs/tree/HEAD unchanged, нет unmerged/rebase.
Log показывает отдельные hint и error lines, upstream default rebase.lua
blobed8aa001577a31ada0ae76e8342d6db0e314bfd8 имеет тот же stdout[1] pattern.

Существующий pinned Neogit backport получает один companion rebase.lua:
соединяет stdout и проверяет обе native editor-message строки. Настоящий
Git conflict не содержит этой пары; отдельный third case переставляет
зависимые A/B, получает реальный unmerged index и делает native rebase abort.
Не перехватывать vim.notify/публичные actions, не подавлять общий ERROR.

Price: existing6 dependencies теперь14 файлов. Pins/SDK прежние. Preparation
явная, ordinary startup source не меняет. Удаление patch после готового
upstream fix + тех же submit/abort/conflict cases на целевых ОС. На Windows
обновляется только .tests/editor-deps/lazy/Neogit и его prepared manifest.
Без network/SDK rebuild; Ubuntu image с прежним payload требует явной local
подготовки private SDK overlay либо build после готового engine.

## Межплатформенная итерация

Первый target Windows submit/abort PASS, third conflict case получил ERROR и
unmerged index, но тест открыл r popup до обновления native status (253.../2542895048900).
Исправлено только ожидание видимых Rebasing/unmerged/Abort; runtime тот же.
Ubuntu target с этой проверкой: submit/conflict PASS, abort222708347331 FAIL:
Git2.43 пишет «There was», Windows Git — «there was». Общее classification-copy
stdout теперь lower-case, видимый output не меняется, ветвлений ОС нет.
Original pin сохраняется; local v1 payload явно revert/apply через общий CLI,
новый after SHA в manifest, никакой сети/SDK rebuild. Повторяются лишь новые
Git3 и preparation15 на новой версии, прежние mixed9/old conflicts не повторяются.

Old Windows git-conflicts rebase-abort2633297634000 дал timeout до конфликта:
notifications пусты, HEAD/refs/tree не изменились; источник запуска не установлен.
IDE-124 отдельный gate, не приписывается этому parser fix. Тот же Ubuntu old
набор4 PASS; это не объясняет исходный Windows FAIL.
