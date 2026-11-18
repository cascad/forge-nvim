# Design

## Context

Generic stop сохраняет scope result в shutdown.json. В POSIX active() уже
имеет native ps result, но assert оставляет только stderr. SIGCHLD/OOM/
kernel/лимиты не объявляются причиной без соответствующего native результата.

## Goals / Non-Goals

**Goals:** сохранять полный отказ boundary и не принимать failed probe за
доказательство empty groups. Windows backend и успешный POSIX lifecycle прежние.
**Non-Goals:** новый process manager, fallback probe, retry/больший timeout,
историческая root cause по догадке, управление Desktop/WSL или чужими группами.

## Decisions

- На границе vim.system сохранять native result/ошибку spawn только при
  отказе, argv/elapsed/номер попытки. Успешные ps stdout не копировать в каждый
  shutdown: polling может происходить многократно, process table не нужна.
- При nonzero code/signal или ошибке spawn выходить прежним error path.
  Scope.ok=false, active_after не выводится, сигналы по неизвестной таблице
  не отправляются. Существующая политика SIGTERM/SIGKILL групп не меняется.
- Permanent E2E запускает real clean Neovim в собственной группе. Частный
  executable ps контролирует native boundary, не подменяет vim.system/wait
  или код resolver. Контроль делегирует настоящему ps с исходными аргументами.
- После восстановления PATH отдельный настоящий ps подтверждает отсутствие
  живых зарегистрированных групп. Intentional probe failures различаются
  от failed native editor: сам root завершается0/0.
- Source driver фиксируется git3d0e6b7. Windows получает platform SKIP
  новых POSIX cases, а существующий Job/editor/session regression выполняется.

## Risks / Trade-offs

- Даже code0 с nonzero signal обязан оставаться FAIL: native negative case
  должен подтвердить ветку до реализации; старый active смотрит только code.
- Ошибка запуска не имеет native exit result: сохранять spawn_error, а не
  выдуманные code0/signal0. Обычное native завершение хранит все поля result.
- 2026-11-18 existing Ubuntu engine доступен. Frozen3d0e6b7 source native1 PASS/
  3 FAIL подтверждён до observer fix. Для spawn fixture PATH ограничен private
  bin: execvp иначе продолжает поиск после отсутствующего shebang interpreter
  и находит настоящий ps. Target проверяется отдельно; Mac остаётся открытым.
