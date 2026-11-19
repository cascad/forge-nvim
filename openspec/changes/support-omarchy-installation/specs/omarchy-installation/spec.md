# Spec Delta

## Purpose

Обеспечить установку отдельного fride на Arch/Omarchy штатными средствами,
с сохранением готовой среды и различением автоматической CLI и desktop проверки.

## ADDED Requirements

### Requirement: IDE-BOOT-53 Установка и проверка на Omarchy

На Arch/Omarchy fride SHALL переиспользовать готовые зависимости/SDK и предлагать
недостающие OS packages и Git через native pacman. При наличии Mise явная
подготовка отсутствующего SDK SHALL использовать штатные project versions/options
через mise install; для ненастроенного языка — tool@latest. Без Mise Node/Python
SHALL использовать pacman, Go/Rust — прежние upstream providers. Provider SHALL
определяться по ОС, не наличию foreign manager. Установка MUST NOT выполнять
sync базы/полный system upgrade, менять mirrors/desktop/Mise/ordinary Neovim
или требовать AUR/helper. Готовые SDK/версии/custom paths и deferred Default
SHALL сохраняться; package actions SHALL быть явными с command/log/recheck.
Платформы: linux/arch, native linux/omarchy; Windows/Ubuntu regression, Mac отдельно.
Проверка: tests/install-system-dependencies.test.py, tests/install-arch-packages.test.py; вручную (tests/manual/omarchy.md).
Натурные сценарии: O1-O8.

#### Scenario: Установка недостающего
- **GIVEN** выбран Core/Terminal либо явно подготавливаемый язык
- **WHEN** на Arch отсутствуют нужные packages и пользователь подтверждает действие
- **THEN** видит pacman command/source и получает native transaction/recheck
- **AND** неподключённые language SDK/build tools не устанавливаются

#### Scenario: Имеющаяся среда
- **GIVEN** есть ordinary Neovim, SDK в PATH/Mise либо explicit paths и settings
- **WHEN** устанавливается, обновляется или повторно запускается fride
- **THEN** private IDE использует отдельный app namespace и сохраняет эту среду
- **AND** ready SDK/versions не заменяются и язык не ставится без выбора

#### Scenario: SDK через существующий Mise
- **GIVEN** на Arch установлен Mise и SDK отсутствует
- **WHEN** пользователь явно выбирает подготовку языка
- **THEN** Mise устанавливает выбранный язык по текущей конфигурации проекта
- **AND** config/defaults/trust policy не переписываются, результат проверяется native SDK probe
- **AND** ошибка/no-op оставляет причину и log, без скрытого перехода на pacman/другой SDK

#### Scenario: Просмотр SDK в разных проектах
- **GIVEN** один Mise shim соответствует разным SDK двух проектов
- **WHEN** пользователь проверяет SDK либо переключает проект
- **THEN** версия/ошибка соответствует текущему project cwd и не портит cache другого проекта
- **AND** readiness probe не скачивает SDK и не меняет обычный terminal environment

#### Scenario: Ошибка или устаревшая база
- **WHEN** действие отменено либо manager/DB/keyring/mirror/recheck не готов
- **THEN** нет ложного ready/замены рабочего kit, доступны причина и native log
- **AND** требуется штатное исправление ОС и повтор, без автоматического sync/upgrade

#### Scenario: Проверки и платформенные границы
- **WHEN** выбран preview/check либо выполняется Windows/macOS/другой Linux
- **THEN** прежние read-only/confirmation boundaries соблюдаются
- **AND** APT не вызывается для Arch и pacman не вызывается для чужой family
- **AND** Arch CLI report не объявляет Omarchy Wayland/GPU/clipboard/hotkeys готовыми

#### Scenario: Воспроизводимый стенд
- **WHEN** владелец запускает документированную команду контейнера или native проверки
- **THEN** получает baseline/source/versions и результат с reports без скрытого Docker/WSL старта
- **AND** native desktop checklist отдельно показывает выполненные и непроверенные cases
