# Proposal

## Why

FIXLOG §43 нашёл и исправил дефекты подключения конфига WezTerm в установщике macOS, но в `nvim_forge/scripts/install-linux.sh` та же логика осталась старой копией. Сверка базовой линии подтвердила все дефекты на Linux (WT-LOAD-13, divergence 10; проба `linux_probe.sh` в WSL):

1. Если `~/.config/wezterm` — симлинк на каталог чекаута, `wezterm.lua` репо уезжает в `wezterm.lua.backup-*`, а на его месте появляется симлинк сам на себя: файл репо пропадает (`install-linux.sh:214-228`).
2. Из терминала nvim_forge (`XDG_CONFIG_HOME` = корень репо) симлинк создаётся внутри репо, в `<репо>/wezterm/wezterm.lua` (`:214`).
3. Верный относительный симлинк считается чужим: цель сравнивается строкой с абсолютным путём. Он уходит в бэкап при каждом запуске (`:217`).
4. Если `~/.config/wezterm` — битый симлинк, `mkdir -p` падает с `File exists`, и установка останавливается с кодом 1 (`:226`).
5. При `curl | bash` `BASH_SOURCE[0]` внутри функции равен `main`, поэтому `wezterm.lua` ищется от текущего каталога (`:199`).

Кроме того, ручная команда для Linux в шапке `wezterm.lua` (`wezterm.lua:17`, divergence 15) падает на чистой машине: каталога `~/.config/wezterm` нет. И шапка не упоминает, что то же делает `install-linux.sh`.

Корень проблемы — две копии одной логики, из которых §43 починил одну.

Объём владелец решил 2026-09-27 (Q13 = A): только исправления 1–5 и команда в шапке `wezterm.lua`. Нейтрализации перекрытий (`~/.wezterm.lua`, `WEZTERM_CONFIG_FILE`) и проверки итога на Linux не будет. Сценарий WT-LOAD-13 «перекрытия не нейтрализуются и итог не проверяется» остаётся как есть. Отвергнутые варианты — design.md, Decision 6.

## What Changes

- Шаг WezTerm в `install-linux.sh` получает ту же логику подключения, что `install-macos.sh` после §43:
  - каталог скрипта считается один раз, и только если скрипт запущен из файла;
  - пути сравниваются после раскрытия симлинков;
  - путь, уже ведущий в файл репо (абсолютным или относительным симлинком, через каталог-симлинк), не трогается;
  - битый каталог-симлинк уходит в бэкап и заменяется настоящим каталогом;
  - `XDG_CONFIG_HOME`, указывающий внутрь чекаута, не учитывается.
- Ручная команда в шапке `wezterm.lua`: `mkdir -p ~/.config/wezterm && ln -sf "$PWD/wezterm.lua" ~/.config/wezterm/wezterm.lua` (из корня репо) и ссылка на `./nvim_forge/scripts/install-linux.sh`.
- Новый `tests/install-linux.scenarios.sh` — песочница по образцу macOS: свой HOME, `env -i`, GUI-сессия через `DISPLAY`. Он покрывает каждый из пяти дефектов и прежние сценарии WT-LOAD-13.
- Перекрытия на Linux по-прежнему не нейтрализуются и итог не проверяется: `~/.wezterm.lua` и `WEZTERM_CONFIG_FILE` молча перекрывают симлинк, код 0 (решение владельца, Q13 = A).
- Обновляются документы, описывающие подключение на Linux (nvim_forge/README.md, docs/WEZTERM.md), и дописывается запись FIXLOG со строкой `Спека: WT-LOAD-13 (MODIFIED)`.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `wezterm-config-loading`: WT-LOAD-13 — какие пути шаг Linux не трогает, где кладёт симлинк, поведение при битом каталоге-симлинке, при `curl | bash` и ручной команде. Новых требований нет: нейтрализации перекрытий и проверки итога на Linux не будет (Q13 = A).

## Impact

- Код: `nvim_forge/scripts/install-linux.sh` (шаг WezTerm); новый общий с `install-macos.sh` файл функций подключения `nvim_forge/scripts/lib/wezterm-link.sh` (design.md, Decision 1) и его подключение в `install-macos.sh`.
- `wezterm.lua`: только комментарий-шапка, поведение конфига не меняется.
- Тесты: новый `tests/install-linux.scenarios.sh`; нужны те же bash, git и python3 (WSL/Linux).
- Документы: nvim_forge/README.md, docs/WEZTERM.md; nvim_forge/FIXLOG.md.
- Вне охвата, но рядом:
  - режим установки в `~/.config/nvim` в `install-linux.sh` (по умолчанию клонирует весь монорепо, как MAC-INST-10 на macOS). На macOS он становится симлинком на `<чекаут>/nvim_forge` (change `fix-macos-installer`, Q12 = B). Тот же симлинк на Linux — follow-up change после этого, здесь не делается;
  - флаги Linux в nvim_forge/README.md (divergence 12) — change `sync-docs-with-baseline`.
