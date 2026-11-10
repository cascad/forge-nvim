# Proposal

## Why

IDE-087: два Docker stop event совпадают с Windows E2E, но caller не записан. Pinned Neovim proc.c обходит потомков по одному PPID без creation times. Нужна проверка механизма до изменения SDK: source review и код 15 не доказывают причину остановки Docker.

## What Changes

- Read-only Windows ancestry audit: native Toolhelp/GetProcessTimes, JSON, никаких signal/terminate API.
- Native C harness с точным pinned proc.c fragment и собственными worker/root/child под Job Object; контролируемый snapshot содержит один stale edge. Положительный сценарий сохраняет настоящую parent-child связь.
- Сравнение upstream fragment с ограниченным guard prototype в частном build, source SHA и reports; установленный SDK не меняется.
- Журнал и primary links с явным разделением conditional proof, полного Neovim E2E и Docker attribution.

## Capabilities

### New Capabilities

Нет, skip_specs=true: тестовый инструментарий и диагностический prototype.

### Modified Capabilities

Нет. Нет изменений production runtime/SDK/lock или main specs.

## Impact

tests/diagnostics, отдельный native harness/build script и docs. Windows ABI только в Windows probe; Linux/macOS этот SDK не используют. Рабочие процессы, Desktop/WSL и настройки системы не меняются. Все build/temp на F:.
