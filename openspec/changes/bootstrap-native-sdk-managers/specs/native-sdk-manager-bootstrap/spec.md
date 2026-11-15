# Spec Delta

## Purpose

Продолжить установку fride с чистой машины через официальный штатный менеджер SDK, сохраняя явный выбор пользователя и отдельное окружение каждого языка.

## ADDED Requirements

### Requirement: IDE-BOOT-21 Явный bootstrap менеджера SDK

Native installer SHALL сначала искать штатный менеджер в PATH и известных стандартных каталогах. Если отсутствует WinGet на Windows или Homebrew на macOS, действие установки SDK SHALL предложить официальный bootstrap менеджера с источником, командой, местом установки и отдельным подтверждением по умолчанию «Нет». После успешного bootstrap SHALL повторно найти менеджер и отдельно подтвердить установку SDK. Отказ, ошибка и exit0 без менеджера MUST оставить доступными выбор existing SDK, retry, skip и cancel; успешный plan и публикация IDE до этих решений MUST отсутствовать. Preview/check/headless MUST не запускать bootstrap. Отсутствие APT в Ubuntu SHALL объясняться как неподдерживаемое окружение без автоматического ремонта ОС. Глобальные PATH/profiles и SDK homes MUST не переназначаться; установленный по подтверждению менеджер SHALL оставаться штатным приложением при отмене IDE.

#### Scenario: Отдельные подтверждения
- **GIVEN** отсутствуют Node SDK и WinGet либо Homebrew
- **WHEN** пользователь выбирает установку Node, подтверждает bootstrap менеджера, а затем отказывается от SDK
- **THEN** bootstrap выполнен один раз, SDK не установлен и SDK menu остаётся доступным

#### Scenario: Ошибка или неполный результат
- **WHEN** bootstrap завершается ошибкой либо exit0 без доступного менеджера
- **THEN** installer показывает причину/лог и возвращается в SDK menu без запуска SDK install

#### Scenario: Менеджер уже есть вне PATH
- **WHEN** WinGet доступен через стандартный WindowsApps alias либо Homebrew в стандартном prefix
- **THEN** installer использует его напрямую без bootstrap и изменения глобального PATH

#### Scenario: Без подтверждения
- **WHEN** пользователь оставляет ответ «Нет», отменяет, запускает preview, check либо headless
- **THEN** bootstrap process и загрузка bootstrap script не запускаются

#### Scenario: Ubuntu без APT
- **WHEN** в Linux окружении отсутствует apt-get
- **THEN** SDK menu сообщает об отсутствии поддерживаемого менеджера, не устанавливая иной менеджер или SDK
