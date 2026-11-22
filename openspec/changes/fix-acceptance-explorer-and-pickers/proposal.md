## Why

Приёмка Windows 2026-11-22: созданные/скопированные файлы временно отсутствуют
в Files, перемещённый остаётся с красным крестом; поднявшись выше проекта,
непонятно как вернуть корень. Ctrl+J/K в палитре накапливают отступ.
Владелец просит быстрый buffer picker, поиск хоткеев и reveal без сброса соседей.
IDE-FILE-8/8 и IDE-PANEL-31 фиксируют ожидаемое поведение. В текущем
Telescope selection_caret=' ' является префиксом entry_prefix='  '.
Живое read-only наблюдение подтвердило filesystem source и существование
кириллического файла в позднем render; точная причина задержки ещё не доказана.

## What Changes

- Files показывает текущее содержимое диска; Git decorations остаются в Git.
- Возврат к рабочей папке без смены проекта, reveal сохраняет соседние ветви.
- Поиск реальных keymaps и buffer picker получают быстрые вызовы.
- Различимые штатные префиксы Telescope предотвращают рост отступов.
- Native UI regression с Unicode, tracked/untracked файлами и реальным вводом.

## Capabilities

### New Capabilities

- `ide-acceptance-navigation`: актуальность Files, root/reveal и searchable keys.

### Modified Capabilities

Нет: IDE baseline пока не перенесён в main specs; новые контракты — delta.

## Impact

Neo-tree/Telescope configuration и native E2E, руководство/история приёмки.
Пины, SDK, платформенные менеджеры, установщик и WezTerm не меняются.
