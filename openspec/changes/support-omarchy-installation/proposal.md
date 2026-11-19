# Proposal

## Why

IDE-143: владелец добавил Omarchy к рабочим системам. Текущий native OS step
отказывает при missing dependencies Arch, а Git/Node/Python recipes на Linux
выбирают APT без distro routing; чистая установка на Omarchy не завершится.
Нужны native pacman и воспроизводимые CLI/desktop проверки, сохраняя среду.

## What Changes

- Arch/Omarchy получает native pacman provider выбранных OS dependencies и
  Git/Node/Python recipes. APT остаётся Debian/Ubuntu; preview/read-only modes,
  ask/install/check, cancel/recheck и native logs сохраняются.
- Устанавливать только недостающее через pacman -S --needed; без -Sy/-Syu,
  смены mirrors, AUR/helper и автоматического system upgrade. При устаревшей
  базе дать native error/log и инструкцию штатного обновления вне fride.
- Default сохраняет отложенные SDK; существующие PATH/Mise/manual SDK и версии
  переиспользуются. На Arch при наличии Mise явная подготовка SDK использует
  mise install с настройками проекта, без редактирования config/defaults.
  Без Mise остаются official Go/rustup и native Node/Python packages.
  Ordinary Neovim/config/terminal defaults не заменяются.
- Подготовить Arch CLI install/check/repeat/preservation стенд с фиксированными
  inputs/reports и простыми командами; отделить его от настоящей Omarchy VM/
  Wayland/GPU/clipboard/hotkeys acceptance на машине владельца.

## Capabilities

### New Capabilities

- `omarchy-installation`: IDE-BOOT-53, native Arch package providers и проверяемая
  установка/использование отдельного fride на Omarchy.

### Modified Capabilities

Нет root IDE baseline (openspec/specs — WezTerm/macOS). Active IDE-BOOT-50/51/52
прочитаны: новый capability дополняет providers, сохраняя их deferred/ready и
non-Linux boundaries. Main specs не меняются.

## Impact

Native frontend system/SDK package runner, OS requirements catalog, targeted
fixtures/native tests, Arch diagnostic/test entrypoints, Omarchy guide/checklist,
roadmap/PROBLEMS/FIXLOG294–295/HISTORY/commands202–203. Готовые frontend builds Windows/
Linux отдельно после всей реализации; старые .tools SDK/frontend/locks прежние.
Native desktop PASS требует настоящей Omarchy и не заменяется контейнером.
