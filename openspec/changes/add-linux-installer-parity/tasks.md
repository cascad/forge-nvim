# Tasks

Прогон наборов ниже — «оба bash»: в WSL `tests/install-linux.scenarios.sh /mnt/f/repo/forge-nvim bash` (bash 5.2) и тот же скрипт с собранным bash 3.2.57 (`/home/cascad/b32/bash-3.2.57/bash`). Для `tests/install-macos.scenarios.sh` — так же. Объём — решение владельца Q13 = A (design Decision 6): только исправления 1–5 и команда в шапке `wezterm.lua`; перекрытия на Linux не нейтрализуются.

## 1. Тестовая обвязка и красные тесты

- [x] 1.1 Создать `tests/install-linux.scenarios.sh` по образцу macOS (design Decision 5):
  - аргументы `[repo] [bash]`;
  - свой HOME, `env -i`, `DISPLAY=:0`, `FORGE_NVIM_SKIP_DEPS=1`, `FORGE_NVIM_DEPS_ONLY=1`;
  - заглушки `wezterm` (пакет уже стоит) и `fc-list` (шрифт уже есть), в каждой — комментарий, что она изображает; сети нет;
  - `mk_checkout` копирует `wezterm.lua`, `nvim_forge.sh`, `nvim_forge/scripts/install-linux.sh`, `nvim_forge/init.lua` и, если есть, `nvim_forge/scripts/lib/`.

  Проверка: на текущем коде зелёные L1 (GUI, чистый HOME), L4 (без GUI — `No GUI session detected…`, симлинка нет) и L5 (`~/.wezterm.lua` и `WEZTERM_CONFIG_FILE` не тронуты, код 0) под обоими bash (windows, WSL).
- [x] 1.2 Написать L2, L3, L6–L10 по сценариям WT-LOAD-13 из `openspec/changes/add-linux-installer-parity/specs/`:
  - L2 — абсолютный и относительный симлинк на файл репо;
  - L3 — чужой файл и битый симлинк → бэкап; с `FORGE_NVIM_NO_BACKUP=1` — код 1;
  - L6 — `~/.config/wezterm` → каталог чекаута: `wezterm.lua` репо остаётся обычным файлом, бэкапов в чекауте нет;
  - L7 — `~/.config/wezterm` — битый симлинк;
  - L8 — `~/.config/wezterm` → каталог dotfiles с чужим `wezterm.lua`;
  - L9 — `XDG_CONFIG_HOME` = корень чекаута и его подкаталог; `XDG_CONFIG_HOME=<чекаут>-other` при этом учитывается;
  - L10 — скрипт со stdin, текущий каталог — `<чекаут>/nvim_forge/scripts`, где `../../wezterm.lua` есть: ловушка для поиска от текущего каталога.

  Проверка: на текущем коде красные L2 (относительный), L6, L7, L9 и L10 (под bash 5.2), остальные зелёные (windows, WSL).
- [x] 1.3 Добавить `tests/install-linux.scenarios.sh [repo] [bash]` в раздел «Проверки» `CLAUDE.md` рядом с набором macOS. Проверка: команда из `CLAUDE.md`, запущенная в WSL из корня репо дословно, печатает список проверок и итог `N passed, M failed` (windows, WSL).

## 2. Общий файл функций подключения (поведение macOS не меняется)

- [x] 2.1 Создать `nvim_forge/scripts/lib/wezterm-link.sh` по design Decision 1:
  - `resolve_path`, `link_wezterm_config` и проверка «путь внутри чекаута» (раскрытые пути, `/` на конце);
  - в шапке — контракт вызывающего (`step`, `info`, `backup_path`);
  - совместимость с bash 3.2.

  Если `fix-macos-installer` уже применён, сюда же перенести его общую функцию «симлинк с бэкапом» и проверку «внутри чекаута», а не заводить вторые копии. Проверка: `bash -n nvim_forge/scripts/lib/wezterm-link.sh` и то же под bash 3.2.57 — без ошибок; `grep -c "^resolve_path()" nvim_forge/scripts/*.sh nvim_forge/scripts/lib/*.sh` находит ровно одно определение (windows, WSL).
- [x] 2.2 Подключить файл в `install-macos.sh` по `$SCRIPT_DIR/lib/wezterm-link.sh` до первого вызова его функций и убрать оттуда перенесённые функции. `mk_checkout` в `tests/install-macos.scenarios.sh` копирует `nvim_forge/scripts/lib/`. Проверка: набор macOS зелёный под обоими bash с тем же числом проверок, что до правки (windows, WSL).

## 3. WT-LOAD-13: шаг WezTerm в install-linux.sh и ручная команда

