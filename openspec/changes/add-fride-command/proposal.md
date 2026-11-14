# Proposal

## Why

Владелец выбрал fride (Forge IDE), IDE-141/§238. Сейчас отдельный комплект создаёт только bin/forge, а запуск из checkout называется nvim_forge; выбранной команды нет. Нужен IDE-BOOT-12 с сохранением изоляции IDE-BOOT-11.

## What Changes

- Комплект создаёт основные launchers fride и полное имя forge-nvim; прежний forge сохраняется.
- Checkout получает fride/fride.cmd/fride.ps1 через существующие launch helpers без нового SDK resolver.
- Явные -CommandDir/--command-dir позволяют разместить fride в выбранном bin каталоге. PATH/registry/shell profiles не изменяются.
- Чужие одноимённые команды/файлы не заменяются. Регистрация имеет receipt владения; повтор не перезаписывает пользовательские правки.
- Native E2E проверяют args/cwd/exit/stdin/окружение, aliases, регистрацию/повтор/конфликт и отсутствие изменений у чужого редактора.

## Capabilities

### New Capabilities

- `launcher-command`: постоянная fride, совместимость имён и явная безопасная регистрация.

### Modified Capabilities

Нет. Поведение global PATH и штатного nvim сохраняется.

## Impact

Private installer/launchers, root entry flags и checkout wrappers, существующий isolated stand и документы IDE-141. UI LocalVox и полная доставка Default SDK — следующие части IDE-138, не подменяются переименованием.
