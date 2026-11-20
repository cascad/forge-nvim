# Design

## Context

См. proposal. Runtime/Core/Terminal packagers уже выполняют native probes и
создают manifest/files SHA; fride-setup умеет explicit runtime path. Они остаются
владельцами установки. Local acceptance package — вход этой существующей цепочки.

## Goals / Non-Goals

Goals: передаваемый native комплект с исходниками текущей сборки и штатным UI;
не требовать Python/Cargo/компилятор при его установке. Publisher использует
готовые native inputs; официальная поставка POSIX Neovim доступна отдельной
явной командой. Источники и версия frontend проверяются при упаковке.
Non-Goals: публикация на GitHub, новый runtime format/package manager,
пересборка Windows Neovim, изменение обычных SDK/config, Omarchy и GUI acceptance.

## Decisions

- Подготовка Neovim использует pinned upstream tar.gz и SHA из официального
  expanded_assets/v0.12.2; Linux/macOS имеют разные assets. Native version probe
  обязателен; Windows продолжает использовать существующий patched SDK.
- Пакет собирается из существующих Core/Terminal archives. Их manifest и
  полные files SHA проверяются до сборки. Компоненты объединяются в уже
  поддерживаемый monolithic explicit runtime; никаких HTTP servers для local
  install. Public modular transport не меняется.
- Источники берутся только из tracked nvim_forge/scripts/wezterm, без .tests,
  .tools, Git metadata и private notes. Упаковка не меняет checkout.
- Native frontend receipt обязан соответствовать текущим исходникам.
- Решение владельца: Core содержит publisher-built fzf-native для каждой ОС.
  Existing prepare_fzf/manifest фиксируют pin/source/SHA; Core packaging проверяет
  native ABI. Явный plugin setup копирует library, не запускает compiler/CMake.
  При отсутствии Core library сохраняется обычный Telescope Lua fallback.
- В комплекте PowerShell/Bash entrypoints, manifest и native frontend. Проверка
  files SHA выполняется до запуска UI; параметры идут прямо в штатный frontend.
  Default/deferred SDK/Custom/settings/isolation и rollback принадлежат ему.
- Publisher deps требуются только автору пакета. Local package не называется
  публичным one-line bootstrap; это следующий release gate после приёмки.

## Risks / Trade-offs

Stale/foreign inputs → platform/manifest/SHA/source receipt checks.
Лишние private files → явный tracked allowlist. Частичная сборка → новый
output через staging, existing output не перезаписывается. Native Mac нельзя
подтвердить на Windows → отдельная команда publisher и честный native gate.
Monolithic acceptance runtime содержит выбранный publisher Terminal; private
backend фильтрует его files/probes/paths при Custom без Terminal. Копируются
только выбранные manifest files; публичная модульная доставка остаётся прежней.
