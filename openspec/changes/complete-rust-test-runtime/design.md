# Design

## Context

См. §288 verification. SDK остаются общими; IDE packages — Mason. Nextest —
обычная утилита Rust в CARGO_HOME/bin по решению владельца.

## Decisions

Отдельный Rust tools preflight после SDK, через verified Core/shared Lua и
native bounded version probe. Не добавлять nextest в список language SDK.
Меню существующих prerequisites используется для выбора каталога, install,
skip Rust, refresh/cancel. Официальные get.nexte.st sh/PowerShell scripts
проверяют SHA binary и устанавливают в обычный Cargo home; сначала проверяется
существующий tool/целевой файл, готовая версия сохраняется. Нет молчаливой
переустановки повреждённого/чужого файла. Headless missing — nonzero с причиной,
SDK actions без TTY остаются прежними. Постусловие private setup тоже проверяет
nextest при выбранных Rust tools до publication.

Runtime resolver: explicit tools.json, затем PATH/обычный Cargo bin. Native
RunSpec cargo nextest получает выбранный executable напрямую; cargo SDK для
build/metadata прежний. DAP strategy не требует nextest для native Cargo build.
Opening file не читает registry, не устанавливает tools и не вызывает version probe.

Native build_spec=nil запускает fallback по descendants, а не отменяет Run.
Missing prerequisite поэтому проверяется существующим Forge consumer до вызова
публичного run/run_last API и Run all. Сам native выбор/augmentation/results
и хранение last-run сохраняются; private fields/API не используются. Пустая
strategy/фиктивные команды/подмена результата для отмены не создаются.

Root-file backport выбирает реальные discovered IDs и нужный Cargo target для
main/lib, вместо предположения об обязательном tests::. Старый after hash
добавляется в previous; upgrade/revert/unknown-content guards сохраняются.

## Risks / Trade-offs

Official installer заменяет existing target → общий preflight/action перед ним
сохраняет любую рабочую версию и отказывает при conflict. Shared Cargo home
тестируется только в собственных stands, не в домашнем SDK пользователя.
Rust root filter → native main/lib root+nested tests, соседний failing target,
nearest/integration/DAP controls и actual nextest, без подмены результатов.

## Non-Goals

Замена adapter, private API overrides, cargo test fallback, SDK upgrade,
распространение собственных nextest packages, GUI/Mac/WSL/public release.
