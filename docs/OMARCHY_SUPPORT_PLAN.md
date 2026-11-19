# IDE-143 — Omarchy

Статус на 2026-11-19: автоматическая CLI часть завершена, native Omarchy ждёт
машины владельца. Native pacman provider добавлен. В чистом Arch
пройдены Default/Terminal/font/startup без SDK, пять Core editor cases,
Custom в отсутствующий путь и repeat с сохранением обычного Neovim, Mise,
plugin pins, receipts и настроек fride. Это CLI checkpoint, не готовность Omarchy.
Текущий frontend9664c9b1/source5daa7574 прошёл новый clean replay: сохранены
67 plugin pins,2 receipts, preferences и обычный Python SDK при Custom/repeat.
Evidence: `.tests/omarchy/final-cold`; подробности — FIXLOG §294–295 и
[отчёт](../openspec/changes/support-omarchy-installation/verification.md).
Windows, Ubuntu и macOS остаются в матрице; Mint пока не добавляем.

SDK provider реализован: на Arch при наличии Mise явная подготовка языка
использует его project versions/options, без изменения config/defaults/trust.
Если язык не настроен — `tool@latest`; уже установленное переиспользуется.
Без Mise остаются прежние upstream Go/rustup и pacman Node/Python. Git и OS
dependencies используют pacman. Read-only SDK probes не скачивают версии.

Ближайшие шаги:

1. Пройти O1-O8 на настоящей Omarchy: Wayland, font, clipboard, клавиши,
   панели и смешанный проект. Пока все native desktop cases непроверены.
2. Зафиксировать замечания владельца и результаты; закрыть native gate после
   фактического прохождения. Общие macOS/delivery gates идут отдельно.

Итоговый affected packet Windows/Ubuntu/Arch выполнен; failed cases закрыты
отдельными повторами. Полный unrelated regression не повторялся. Простая
команда стенда прошла с автоматическим созданием и удалением своих containers.

Исправлен ложный Core acceptance FAIL: проверка читала ERROR всех прошлых
сессий из общего журнала. Теперь проверяет ошибки текущего процесса, сохраняя
историю. Native контроль специально оставляет ERROR прошлого запуска и
проверяет, что он виден в истории и не приписывается новому запуску.

Omarchy использует Arch/OPR packages через pacman и уже содержит собственные
Neovim/терминалы и управление языковыми версиями. Опираемся на
[официальный сайт](https://omarchy.org/) и
[upstream installer пакетов](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-pkg-install).
Конкретную версию/архитектуру фиксируем в отчёте стенда, а не в своей матрице SDK.

- [x] Определять Arch/Omarchy по native release metadata; foreign manager в PATH
  не меняет provider. APT остаётся Debian/Ubuntu.
- [x] Добавить provider системных зависимостей через pacman, с reuse существующих
  пакетов и соблюдением штатной политики rolling release. Не делать partial
  upgrade/отдельное обновление базы пакетов ради fride; изменения показывать до
  выполнения. AUR/helper не требовать для базовой установки.
- [x] Проверить общий однострочный bootstrap, Default/Custom/пользовательский путь,
  создание отсутствующего каталога, upgrade/repeat/отмену. Neovim/config/data
  Omarchy сохраняются; fride использует свой NVIM_APPNAME и private IDE payload.
- [x] Проверить SDK из PATH и штатного менеджера версий Omarchy, user/project
  paths и ручной выбор; SDK не ставятся до выбора языка. Не заменять существующие
  Go/Rust/Node/Python или системные defaults.
- [x] Прогнать общие CLI/editor/installer E2E в подготовленном Arch-контейнере;
  зафиксировать image digest, packages, tool versions, source и отчёты.
- [ ] Поднять настоящую Omarchy VM либо прогнать на машине владельца: WezTerm,
  Wayland/Hyprland, GPU/font/clipboard, русская раскладка, hotkeys/panels и
  отзывчивость. Контейнер этого не доказывает. Desktop defaults не менять.
- [ ] Проверить смешанный проект, восстановление вкладок/дерева/панелей,
  LSP/navigation/format, run/debug/output/tests, git diff/stage/commit и смену
  проекта. Сеть/push проверять только в своём test remote.
- [x] Дать простые команды установки/подготовки/прогона с отчётами; описать
  восстановление/удаление fride. Внести FIXLOG/HISTORY и платформенный статус.

Общие существующие команды для подготовленной Linux-среды:

```bash
bash scripts/test.sh quick
bash scripts/test.sh e2e
bash scripts/test.sh regression
```

Они требуют подготовленных зависимостей стенда; это не текущий Omarchy PASS.
Полный regression выполняем после цельной реализации, затем только affected
повторы. Нужные регрессионные случаи добавляем вместе с изменениями providers.

Arch CLI stand из Windows/Linux x86_64, при уже включённом Docker Linux engine
и подготовленных IDE archives/frontend:

```sh
docker compose -f tests/containers/compose.yaml build ubuntu
python -B tests/diagnostics/check-arch-install.py --artifacts .tests/cold-install/artifacts/omarchy
```

Первый шаг нужен один раз для общего test image. Во втором каталог должен
содержать `core.tar.gz`, `terminal.tar.gz`, `fride-setup`, `frontend-manifest.json`;
это подготовленные native Linux payloads из общего delivery pipeline, не cache
пользователя. Нужен подготовленный Neovim для PTY driver (`--nvim PATH`, иначе
PATH на Linux или private repo SDK на Windows). Publisher создаётся и удаляется
автоматически; target — pinned official Arch image, 2 CPU/3 GiB. `--keep`
оставляет только свои контейнеры для диагностики, IDs и отчёты — в `.tests/omarchy`.
Docker Desktop/WSL скрипт не запускает и не перенастраивает.

Настоящая Omarchy после установки: [O1-O8 и команды](../tests/manual/omarchy.md).
