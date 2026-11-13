# Проверка

2026-11-13. Исходная конфигурация dc23a30; final test/helper одинаковы у source
и target. Изменение runtime — только native `async_directory_scan="always"`.

| Среда | Source IDE-FILE-6 | Target scan-order | Filter controls | Ввод при held IO |
|---|---|---|---|---|
| Windows native SDK | RED: sync opendir1 | 8 PASS | 2 PASS | 112.849ms |
| Ubuntu24.04 / Neovim0.12.2 | RED: sync opendir1 | 8 PASS | 2 PASS | 11.980ms |
| macOS | не проверено | не проверено | не проверено | не проверено |

22 final native profiles: exit0/signal0/APIerrors[]/hard_kill=false/scope empty.
Сохранённые config/test/helper bytes совпадают с проверенной версией. Raw:
`.tests/tree-async-source-final.txt`, `tree-async-target.txt`,
`tree-async-file-filter.txt`, `tree-async-audit.json`; guest equivalents в
`.tests/ubuntu`, scan-order target там `tree-async-file-scan-order.txt`.

Первый Windows draft39026721516800 завершился ошибкой проверки сохранённого
содержимого: вставка добавлялась к `alpha`, ожидался целиком новый текст.
Кроме того, sync counter читался до обработки клавиши. Native stack уже
содержал sync_scan. Исправлено ожидание раскрытого узла и штатная замена строки;
драфт сохранён отдельно `tree-async-source-observer-error.txt`. Его native
выход тоже штатный; это не финальное source доказательство.

Docker engine28.5.1 уже работал, image f63a05ca прежний, network none, private
Neogit overlay через существующий pinned applier. Без build/download/Desktop/
WSL lifecycle. Windows/Ubuntu serial, temp F,67 pins/6 backports16 files/SDK
и отложенные startup/infra drafts сохранены. Strict validate PASS.

Mac/physical и фактическая стоимость большого рабочего дерева остаются
открыты. Этот срез доказывает устранение sync IO пути ручного раскрытия и ввод
до завершения настоящего async IO. Он не доказывает длительность Git/render
или полный regression и не закрывает IDE-133.
