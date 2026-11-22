# Design

## Context

Source cf6095e. Incident session jsonl сохранён в .tests/files-input.
Native повторение create/delete пока не воспроизвело тот же E21: первый draft
observer ошибся с parent создания после удаления (каталог создан в nested).
Этот FAIL не считается воспроизведением product bug. Нужны отдельные проверки
подтверждённых опасных boundaries: modal error, cmp prompt Enter и sync delete.

## Decisions

- Штатный Neovim messagesopt wait:0 сохраняет history/progress и не ждёт
  подтверждения сообщений; nomore убирает paging prompt для длинных ошибок.
  Они не меняют реальные confirm/input dialogs. Новый E2E начинает с native
  more=true до init: общий harness по умолчанию more=false мог скрыть этот gap.
- Panel refresh меняет window options; native redraw сам применяет их.
  Synchronous :redrawstatus внутри nested event processing не нужен.
- Только prompt Enter обходит completion sync; обычное подтверждение cmp прежнее.
- Async delete — companion patch pinned Neo-tree: Plenary async.uv lstat,
  scandir, unlink/rmdir и scheduler для UI/events/cleanup. Ссылки не обходятся.
  Не вводятся новый file manager, subprocess worker или очередь IDE jobs.
- ОС может отказать и после частичного recursive delete: не объявлять success,
  сохранить причину/путь, не удалять буферы оставшихся файлов и не повторять
  разрушительное действие автоматически. Повтор — новое действие пользователя.
- Global no-hit-enter имеет meaningful native error/Logs controls, другие
  режимы сообщений/панели проверяются affected набором после цельного блока.

## Risks / Limits

Нельзя обещать атомарность recursive delete или мгновенное завершение kernel IO.
Требование — отзывчивый UI во время ожидания и после ошибки. Async delete
сохраняет public callback/events; старые dirty guards повторяются после Yes.
Slow successful copy/create на network FS не объявляются исправленными только
потому, что их error-path перестал ждать Enter; отдельный аудит остаётся явным.
