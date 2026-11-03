# Tasks

## 1. Go language E2E и явная подготовка

- [x] 1.1 Добавить prepare_lsp.py с fixed versions/module metadata/SHA/ограниченным build, отдельными server/formatter PATH; явно подготовить на Windows и проверить повтор без download, описать команды подготовки в E2E README.
- [x] 1.2 Добавить dependency-free multi-file fixture и зарегистрированный реальный UI E2E definition/references/rename/completion/diagnostics/format/save/fallback; получить Windows PASS с сохранёнными source/artifacts и обновить матрицу покрытия без объявления других языков проверенными.

## 2. Интеграция и история

- [ ] 2.1 На уже работающем engine явно подготовить Ubuntu image, последовательно проверить те же Go language E2E, Go tests и editor smoke; сохранить build/runtime logs. Пока engine недоступен, задача остаётся незавершённой.
- [x] 2.2 Проверить Windows Go tests/editor smoke, unit/trace и strict validate; дописать FIXLOG/HISTORY/команды/roadmap с точными результатами и Mac/Ubuntu ограничениями, локально закоммитить выполненное. Не закрывать IDE-047/048 посторонним PASS.

Windows 6 UI PASS, Go tests 5 + smoke 10, unit/trace 364 checks. IDE-050
обнаружен и исправлен отдельной delta fix-lsp-format-fallback (§110).
Ubuntu engine недоступен; 2.1 не выполнена, change не завершён/не архивирован.
