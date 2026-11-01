# Tasks

## 1. Воспроизведение

- [x] 1.1 Сохранить исходный artifact IDE-032 и получить устойчивый red реального удаления loaded worktree/checktime на Windows; добавить tests/e2e/deleted-files.test.lua, без подмены Git результата/расширения timeout. Windows red 22298339049700, настоящий блокирующий prompt после native delete.

## 2. Общая политика удалённых файлов

- [x] 2.1 Реализовать IDE-BUF-4 через public native events в ide.buffers; проверить сохранность текста/modified/hidden buffers, одно предупреждение, pending autosave и write/Save As реальными editor E2E Windows/Ubuntu. Focused 5 PASS на обеих ОС; контроль старого полного config-source 36164862736900 даёт E211.
- [x] 2.2 Проверить обычный autoread и конфликт существующего файла, исходный IDE-GIT-3 и полные buffer/Git/worktree-refresh наборы Windows/Ubuntu; не маскировать чужие prompts/errors. Все эти наборы PASS в обоих full, native W12 с сохранностью обеих версий проверен.

## 3. Регресс и история

- [x] 3.1 Пройти full Windows с выбранным SDK и Ubuntu, quick/trace/strict validate/diff --check; сохранить отчёты и проверить 0 runtime/C temp и source lock без изменений. Windows 38 PASS/1 FAIL (SDK CLI/IDE-031)/2 SKIP, SDK повтор 2 PASS; исходный full сохранён, причина CLI не объявлена исправленной. Ubuntu 37 PASS/0 FAIL/3 SKIP. Mac/GUI явно не проверены.
- [x] 3.2 Дописать FIXLOG §95 со Спека: IDE-BUF-4 (ADDED), причиной/изменениями/тестами/выводом; обновить HISTORY/PROBLEMS/ROADMAP/AGENT_COMMANDS/e2e docs, проверить байты прежней истории. Прежние 338647 байт сохранены точно, e11f8299b6bebcaa0aa5d9b4fefd9d92430100a5fd253e1ae03c97d6d5a677d2.
