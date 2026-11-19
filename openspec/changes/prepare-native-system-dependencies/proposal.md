# Proposal

## Why

IDE-142: cold Ubuntu1795081713824789000 останавливается в
scripts/install-private.lua при проверке шрифта WezTerm: отсутствует
libX11-xcb.so.1. IDE-BOOT-50 требует готовый Core/выбранный Terminal без языковых
SDK, но frontend не подготавливает зависимости ОС; unzip для Mason и cc для
явного Rust workflow также отсутствуют. Владелец продолжил рекомендованный
вариант отдельного native APT шага; SDK остаются отложенными.

## What Changes

- Проверять только выбранные системные требования, показывать недостающее и
  команды; установка через APT с повторной проверкой, без ложного ready.
- Core — Unix download/archive utilities; Terminal — внешние runtime libraries
  текущей upstream AppImage, включая GL/EGL для GUI. Rust build tools — только
  при явной подготовке языка/eager выборе, без ранней установки SDK.
- Явная политика ask/install/check для automation, read-only check-system,
  preview без probe/install и понятные ошибки/логи/отмена.
- APT ограничен Debian/Ubuntu. На других Linux повторно использовать имеющееся,
  не запускать чужой manager. Omarchy/pacman — отдельный IDE-143 backlog.
- Пройти fresh Ubuntu Core без SDK и actual language preparation/workflows,
  затем общий affected regression; native Mac/GUI не имитировать.

## Capabilities

### New Capabilities

- `native-system-dependencies`: IDE-BOOT-52, явная подготовка системных требований
  выбранных IDE компонентов без установки отложенных языковых SDK.

### Modified Capabilities

Нет: main specs содержат WezTerm/macOS baseline; IDE baseline пока отсутствует.
Active IDE-BOOT-50/51 сохраняются; этот contract дополняет prerequisite этап.

## Impact

Native frontend/source и installed maintenance, root bootstrap flags,
неверсионный каталог OS requirements, shared native package execution,
installer fixtures/PTY/cold diagnostic, guides/roadmap/FIXLOG/HISTORY.
Старые SDK/.tools frontend/locks/backports не меняются. Системные пакеты —
штатные общие зависимости ОС, не SDK внутри fride. Omarchy plan — документация,
не заявление новой проверенной платформы.
