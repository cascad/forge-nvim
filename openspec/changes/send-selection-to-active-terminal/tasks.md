# Tasks

## 1. Выполнение выделения

- [x] 1.1 Заменить legacy pwsh callback на getregion + native ToggleTerm open/send, Visual Space t e и Ctrl+Enter; split/float/private/dead handling, одна UI ссылка на native instance без нового реестра/state manager. Проверка — Lua syntax/source diff, E2E всей реализации после готовности кода.
- [x] 1.2 Добавить registered native E2E: first actual shell/видимый output, hidden/repeat, несколько и private terminals, exact Unicode/indent/newlines char/line/block/reversed/exclusive, aliases/registers/buffer/cwd/REPL/dead/float. Source legacy RED, затем один affected Windows/Ubuntu packet new suite + terminal-shell; только failed/affected repeats. Native Mac/Omarchy явно не проверены.
- [x] 1.3 FIXLOG297 со строкой Спека: IDE-PANEL-30 ADDED, HISTORY/PROBLEMS/roadmap/PANEL_KEYS/commands205 и verification; strict/change trace/diff/prefix/frozen SDK+pins/backports, cleanup own test containers и local commit. Полный unrelated E2E не повторять.
