# Proposal

## Why

Владелец хочет принять Windows/macOS установленной сборки. IDE-138 уже имеет
native frontend, private runtime и проверенные backend stages, но checkout
сам по себе не устанавливает dependencies, а public artifact catalogs пусты.
Нужен готовый локальный комплект до публикации; Omarchy отложена владельцем.

## What Changes

- Явная publisher-подготовка официального POSIX Neovim0.12.2 с pinned SHA.
- Сборка локального приёмочного комплекта из подготовленных Core/Terminal,
  текущего frontend и tracked source; штатный native installer запускается
  одной командой, без developer dependencies на машине установки.
- Проверка комплектности/SHA до запуска frontend, Default/Custom и обычные
  параметры установки; прежние системные nvim/config/SDK сохраняются.
- Windows bundle готовится здесь; native macOS сборка и GUI приёмка открыты
  до выполнения на Mac. Публичные catalogs/URLs не объявляются готовыми.

## Capabilities

### New Capabilities

- `native-acceptance-delivery`: IDE-BOOT-54 — локальный native установщик;
  IDE-BOOT-55 — явная подготовка upstream POSIX Neovim для publisher.

### Modified Capabilities

Нет. Прежний remote bootstrap и runtime formats сохраняются.

## Impact

Новые publisher scripts/templates, E2E CLI tests, инструкции и история.
Существующие package-runtime/Core/Terminal и fride-setup переиспользуются.
Plugin pins, SDK policy, языковые managers, GUI/DAP и main specs не меняются.
