# Design

## Context

Mason/provider boundaries, принятые Bash/SQL patches и native SQLLogicTest runner уже существуют. Runtime parts transport умеет platform/SHA/manifests/probes. Windows codelldb исключён историческим guard; SQL currently зависит от Go только ради сборки tool, Rust helper не входит в доставку.

## Goals / Non-Goals

**Goals:** четыре уже принятых debug/test tools без ручной подготовки после install; понятные failure/repeat/version boundaries, реальные native consumers.

**Non-Goals:** новый LSP/adapter/provider, новый SDK manager, установка WSL/Docker/SDK, полный Core/Terminal release catalog или Mac PASS без native запуска.

## Decisions

- Pinned Mason codelldb v1.12.2 на всех целевых ОС; использовать bundle и native DAP handshake/launch, сохраняя существующие explicit/PATH choices. Bash pin — текущий registry release tag untagged-438733f35feb8659d939 (adapter0.3.9). SDK/DLL не заимствуются из чужого Python.
- Выделить строгий API existing Bash patch engine: setup выбирает только штатный Mason path, interactive command сохраняет старый warn UX. Hash/atomic replacement/repeat logic общие; никакой записи на startup.
- Native SQL part содержит sql/bin/sqls и forge-sqltest, metadata и обычный component manifest. Publisher wrapper над package-runtime.py принимает уже проверенные native build manifests, сверяет source/patch/version/binary hashes. Не переносить build из tests в пользовательский installer.
- SQL больше не требует Go SDK и stock Mason sqls в managed component list; sqruff остаётся Mason. Новая IDE-only FRIDE_RUNTIME указывает active staged/installed runtime. Native SQL lookup предпочитает принадлежащие kit tools перед старым Mason copy; explicit overrides остаются первыми. SQL readiness проверяет именно доставленные binaries.
- Native version policy двух SQL tools хранится в config asset; publisher сверяет её с existing SDK metadata/Cargo version. Build SDK нужны publisher, не end-user.

## Risks / Trade-offs

- Codelldb payload/DLL closure проверяется реальным DAP, не одним --version/receipt. Native Mac отдельно у владельца.
- SQL artifacts пока собираются локально; production catalog/публикация остаются следующими этапами. Linux ABI принимается на Ubuntu stand, другие версии дистрибутивов не объявляются PASS.
- WSL2 backend для Windows Bash выбран владельцем ранее; setup его не запускает и не устанавливает. Работоспособность backend требует отдельного native окружения.
