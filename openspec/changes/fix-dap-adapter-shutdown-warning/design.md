# Design

## Context

Диагноз и source evidence — proposal.md/IDE-053. Debugpy logs завершаются
штатно, stderr пуст. Libuv на Windows реализует SIGINT завершением процесса:
https://docs.libuv.org/en/latest/guide/processes.html. Код nvim-dap не учитывает,
что сам вызвал остановку adapter. Это не свидетельство ошибки pytest/debugpy.

## Goals / Non-Goals

Исправить ложную ошибку штатного shutdown и сохранить genuine crash warning.
Не переписывать exit codes, не скрывать все WARN, не менять transport/SDK,
не вводить дополнительные таймеры и не перестраивать процессный lifecycle.

## Decisions

1. В stdio process exit callback прочитать closed до onexit. Флаг уже true,
   если frontend инициировал закрытие; native onexit всё ещё закрывает pipes/
   выполняет прежний bounded signal sequence. Поздний ожидаемый code не даёт
   ложный WARN, но остаётся в raw logger.
2. Если process умер до client close, closed false: nonzero сохраняет stderr
   и WARN. Negative E2E задаёт публичную user adapter configuration с настоящим
   Python process и args -c/raise SystemExit(23), запускает её через проектный
   launch.json/F5: процесс действительно завершается с ошибкой; UI показывает
   warning, session исчезает, код редактируется. Это fault injection процесса,
   не mock протокола/server/handler.
3. Backport привязан к commit 45a69eba683a2c448dd9ecfc4de89511f0646b5f и
   before/after SHA, применение только явным build/prepare. Source RED replay
   восстанавливает точный старый plugin в private copy, global deps неизменны.
4. Не используем TCP/другой launcher ради избежания error: проверяем ту же
   реальную stdio конфигурацию. Не делаем вывода о всей IDE-006 на Mac.

## Risks / Trade-offs

- Exit почти одновременно с close → capture берётся до onexit текущего callback,
  неожиданный процесс не становится ожидаемым из-за самой обработки его exit.
- Late adapter shutdown за пределами session nil → E2E ждёт actual Neotest
  result и отдельно проверяет notifications/output, не только отсутствие session.
