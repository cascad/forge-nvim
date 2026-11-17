# Verification — 2026-11-17

IDE-BOOT-38: Windows и Ubuntu по2 новых E2E +5 controls PASS, целевые запуски.
Native Mac не запускался; полный Default/installer/setup согласование отдельно.

## Поведение

Space l S / ForgeSdk содержит Python/Node. Общий native select/input flow
использует новый provider к существующим Python/Node resolvers; хранение
в прежнем tools.json. Атомарный scoped set/reset сохраняет остальные tools и
metadata, corrupt JSON не затирается. Reset project наследует user/legacy/native.
Python venv symlink остаётся interpreter venv, без fs_realpath к base Python.
Version probes только при явном menu/manual/refresh:3s, максимум2 параллельно,
Python -I -B / Node --version. Startup provider не загружает и CLI не вызывает.
SDK установки, globals/PATH/homes не меняются. Existing project SDK workflows
переиспользуются; active tasks/debug/tests/terminal guard и native session restart
общие. Сохранение само по себе не перезапускает работающий LSP.

## Результаты

Raw logs в `.tests/toolchain-research/`:

| Case | Windows | Ubuntu |
|---|---|---|
| Common menu1 | python-node-picker-menu-final-windows.txt | python-node-picker-menu-ubuntu.txt |
| Native TUI1 | python-node-picker-windows.txt (native case PASS) | python-node-picker-ubuntu.txt (native case PASS) |
| Existing paths4 | python-node-picker-path-controls-windows.txt | python-node-picker-path-controls-ubuntu.txt |
| Go/Rust menu1 | python-node-picker-go-rust-control-windows.txt | python-node-picker-go-rust-control-ubuntu.txt |

Native artifacts: `.tests/editor-e2e/45788074657400` и
`.tests/ubuntu/editor-e2e/16815766784020`. Menu artifacts:45881015498700 /
16859992086016. Native session:3 process instances, two apply/restart, first.txt
23,7 восстановлен, Python sys.prefix/executable внутри venv с пробелами,
NodeRunFile фактический native image/version, SDK env unchanged, installs0,
Overseer task запрещает apply без потери PID. Strict native shutdown:exit0/
signal0/no hardkill/scope not terminated/active_after0.

Menu: общий language/scope вход, discovered active venv, native prefix,
project reset→user, user reset→active venv, manual Node root с пробелами,
настоящий --version, сохранение user/project metadata/других keys,
cancel/invalid path/corrupt JSON, startup без Python/Node probes.
Controls проверяют прежние user/project/legacy priority, native venv/Node/Bash
процессы, settings refresh/project isolation/invalid/no fallback и Go/Rust UI
с guard active task. Full regression не запускался.

## Первичные отказы

Initial common menu test ожидал discovery произвольно названной venv, не
настроенной как active и не являющейся стандартной .venv. Fixture обозначила её
как VIRTUAL_ENV, matching существующего resolver; native TUI case уже проходил.
Windows retry сам менял slash spelling VIRTUAL_ENV перед сравнением env; лишнее
присваивание убрано. Product code после initial run не менялся. Повторялись
только failed menu cases; результаты native процессов не подменялись.

## Среда и финальная проверка

Только существующие native Python/Node deps; новые SDK/tools не скачивались.
Ubuntu existing offline image, source RO/private prepared plugins; Docker
Desktop/WSL/image/build/pull не трогались. Host tmp/cache на F. Private venv
создана --without-pip; derived venv исключена из source snapshot, фактический
prefix/executable сохранён в JSON. Только принадлежащие стенду scopes очищены.

Перед local commit: OpenSpec strict, diff/staged checks, frozen25/WIP/native
SDK/locks, raw/staged append-only journal prefixes и exact owned index.
Registry включает только собственную новую строку, прежние WIP вне коммита.
