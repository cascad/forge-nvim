# Design

## Context

67 pinned plugins уже имеют license files в prepared editor-deps.33 native parser
libraries содержат revisions; их upstream URLs доступны из locked Treesitter.
Mason packages из явных roots имеют receipts/source IDs/links, но часть packages
не подготовлена, некоторые providers не сохраняют license. Core/SQL/Terminal
archives содержат hash manifests и отдельные prepared metadata. Языковые SDK
остаются внешними; test SDK manifests не являются private runtime inventory.

## Goals / Non-Goals

Goals: единая read-only команда, current catalog без второго списка инструментов,
exact notices и gaps; реальная таблица подготовленности Default/Custom.

Non-Goals: новый package manager/LSP/license scanner, установки SDK/Mason,
изменение runtime/публичного catalog, юридическая оценка licenses, утверждение
полного transitive coverage или full Default/native Mac readiness.

## Decisions

- Native Neovim -u NONE инспектирует current tool_catalog и locked Treesitter;
  language SDK commands/GUI/setup не запускаются. Python сводит результаты.
- Все67 plugin pins перечислены как locked catalog; это явно отличается от
  файлов, реально доставленных archive. Backports сверяются по patched SHA.
- Для каждого selected parser сверяются revision и library SHA; по отдельному
  --fetch-parser-licenses raw license читается из того же pinned GitHub source.
  Default mode сеть не использует; отсутствие docs даёт gap.
- Явные Mason roots: receipt/source/version/entrypoint hashes, находящиеся внутри
  package license documents (включая вложенные), без исполнения package binaries.
  Дублирующиеся разные receipts не выбираются молча. Missing package/license
  остаётся конкретным gap, test tool SDKs/venvs не сканируются.
- Явные archives: archive/manifest/files SHA, platform/components, license documents
  и known prepared metadata; unknown/untracked/missing members считаются ошибкой.
- Outputs: inventory.json, INVENTORY.md, THIRD_PARTY_NOTICES.txt, licenses/.
  Стабильная сортировка, relative paths без user SDK homes; новый output атомарно
  публикуется. Existing output не заменяется. --strict означает metadata gaps,
  отдельный full-release-ready false сохраняет границу acceptance/transitives.

## Risks / Trade-offs

- License filename не доказывает покрытие nested binaries → report scope и
  отдельная remaining queue; нет guessed SPDX/legal выводов.
- Platform prepared inputs различаются → native Windows/Ubuntu report/E2E,
  missing data выводится явно. Mac реализован общими APIs, здесь не проверяется.
- Archive hashes не доказывают функциональность → существующие native consumer
  E2E сохраняются; inventory их не повторяет и не заменяет.
