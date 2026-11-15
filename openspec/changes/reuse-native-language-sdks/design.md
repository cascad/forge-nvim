# Design

## Context

Managed setup и launch переназначали XDG/NVIM/temp и SDK profiles. Это меняет toolchain, registry/auth, global install destinations и даже SDK defaults без явных SDK variables. Checkout launcher такой policy не применяет. Полный Default release ещё не опубликован. Владелец выбрал штатные каталоги отдельного приложения fride.

## Goals / Non-Goals

**Goals:** сохранить штатные SDK/project settings при явном setup и каждом запуске, оставить IDE приватной, закрепить регресс и исправить текущий план.

**Non-Goals:** новый SDK manager, упаковка Node/Go/Rust/Python, глобальный sandbox, реализация нового installation UX или автоматическая установка SDK. Установку недостающего SDK сначала предлагает UI и выполняет только после выбора пользователя; поведение VS Code/IntelliJ IDEA изучается следующим этапом.

## Decisions

- Удалить sdk-environment.lua/tsv и их применение. Не сохранять ненужный абстрактный слой без policy.
- Не менять XDG. Использовать штатный NVIM_APPNAME=fride для plugins/data/state/cache; бинарь и конфигурация остаются в выбранном InstallPath. Конфигурация выбирается штатными -u/--cmd, FRIDE_CONFIG хранит её путь; lazy получает явные lockfile/rtp paths, команда открытия конфига открывает фактический файл.
- PATH дополняется только проверенными runtime directories IDE; исходный PATH и SDK variables сохраняются. Общие SDK не добавляются в runtime в следующих release recipes.
- Сохранять уже созданный sdk-state при обновлении; не переносить его настройки в пользовательские SDK и не удалять файлы пользователя. Обновлённые launchers его не читают.
- Mason/IDE tools продолжают использовать собственные install locations штатных providers. Это не повод глобально менять окружение процессов проектов.
- Native E2E: настоящий Neovim, fixture init/setup; whitelist env capture в probe/3 stages/launch; queries Go/Rust/npm/Python, активная venv, повтор и Windows caller restoration. Весь тестовый HOME/SDK state находится в stand; никаких реальных global installs.

## Risks / Trade-offs

- Стандартные каталоги fride общие для запусков этого приложения у пользователя, в том числе разных каталогов установки. Прежние kit data/sdk-state сохраняются без автоматического переноса; явный setup готовит данные в новом namespace. Нужен native launch/upgrade regression.
- Отсутствующий SDK теперь нельзя считать поставленным вместе с IDE; native prerequisites и UI решения пользователя — отдельный следующий этап с явным статусом.
- Native Mac проверяет владелец; Ubuntu не подменяет macOS acceptance.
