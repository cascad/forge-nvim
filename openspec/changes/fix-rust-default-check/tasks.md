# Tasks

## 1. Native compiler diagnostics

- [x] 1.1 Permanent IDE-RUST-1 добавлен; frozen a9758ed Windows/Ubuntu source
  отказал на native missing Clippy, actual logs/argv/test/native exit сохранены.
- [x] 1.2 Check без --no-deps: Windows/Ubuntu target1 + прежний completion/
  diagnostics control1 PASS, по3 native profiles exit0/signal0/scopes empty.
- [x] 1.3 FIXLOG223 со Спека: IDE-RUST-1 (ADDED), docs/roadmap/PROBLEMS/HISTORY/
  commands; strict/diff/frozen/prefix guards и isolated commit готового среза.

## 2. Платформы

- [ ] 2.1 macOS native проверка на предоставленной машине: тот же command/case,
  отсутствие результата не обозначать PASS. Ubuntu завершён в1.1/1.2.

Итого3/4, native Mac открыт. Full regression, IDE-130/133, project warmup и
Files latency этим срезом не закрыты. Native source/target разных ОС не
подменяют друг друга; SDK/pins/backports прежние.
