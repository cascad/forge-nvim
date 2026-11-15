# Design

## Context

tool_catalog/filter и components.tsv уже задают общий список для Mason и readiness. Mason Go installer задаёт только GOBIN каталогу tool package, сохраняя обычные GOPATH/GOROOT/caches. Node consumer уже ищет project → shared → Mason Prettier JS entrypoint без .cmd в argv.

## Goals / Non-Goals

**Goals:** закрыть пять обнаруженных tool gaps, закрепить версии, проверить postconditions и настоящие LSP/formatter consumers.

**Non-Goals:** новые LSP, новый installer/provider, SDK capsules/global installs, Windows codelldb/Bash/SQL/Terminal delivery, полный release catalog или объявление native Mac PASS.

## Decisions

- Использовать существующий Mason. Версии: gopls v0.23.0, gofumpt v0.12.0, golines v0.16.0, stylua v2.6.0, prettier3.9.10; проверены official registry и go.mod. Go tools source build требует Go1.26.0, это обычный SDK пользователя. Перед необходимой сборкой explicit setup проверяет Go version, GOTOOLCHAIN=local не допускает скрытой загрузки SDK. Правильные готовые packages переиспользуются без build-SDK requirement; full SDK compatibility selection в native TUI не заявляется реализованным.
- tool_catalog.mason() сохраняет names API; отдельные install specs добавляют version для пяти packages. Тот же map используется readiness. Иные packages и provider boundaries не меняются.
- stylua входит в Core и получает native release binary, без обязательного Rust SDK. Prettier принадлежит Node, checkbox label явно включает shared JSON/YAML/Markdown formatting. Core-only не зависит от Node; отдельная новая галочка не вводится.
- Проверять pinned receipt version и именно нужный bin alias; для Prettier проверять Mason JS file независимо от project copy. Настоящие consumers проверяются отдельным native editor scenario, без подмены реализации formatter/LSP.
- Controlled native registry cases покрывают failure/partial/repeat; actual tool smoke выполняется в отдельном test stand с подготовленными SDK, cache/tmp на F. Native Linux без сети использует готовые inputs; Mac команда подготавливается владельцу.

## Risks / Trade-offs

- Source build новых Go tools требует Go1.26.0: обычный SDK probe --version не равен всей build compatibility. Это явный failure boundary, не скрытое обновление SDK.
- Mason registry и зависимости не полностью frozen этим change; только пять versions. Full release/source/hash/license inventory остаётся отдельным этапом.
- После явного обновления этих пяти tools на другую версию managed setup восстанавливает declared pin; другие user SDK/toolchain versions не меняются.
