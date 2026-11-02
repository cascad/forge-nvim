# Proposal

## Why

IDE-043: неудачный push показывает остаток OSC title с путём Git и BEL.
Наблюдатель 24997056234800 подтвердил повреждение внутри remove_ansi_escape_codes:
полный OSC на входе превращается в видимый хвост. Это засоряет причину ошибки.

## What Changes

- Убирать полный OSC с BEL/ST до обычной очистки CSI, сохраняя видимый текст,
  UTF-8, цветной вывод и обычные пути. Не фильтровать Windows-пути по содержимому.
- Использовать существующую явную pin/SHA подготовку Neogit: добавить util
  companion, сохранить исправление worktree и read-only обычный запуск.
- Проверить настоящий missing-remote stdout и Git hook с OSC на Windows/Ubuntu;
  отдельно матрицу BEL/ST, соседних OSC, цветов, UTF-8 и обычного пути.
- Добавить историю, команды и инструкцию явного обновления существующей установки.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-12, читаемый вывод без OSC metadata. Основного spec
  ещё нет, продолжение unarchived Git capability IDE-GIT-1…11.

### Modified Capabilities

Нет.

## Impact

Временный backport одного дополнительного файла Neogit на прежнем pin,
подготовка/CLI/Lazy E2E, git-errors E2E и документация. В upstream HEAD
697ad3ee86a73cf6b6758b838d7a7d76cf3b9f86 OSC ещё не поддержан; оттуда берётся
также исключение byte 155 из CSI pattern ради UTF-8. Ни обновления всего
плагина, ни runtime monkeypatch, ни Windows-only логики.

Интеграционный прогон также выявил два дефекта организации E2E: общий 30s
для всех SDK CLI сценариев (IDE-045) и поиск файла до готовности Neogit Head
после checkout (IDE-046). Исправляются discovery/отдельным исполнением
существующих SDK сценариев и ожиданием UI; production SDK/Git не меняются,
прежние deadline и исходные FAIL сохраняются. Результаты и причины — отдельные
записи FIXLOG.
