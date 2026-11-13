# Design

## Context

См. proposal. §215 использует ready bash-debug0.3.9 и общий native DAP PTY.
Windows Node/WSL2 Ubuntu и Docker Ubuntu SDK уже готовы, engine Running.

## Goals / Non-Goals

Проверить обычную работу с read, normal-mode scroll/search, возвращение к
вводу и остановку из terminal-mode. Mac/physical/cold boot/другие shell
отдельно. Никаких protocol mocks/private session writes/ожиданий по sleep.

## Decisions

- IDE-128 source15383345973860: Editor15, Bash54/parent15, независимый Node24
  был live до debug и исчез после Stop. Native adapter выполняет pkill -P
  для PPID Bash; POSIX Bash -c оптимизирует последний command через exec и
  родителем становится Neovim. Upstream src/bashDebug.ts blobb27ee925 сохраняет
  тот же Stop. Подтверждено именно завершение постороннего Editor child.
- SDK patch добавляет newline/exit $? после последнего debugger command:
  outer Bash остаётся родителем, сохраняет exit status и владеет только debug
  subtree. Не меняем backend/protocol и не добавляем proxy/process manager.
- Windows target20909137099400: штатный exit получил TerminatedEvent, но Bash
  PID12943/parent12942 оставались live до закрытия IDE. Native adapter посылает
  q и немедленно TerminatedEvent; nvim-dap закрывает adapter раньше обработки q.
  Первый вариант teardown прошёл Windows7 checks, но нормальный exit печатал
  Killed. Второй fragment ждёт штатное bashdb "That's all, folks..." после q,
  затем закрывает native proxy тем же owned-pkill и посылает TerminatedEvent.
  Нормальный debugger не убивается; нет нового protocol/polling/process manager.
- JSON рядом с Bash module хранит pinned before/after SHA и точную замену,
  общий источник данных Python prepare и Lua explicit BashDebugPrepare.
  F5 проверяет bytes; unprepared/unknown payload отклоняется с инструкцией,
  обычный startup/launch сам исходник не исправляет. Plugin pins/patches прежние.
- Первые Ubuntu0/2 выявили также ошибки наблюдателя: Frame нельзя возвращать
  целиком через RPC; PPID может быть Editor, который должен продолжать работать.
  Возвращаем bool, проверяем только принадлежащие backend PID и live sentinel.

- Private Bash script печатает120 строк, останавливается перед read и пишет
  введённую строку/последующий marker. Отдельный case останавливается на read.
- Только F9/F5/Space w c/Space w 0, native normal commands и i/Enter/Shift-F5.
  RPC читает реальную session/frame, terminal buffer, cursor и native logs.
- Marker PID/parent принадлежит fixture; после stop проверяется ps для этих
  PID кроме самого Editor; sentinel остаётся live до explicit fixture cleanup.
  Дополнительно native Editor scope. Никакой global process cleanup.
- По одному прогону версии Windows и Ubuntu; при FAIL сохраняются raw/logs,
  исправление открывает новую итерацию. Изменённый runtime требует delta.

## Risks / Trade-offs

- Terminal-mode поглощает обычные клавиши → проверяем mode и используем
  штатный Ctrl-\\ Ctrl-n для scrollback, затем i для stdin.
- Backend может не поддерживать интерактивный ввод → не маскировать ошибку
  новым proxy/адаптером; сохранить точный результат и определить границу.
