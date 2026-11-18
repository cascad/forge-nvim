# Proposal

## Why

При настоящем Default из архива repo entrypoint выбрал старый .tools frontend
до чтения catalog выбранного source. Его checksum корректен, но code старый:
выбранные user Go/Node SDK были проигнорированы. Native proof сохранён в
.tests/toolchain-research/default-windows-integration.txt и install-default.json
отдельного owned stand. IDE-BOOT-13 не должен смешивать frontend другой версии
с выбранным source. Explicit developer override остаётся допустимым.

## What Changes

- Source catalog определяет frontend digest. Checkout/cache переиспользуется
  только при совпадении с этим digest, иначе загружается указанный artifact.
- Отсутствующий published artifact не разрешает неявный старый .tools fallback.
  Для неопубликованной developer сборки есть прежний explicit UI path.
- Native PowerShell/Bash resolver и root SDK regression, документация.

## Capabilities

### New Capabilities

- `source-bound-installer-ui`: IDE-BOOT-46.

## Impact

Два shell resolver, native tests/root helper/guides. Без нового manifest parser,
dependency или формата artifact. Нормальный опубликованный one-liner автоматический.
