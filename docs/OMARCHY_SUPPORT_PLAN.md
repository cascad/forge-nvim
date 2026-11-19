# IDE-143 — Omarchy

Статус: запланировано владельцем 2026-11-19; установка и acceptance этой среды
ещё не реализованы/не пройдены. Этап следует после текущего IDE-142 и закрытия
Ubuntu cold installation. Windows, Ubuntu и macOS остаются в матрице; Mint пока
не добавляем.

Omarchy использует Arch/OPR packages через pacman и уже содержит собственные
Neovim/терминалы и управление языковыми версиями. Опираемся на
[официальный сайт](https://omarchy.org/) и
[upstream installer пакетов](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-pkg-install).
Конкретную версию/архитектуру фиксируем в отчёте стенда, а не в своей матрице SDK.

- [ ] Определять Arch/Omarchy по native release metadata и менеджеру. APT provider
  остаётся Debian/Ubuntu; отсутствие pacman support объясняется явно.
- [ ] Добавить provider системных зависимостей через pacman, с reuse существующих
  пакетов и соблюдением штатной политики rolling release. Не делать partial
  upgrade/отдельное обновление базы пакетов ради fride; изменения показывать до
  выполнения. AUR/helper не требовать для базовой установки.
- [ ] Проверить общий однострочный bootstrap, Default/Custom/пользовательский путь,
  создание отсутствующего каталога, upgrade/repeat/отмену. Neovim/config/data
  Omarchy сохраняются; fride использует свой NVIM_APPNAME и private IDE payload.
- [ ] Проверить SDK из PATH и штатного менеджера версий Omarchy, user/project
  paths и ручной выбор; SDK не ставятся до выбора языка. Не заменять существующие
  Go/Rust/Node/Python или системные defaults.
- [ ] Прогнать общие CLI/editor/installer E2E в подготовленном Arch-контейнере;
  зафиксировать image digest, packages, tool versions, source и отчёты.
- [ ] Поднять настоящую Omarchy VM либо прогнать на машине владельца: WezTerm,
  Wayland/Hyprland, GPU/font/clipboard, русская раскладка, hotkeys/panels и
  отзывчивость. Контейнер этого не доказывает. Desktop defaults не менять.
- [ ] Проверить смешанный проект, восстановление вкладок/дерева/панелей,
  LSP/navigation/format, run/debug/output/tests, git diff/stage/commit и смену
  проекта. Сеть/push проверять только в своём test remote.
- [ ] Дать простые команды установки/подготовки/прогона с отчётами; описать
  восстановление/удаление fride. Внести FIXLOG/HISTORY и платформенный статус.

Общие существующие команды для подготовленной Linux-среды:

```bash
bash scripts/test.sh quick
bash scripts/test.sh e2e
bash scripts/test.sh regression
```

Они требуют подготовленных зависимостей стенда; это не текущий Omarchy PASS.
Отдельную команду создания/подготовки Omarchy стенда добавляем в ходе этого этапа.
Полный regression выполняем после цельной реализации, затем только affected
повторы. Нужные регрессионные случаи добавляем вместе с изменениями providers.
