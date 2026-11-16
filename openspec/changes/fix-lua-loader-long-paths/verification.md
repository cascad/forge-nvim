# Проверка IDE-BOOT-25

2026-11-16. Native Neovim0.12.2,67 pinned plugins,6 принятых backports; SDK/locks не менялись.

- Windows RED: `.tests/parser-runtime/lua-cache-before-windows-v1.txt`, два полных запуска не достигли ready. Snapshots `.tests/editor-e2e/6474268523600` и `6488626765400` содержат E5113/ENOENT в vim/loader.lua:135 на URI-encoded cache basename.
- После штатного `performance.cache.enabled=false`: `.tests/parser-runtime/lua-cache-after-windows-v3.txt` —2 PASS; Ubuntu `.tests/ubuntu/parser-runtime/lua-cache-after-ubuntu-v3.txt` —2 PASS. Реальная полная конфигурация/67 plugin registrations,35 loaded, require/reload с42→43, настоящее редактирование/сохранение txt, без Mason installs. Encoded basenames359 Windows /323 Ubuntu; стандартный filesystem limit255 реально превышен.
- Lazy UIEnter timings: Windows905.942/805.497ms (`real_cputime=false`, elapsed с начала Lazy); Ubuntu79.709/113.311ms (`real_cputime=true`, process CPU). Метрики разных ОС напрямую не сравниваются, это не общий IDE performance benchmark.
- Affected parser delivery с production policy: Windows1 PASS31.143s; Ubuntu1 PASS11.978s. Fixture читает настоящие options config/lazy.lua и передаёт cache policy настоящему Lazy; отдельного test-only отключения больше нет. Остальные ранее green parser cases не перезапускались.

## Failures и границы

Windows after-v1: в новом oracle ошибочно написано NeoTree вместо Neotree; v2: использован URI API из master вместо vim.uri_encode в pinned0.12.2. Исправлены только эти ошибки теста; raw failures сохранены. Ubuntu v1 остановилась до запуска редактора: image neogit backport старее принятого. Известные backports подготовлены штатным prepare-plugins.lua в disposable копии editor-deps и manifest обновлён; image/host deps не менялись. Ubuntu v2 затем воспроизвела ту же ошибку URI oracle; v3 зелёный.

Product change — штатный общий параметр Lazy, без monkey patch/fork vim.loader или нового cache implementation. Сохранены binary/runtime Neovim и SDK. Обычный nvim не настраивается этим config. Full editor test использует существующий private editor harness, appname nvim_forge; managed parser test отдельно проходит установленный fride launcher. Native Mac не проверен; full Default language/tool readiness и публикация этим не заявляются.
