## Why

IDE-010/011: владелец требует универсальное ядро и e2e каждой фичи/бага.
Нужны простые команды: Windows native, Ubuntu в Docker на Windows,
macOS отдельно. Mint временно отложен. Существующие unit не доказывают
доставку клавиш/GUI и не покрывают сценарии новой IDE.

## What Changes

- Добавляем suite e2e в существующий runner и обёртки quick/e2e/full.
- Ubuntu-контейнер: pinned base/Neovim, readonly чекаут, отдельные результаты,
  unprivileged runtime, отсутствие сети во время тестов.
- CLI e2e обёрток фиксирует найденный дефект PowerShell scalar-splat:
  `unit` передавался как отдельные `u`, `n`, `i`, `t`.
- Базовый editor e2e запускает сборку с 66 pinned плагинами и настоящим RPC UI:
  редактирование/сохранение, дерево, имя/содержимое, буферы, фокус, ошибки.
  Подготовка зависимостей явная; профиль и проект приватные, артефакты в .tests.
- Правила e2e, архитектурные границы и честная матрица долга — в документации
  и CLAUDE.md. Подход cs2d сверяем после получения пути.

## Capabilities

### New Capabilities

Нет изменений повседневного IDE. `skip_specs: true`: инфраструктура тестов,
команды разработки и документация.

### Modified Capabilities

Нет. Runtime-перенос системных деталей и новые пользовательские фичи IDE
оформляются отдельно с e2e по новым правилам.

## Impact

tests/run.lua, tests/registry.lua, scripts/test.*, tests/containers,
CLI/editor e2e, RPC-клиент и явный preparer плагинов. Документация, план,
инбокс, FIXLOG. Найденные runtime-дефекты оформлены отдельно в
make-editor-startup-passive (IDE-BOOT-1/2).
