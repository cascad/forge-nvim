# Design

## Context

См. proposal.md. editor_process посылает raw RPC notification nvim_command qa!,
ждёт 2 s, затем сигналит собственный child. SystemObj.write не предоставляет
публичного ack; успешный возврат не доказывает native receipt. SystemObj.is_closing
показывает закрытие handle, а completion callback vim.system ждёт EOF stdio.

## Goals / Non-Goals

**Goals:** получать различимые evidence этапов через существующие API, сохранять
source/первичные ошибки и владение процессами, проверить capture на реальном Nvim.

**Non-Goals:** объявить первопричину по старому логу, повысить timeout, заменить
quit/input path, чинить или отключать product hooks, менять SDK/Docker lifecycle,
считать намеренно задержанный fixture воспроизведением исходного бага.

## Decisions

- Отдельный test-only recorder пишет bounded JSONL через sync uv fs (включая
  fast callbacks); его ошибки фиксируются и не перекрывают первичную ошибку.
- Native observer устанавливается --cmd до init; timestamp общей monotonic
  шкалы, события QuitPre/VimLeavePre/VimLeave, без обёрток пользовательских hooks.
- Минимальные quit/EOF/completion records постоянны; подробные request/chunk
  metadata — только по flag, с лимитом. Payload/исходники RPC не логируются.
- Ошибки API notification сохраняются в api_errors и critical trace даже после
  detail cap. Native invalid command fixture проверяет этот путь, без fake replies.
  FORGE_E2E_QUIT_TRACE=0 служит только unhooked comparison: два оставшихся
  baseline samples выполнены без observer, но с in-memory API error capture.
- Шесть файлов helper копируются до старта child с byte length/SHA; старые
  baseline artifacts с ними не смешиваются.
- Stop сохраняет штатную qa!/2 s/SIGTERM/SIGKILL последовательность. Handle
  closing и native events — разные наблюдения, не подмена OS exit доказательства.
- Native normal и реальный QuitPre с задержкой проверяют обе ветки capture.
  Исходный поиск повторяется отдельно, максимум 3 samples за серию.

## Risks / Trade-offs

- Observer меняет тайминг на стоимость записи → исходный uninstrumented RED
  сохранён; отсутствие повтора не доказывает исправления.
- Callback API при завершении ограничен → минимальные данные, защищённые записи;
  trace failures видимы в metadata и не меняют product/cleanup verdict.
- Mac/POSIX различия → native Ubuntu отдельно, Mac gate до фактического запуска.
