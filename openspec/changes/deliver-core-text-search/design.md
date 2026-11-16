# Design

## Context

См. proposal.md. package-core-runtime.py уже собирает Neovim/parser site в обычный Core manifest. Runtime paths/probes и hash-checked transport существуют; Telescope уже использует rg/fd из PATH.

## Goals / Non-Goals

Goals: доставленный rg, native поиск штатным Telescope, release asset/license provenance без SDK compilation.

Non-Goals: Git policy/credentials/installation, WezTerm/font, новые pickers/SDK/package manager, полный Default или публикация.

## Decisions

- Пять official15.2.0 native assets закреплены URL/SHA из GitHub release. Для Linux выбирается musl binary, для Windows существующая x64 платформа, для Mac x64/arm64. Непроверенные native platforms не публикуются.
- Publisher preparation принимает archive или явный --download, извлекает только бинарь и COPYING/LICENSE-MIT/UNLICENSE, проверяет native version. Core publisher повторно сверяет binary/licenses с исходным pinned archive; manifest сам по себе не считается доказательством происхождения.
- Core payload `search/bin` добавляется к обычным runtime paths, `search/licenses` и prepared metadata — к files. Generic transport/launcher не меняются. Исторический Python API может собирать parser-only stand; release CLI требует --search, поэтому отсутствие поиска нельзя случайно выдать за готовый release Core.
- Нативная version probe включена в существующий manifest. Поиск выполняют прежние Telescope commands/config, без runtime downloader и фоновой установки.
- E2E проходит настоящий HTTP/UI/install/launcher. Из launcher запускается Native Neovim controller, а он подключает UI к embedded editor с теми же installed env/config. Данные picker и открытый buffer/line проверяются после реального keyboard input. Другие plugins/Mason provisioning контролируются parser fixture, сам Telescope/rg не подменяются.

## Risks / Trade-offs

- Windows/Ubuntu не доказывают Mac → тот же native recipe владельцу, publication gate остаётся.
- Подмена receipt при изменённом binary → сравнение с сохранённым official archive плюс native version probe перед упаковкой.
- Parser-only historical fixtures не являются release → обязательный --search в CLI и явная граница в документации.
