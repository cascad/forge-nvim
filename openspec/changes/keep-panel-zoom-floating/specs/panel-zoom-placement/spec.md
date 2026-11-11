# Spec Delta

## Purpose

Развёрнутая рабочая панель должна сохранять собственную рамку и размещение при открытии помощи, не превращаясь в дополнительный split и не меняя исходную раскладку.

## ADDED Requirements

### Requirement: IDE-PANEL-18 Zoom остаётся floating overlay

Развёрнутая Space w z панель SHALL сохранять floating-размещение и тот же buffer при открытии общей помощи. Docking MUST NOT превращать overlay в обычный split. Исходная панель SHALL оставаться в своём slot; закрытие помощи SHALL возвращать фокус в overlay, а Esc/Space w z SHALL возвращать исходное окно/раскладку. UI действия SHALL сохранять DAP pause, jobs и вывод.
Если backend закрывает исходную панель, overlay SHALL убираться с возвратом в код; явный выбор другой существующей панели SHALL сохранять выбранный пользователем фокус.

Платформы: все.
Проверка: tests/e2e/debug-panels.test.lua (IDE-PANEL-18).

#### Scenario: Помощь поверх paused Locals
- **GIVEN** настоящий Go/Delve остановлен и Locals содержит переменную
- **WHEN** пользователь разворачивает Locals и открывает ?
- **THEN** overlay остаётся floating с тем же buffer, а native split не дублируется
- **AND** q закрывает помощь и возвращает overlay; Esc возвращает исходное окно/geometry с той же паузой и stdout

#### Scenario: Shared buffer и placement
- **WHEN** обычная tool-панель и её zoom показывают один buffer
- **THEN** исключение docking применяется к overlay window, не к buffer и не к исходному slot

#### Scenario: Backend закрывает исходное окно
- **WHEN** backend закрывает source под активным zoom
- **THEN** overlay убран, фокус в коде, DAP pause/stdout сохранены
- **AND** повторное открытие Output возвращает прежние данные