- [x] 3.1 Считать каталог скрипта один раз на верхнем уровне через `${BASH_SOURCE[0]:-}` с проверкой, что это реальный файл (Decision 2). Подключить общий файл так же, как в 2.2; нет файла — шаг пропускается с `wezterm.lua not found near the config; skipping terminal config link`. Проверка: L10 зелёный под обоими bash — симлинка нет, в выводе это сообщение (windows, WSL).
- [x] 3.2 Перевести шаг WezTerm на `link_wezterm_config` из общего файла: путь, уже ведущий в файл репо, не трогается; битый каталог-симлинк уходит в бэкап. Проверка: L1–L3, L6–L8 зелёные под обоими bash (windows, WSL).
- [x] 3.3 Не учитывать `XDG_CONFIG_HOME` внутри чекаута (Decision 3). Проверка: L9 зелёный под обоими bash — симлинк в `~/.config/wezterm/wezterm.lua`, в чекауте ничего нового, `<чекаут>-other` учитывается (windows, WSL).
- [x] 3.4 Написать L11: вынуть из шапки `wezterm.lua` строку команды для Linux и выполнить её в чистом HOME из корня копии чекаута. Проверка: на текущей шапке L11 красный (`No such file or directory`) (windows, WSL).
- [x] 3.5 Переписать строку Linux в шапке `wezterm.lua` (Decision 4): `mkdir -p ~/.config/wezterm && ln -sf "$PWD/wezterm.lua" ~/.config/wezterm/wezterm.lua` (из корня репо), и строка «или `./nvim_forge/scripts/install-linux.sh`». Проверка: L11 зелёный — симлинк на `wezterm.lua` репо; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — непустой stdout, в stderr нет `ERROR` (windows).
- [x] 3.6 Обновить документы о подключении на Linux (если `sync-docs-with-baseline` уже переписал файлы — в их нынешних разделах про Linux):
  - `docs/WEZTERM.md` (строка про Linux в начале);
  - `nvim_forge/README.md` (раздел Linux).

  Что написать: ручная команда — как в шапке; `install-linux.sh` не трогает путь, уже ведущий в репо, и не кладёт ничего внутрь чекаута; `~/.wezterm.lua` и `WEZTERM_CONFIG_FILE` на Linux перекрывают симлинк молча, убирать их руками. Проверка: `grep -n "mkdir -p ~/.config/wezterm" docs/WEZTERM.md nvim_forge/README.md` находит команду, `grep -n "WEZTERM_CONFIG_FILE" nvim_forge/README.md docs/WEZTERM.md` находит предупреждение для Linux; ни одна правка не противоречит WT-LOAD-13 из `openspec/changes/add-linux-installer-parity/specs/` (windows).
- [x] 3.7 Дописать в `nvim_forge/FIXLOG.md` новую нумерованную запись «Проблема → Причина → Решение → Файлы» о дефектах 1–5 и шапке. В ней:
  - строка `Спека: WT-LOAD-13 (MODIFIED)`;
  - «Решение владельца 2026-09-27: Q13 = A» — перекрытия на Linux не нейтрализуются; режим `~/.config/nvim` на Linux — follow-up;
  - восстановление после самоссылки старой версии: `git checkout -- wezterm.lua` в чекауте (или вернуть `wezterm.lua.backup-*`), затем удалить лишний бэкап;
  - «Проверено: L1–L11 и набор macOS под bash 5.2 и 3.2.57; на рабочем столе Linux не проверялось (WSL-песочница)».

  Проверка: `grep -n "Спека: WT-LOAD-13 (MODIFIED)" nvim_forge/FIXLOG.md` находит запись; `git diff nvim_forge/FIXLOG.md` — только добавленные строки в конце (windows).

## 4. Интеграция

- [x] 4.1 Финальный прогон `tests/install-linux.scenarios.sh` и `tests/install-macos.scenarios.sh` под bash 5.2 и 3.2.57. Проверка: все проверки зелёные в обоих наборах под обоими bash, код 0; числа записаны в запись FIXLOG из 3.7 (windows, WSL).
- [x] 4.2 Проверка форматов. Проверка: `openspec validate add-linux-installer-parity --type change --strict --no-interactive` — valid; `openspec validate --all --strict` — без ошибок (windows).
- [ ] 4.3 Передать владельцу шаг для Mac: общий файл функций исполняется и там. `./nvim_forge/scripts/install-macos.sh` из чекаута дважды. Проверка: оба прогона — код 0, второй — `WezTerm config already linked`, новых `*.backup-*` нет; результат — в записи FIXLOG, пока его нет — там «на Mac не проверено» (macos).
