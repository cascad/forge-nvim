# Proposal

## Why

IDE-138 / IDE-BOOT-29: actual Core101-position report содержит два gaps при готовых инструментах. collect_mason ошибочно берёт install_options.version (у LuaLS null), хотя Mason читает version из installed PURL; StyLua v2.6.0 release ZIP не содержит license document. Native workflows §260–261 пройдены, следующему publisher шагу нужны достоверные metadata/notices.

## What Changes

- Читать installed name/source/version/links штатным read-only Mason receipt API, сохраняя requested options отдельно от факта установки.
- Явный --fetch-tool-licenses получает отсутствующий документ только из GitHub source/revision установленного пакета. По умолчанию сеть выключена.
- Тот же --license-cache переиспользует source/version-bound Mason documents с SHA checks, сохраняя вложенные имена и input directories.
- Сформировать actual Windows Core report без этих двух gaps; добавить native CLI regressions Windows/Ubuntu и историю.

## Capabilities

### New Capabilities

- `core-tool-notices`: IDE-BOOT-32, native receipt versions и проверяемые source-bound tool notices.

### Modified Capabilities

Нет; baseline phase1 и IDE-BOOT-29 не синхронизируются.

## Impact

Только existing publisher inventory/helper/tests/docs. Нет новых LSP/SDK, изменений installed tools/receipts/lock или ложного full-release verdict. Transitive/native acceptance отдельно.
