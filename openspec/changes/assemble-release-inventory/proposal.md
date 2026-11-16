# Proposal

## Why

IDE-138/§250–258 дошли до native Core/Terminal artifacts, но единый проверяемый
source/version/SHA/license inventory отсутствует. Разные prepared manifests и
Mason receipts скрывают точные незакрытые входы перед actual Default/Custom.

## What Changes

- Read-only publisher command сводит действующие components/tool_catalog,
  lazy-lock/backports, native parser site, явные Mason roots и готовые archives.
- Генерирует JSON/читаемый отчёт, exact license copies и notices; отсутствие
  sources/версий/лицензий/компонентов отражается конкретными gaps, strict exit2.
- Никаких SDK/host package probes/установок/изменений pins или source inputs.
- Реальные Windows/Ubuntu inputs и адресные E2E проверяют profile selection,
  corrupt archives, неполную подготовку, notices и сохранность inputs.

## Capabilities

### New Capabilities

- `release-inventory`: наблюдаемый publisher inventory выбранного состава.

### Modified Capabilities

Нет; runtime/установщик этим срезом не меняются.

## Impact

Небольшой publisher inspector и native catalog helper, install E2E/документация.
Выходы предназначены для следующей сборки Default/Custom; наличие отчёта не
означает полного release или проверки всех transitive license obligations.
