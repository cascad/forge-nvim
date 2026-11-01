# Proposal

## Why

IDE-027 нарушает стабильность уже описанных IDE-BUF-1 сценариев: Windows Neovim завершается с 0xC0000005 при native terminal и возврате фокуса. IDE-031 — единичный timeout отдельного PowerShell CLI процесса; до продолжения roadmap нужны воспроизводимые данные, а не увеличение timeout или повтор до зелёного.

## What Changes

- Сохранить native red, минимальный чистый Neovim repro и точное место сбоя; сравнить исходную конфигурацию/версию и альтернативы без изменения установленной IDE.
- Проверить локальное исправление upstream ConPTY lifecycle в изолированной сборке на F:; после выбора владельца подключить временный SDK к Windows launcher/test entrypoint с явной подготовкой и проверкой происхождения.
- Вынести воспроизводимый probe и команды в репозиторий; исследовать CLI timeout с неизменённым deadline и сохраняемыми артефактами.
- Исправить найденную в full изоляцию ConPTY набора: private профиль и pinned plugins, выбранный SDK; source lock не должен меняться от теста.
- Записать проверенные факты/отвергнутые гипотезы, ограничения и дальнейший маршрут в FIXLOG/HISTORY/PROBLEMS/ROADMAP.

## Capabilities

### New Capabilities

- `editor-sdk`: IDE-BOOT-3 — выбранный владельцем временный SDK Windows, явная подготовка, проверяемое происхождение, launcher/test entrypoint без фоновой установки.

### Modified Capabilities

Общая конфигурация и хоткеи не меняются. После reviewable A/B владелец выбрал временный SDK Windows; это решение добавлено в текущий change, а не считается незаметным обновлением установленного Neovim.

## Impact

tests/diagnostics, scripts/prepare-windows-sdk.ps1, Windows launcher/test entrypoint, команды и история; SDK в игнорируемой .tools, build/temp в .tests на диске checkout. Установленные Windows программы и main specs сохраняются. Linux/macOS используют официальный Neovim. Mac/GUI не объявляются проверенными. Исходные тесты и их сроки ожидания не ослабляются.
