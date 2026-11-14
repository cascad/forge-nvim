# Proposal

## Why

IDE-138: владелец потребовал полную установку одной командой на Windows,
Linux/macOS с Default/Custom. Первый отдельный шаг — доставить source и
вызвать платформенную установку без заранее установленного Git. Сейчас
Windows/Linux clone кладёт монорепозиторий в config directory; готового
общего entry point нет. IDE-BOOT-8 описывает именно transport/dispatch,
а не ещё не реализованный полный Default.

## What Changes

- Root install.ps1/install.sh получают архив source и запускают installer
  из nvim_forge/scripts в local-source режиме; languages включены по умолчанию.
- Source хранится по SHA256 архива, повтор не плодит одинаковые деревья;
  незавершённая загрузка не становится installed source.
- Состав Default/Custom и фактические gaps фиксируются в документации.
- Permanent E2E с localhost HTTP, настоящими downloads/extraction/shells,
  private destination и fixture platform backend; native package install
  не подменяется такой проверкой и остаётся следующим этапом.

## Capabilities

### New Capabilities

- `installer-bootstrap`: получение source и передача платформенному installer.

### Modified Capabilities

Нет; существующие platform install contracts не переписываются этим шагом.

## Impact

Новые root entry points, isolated installer transport E2E, docs/roadmap/history.
Не меняет daily IDE startup, SDK, pins/backports или host package managers.
Ollama/модели исключены. Полный Default/Custom остаётся отдельной очередью IDE-138.
