# Proposal

## Why

IDE-138 должен устанавливать готовый комплект, не обновляя и не подменяя уже установленный Neovim, его конфигурацию или системные SDK. Сейчас source entry направляет установку в обычный каталог nvim и вызывает глобальные package managers. Это противоречит уточнению владельца от 2026-11-14; нужен IDE-BOOT-11.

## What Changes

- **BREAKING**: source entry устанавливает отдельный комплект, а не замену обычного nvim. InstallPath/--install-dir обозначает корень комплекта.
- Собственные config/data/state/cache/runtime и команда forge; изменения окружения ограничены дочерним процессом.
- Подготовленный runtime копируется в комплект; системные WinGet/apt/Homebrew, PATH, профили shell и конфиг WezTerm не меняются.
- Занятый чужими данными целевой путь отклоняется до записи. Повторная установка сохраняет пользовательские данные Forge и предыдущую конфигурацию.
- Отсутствующий подготовленный runtime — явная ошибка, без fallback на системный nvim или глобальную установку. Доставка полного Default остаётся gate IDE-138, пока нет проверенных release artifacts.

## Capabilities

### New Capabilities

- `installer-isolation`: независимая установка, запуск и проверяемая граница владения файлами.

### Modified Capabilities

Нет; прежние direct platform scripts остаются legacy advanced API, source entry больше их не вызывает.

## Impact

Корневые install.ps1/install.sh, общий native Neovim installer, независимые launchers, runtime packager, isolated E2E и документы IDE-138. Lock/payloads/языковые политики не меняются. macOS проверяется владельцем отдельно.
