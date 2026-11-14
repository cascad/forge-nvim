## Why

IDE-139: setup-stage завершает работу после команды без проверки результата. Mason считает каталог пакета installed даже без receipt/bin, parser task может завершиться с missing parser. Установка не должна сообщать успех в таком состоянии.

## What Changes

- Общие существующие Mason/parser catalogs используются настройками и явной postcondition проверкой, без изменения состава.
- Tools stage проверяет native Mason package/receipt/declared bin files; parsers stage проверяет наличие и native загрузку selected parsers.
- Нарушение даёт nonzero с конкретным именем и причиной, последующие stages не запускаются; startup не запускает checks/install.
- Native регресс с реальным Mason и parser loader, Source RED и актуальные Windows/Ubuntu проверки; история/команды.

## Capabilities

### New Capabilities

- `setup-readiness`: IDE-BOOT-15, проверка фактического результата явного setup.

### Modified Capabilities

Нет; IDE-BOOT-9 exception propagation сохраняется. Состав SDK/LSP и legacy macos-install API не меняются.

## Impact

setup-stage, общие каталоги, lsp/treesitter конфиг только через общий источник, native readiness stand и прежний orchestration fixture. Не вводится download/provider/компилятор или исполнение произвольного --version для каждого адаптера. Полная функциональная матрица языков и release inventory остаются отдельными проверками.
