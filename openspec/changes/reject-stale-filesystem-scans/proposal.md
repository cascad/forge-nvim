# Proposal

## Why

IDE-104 нарушает намерение IDE-FILE-1: после native a созданный файл может
исчезнуть из раскрытого Files. Pinned fs_scan.lua render_context без проверки
актуальности принимает старый full-root scan после нового; управляемый порядок
настоящих IO воспроизвёл expanded=true/loaded=false/no-child Windows/Ubuntu.

## What Changes

- IDE-FILE-5: более старое сканирование не заменяет уже показанный актуальный
  результат создания файла; async/follow/watchers и клавиатурный workflow остаются.
- Постоянный native regression с задержкой одного настоящего root IO ответа,
  source RED→PASS Windows/Ubuntu и controls независимых partial folder loads.
- Предпочесть исправление upstream; при отсутствии готового — только узкий
  source-locked guard через existing backport mechanism, без собственного
  scanner/renderer/controller. Не принимать ручной R/extra toggle как fix.
- Документы/история/команды различают доказанный механизм и два исторических
  untraced отказа. Native Mac/physical GUI — отдельный реальный gate.

## Capabilities

### New Capabilities

- `file-explorer-ordering`: IDE-FILE-5, порядок завершения scan и сохранение
  актуального дерева. Main inventory пока содержит только WezTerm/macOS install;
  связанные IDE-FILE-1/2 — в integrate-file-explorer,3/4 — в protect-unsaved-files-in-explorer.

### Modified Capabilities

Нет: main baseline Neovim пока отсутствует; существующие delta не переписываются.

## Impact

Neo-tree filesystem scan completion, existing dependency backport/preparation,
native E2E/registry и test-only IO ordering helper. §180: два native source
файла через existing applier, SDK binaries/pins прежние. §181 ограничивает normal
coherence retry: native query/explicit restore не смешиваются с normal view
(IDE-105, два дополнительных source RED и permanent filter/clear cases).
Reproducer в tests/diagnostics;
FIXLOG §178 содержит evidence и границы. Это не новый filesystem backend,
не отказ от async и не пересборка всех файловых действий.
