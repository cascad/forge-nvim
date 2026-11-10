# Design

## Context

Один SQLS forge.1 client обслуживает schema actions и query. References
отсутствуют: настоящий backend дал -32601, gr не открыл quickfix (341aba2, §142).
Native prototype прошёл отдельные unit, но не включён в SDK и не стал editor feature.
Уточнение владельца 2026-11-10: не изобретать LSP/обходы ради полноты; перед
рефакторингом повторить обзор фич. Собственные binder/scope graph/index означали
бы сопровождение private SQLS fork. Этот подход отменён.

## Goals / Non-Goals

**Goals:** готовый поддерживаемый backend, сохранение query/tests/mappings,
оценка семантики и цены поддержки. Перед рефакторингом IDE-080 (FEATURE_REVIEW).
**Non-Goals:** свой LSP/parser/binder/index, большой private fork, фабрикация
capabilities/locations, grep вместо references, удаление фич до обзора.

## Decisions

1. Prototype/tooling удаляются из текущего дерева. Source 341aba2 и SHA snapshot
   незакоммиченных файлов сохраняются; §142 остаётся историческим. Удаление
   прототипа не является реализацией references.
2. SDK остаётся forge.1. gr/Space l r не получают текстовый fallback,
   автоматическую установку или дополнительный сервер.
3. Готовые кандидаты проверяются на одинаковые column names, alias/CTE/derived
   scopes, DML, unsaved/closed files, Unicode, диалекты, ОС и explicit setup.
   Исследование 9 ноября относится к конкретным source snapshots.
4. Без готового кандидата references остаются открытыми; работа продолжает
   feature review/другие пункты. Своё language ядро не запасной вариант.
5. Review отличает пользовательскую ценность, plugin glue, узкий backport и
   свою реализацию чужой подсистемы. Existing backports требуют причины,
   regression, upstream status и условия удаления. Число строк/плагинов
   само по себе не доказывает избыточность.

## Risks / Trade-offs

- Нет semantic references → явное ограничение и открытый IDE-SQL-9.
- Provider flag не доказывает семантику → отрицательные editor E2E.
- Удалить полезное с прототипом → product Lua/SDK/pins не менять, проверить
  прежний SQL UI/SDK, unit/trace/strict.

## Migration Plan

Сохранить SHA snapshot на F:, убрать prototype/его registry entry, вернуть
SQL test helper. Проверить прежние SQL UI/SDK, историю и strict; commit отмены.
Затем IDE-080: обзор фич/слоёв и кандидатов убрать/упростить до runtime изменений.
Не начинать интеграцию references без готового кандидата. Mac/GUI непроверены.
