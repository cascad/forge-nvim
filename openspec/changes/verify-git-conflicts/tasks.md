# Tasks

## 1. Конфликты и фокус результата

- [x] 1.1 Добавить real merge conflict E2E, воспроизвести Alt+e на исходном config и сохранить RED/metadata; уточнить причину и решение в истории/документации.
- [x] 1.2 При подтверждённом RED исправить общий selector editable, проверить merge resolve/continue и abort на Windows; описать клавиши выбора/завершения/отмены.
- [x] 1.3 Добавить rebase resolve/continue и abort, проверить Windows и независимую сохранность refs/index/файлов, записать ограничения ours/theirs и sequence editor.

## 2. Интеграция

- [x] 2.1 Выполнить новый набор и git-workflow/git-errors/diffview-close Windows/Ubuntu последовательно, strict validate/trace; дописать FIXLOG/HISTORY/ROADMAP/команды, Mac/GUI оставить непроверенными, локально закоммитить завершённый шаг.

Итог: baseline 34f2054 RED 13338206520000; новые 4 и прежние 7+6+2 PASS
на каждой ОС (38 E2E). Source совпадает во всех artifacts, snapshot/refs/
index/files сверены; trace обеих ОС 7 PASS/1 SKIP, strict validate PASS,
169 local links/prefix/source SHA PASS. История — FIXLOG §103.
