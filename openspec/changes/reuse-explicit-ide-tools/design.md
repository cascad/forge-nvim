# Design

## Decisions

Малый setup_tools module описывает только уже поддерживаемые runtime keys и
перевод Mason delve -> dlv; JS entrypoints отличаются от executables. Он вызывает
tool_paths.override(scope=user), сохраняет source и проверяет Node через ту же
user setting/PATH, без project discovery. Неизвестный ключ не исключает package.

Catalog создаёт native MTI condition без чтения JSON/registry на startup.
При явной установке condition проверяет external path до installed-version
policy. Setup plan разделяет выбранные external и оставшиеся Mason names;
readiness/build проверяют только Mason names, external повторно проверяются
после установки. При полностью external наборе Mason install не вызывается.
Прямые strict readiness/publisher calls остаются прежними.

Выбранные user files/SDKs/payloads/receipts не меняются, baseline не сбрасывает
external paths. Неверный явный path не заменяется PATH/Mason fallback. Проектные
tools.json не влияют на установку самого приложения. Ссылки внутрь заменяемых
kit directories отклоняются, как выбранный SDK внутри старого kit.

## Non-Goals

Новые path keys для неподключённых consumers, автоматическая установка SDK,
свой version solver/updater, устранение обычных prerequisites проекта,
проверка произвольной совместимости всех LSP версий и full Default delivery.

## Verification

Один affected пакет Windows/Ubuntu после цельного изменения: настоящий frontend/
private Neovim/Mason, локальные native package releases и готовый gopls/Prettier;
external-only, mixed, baseline, invalid, project isolation, moved kit path и
повтор с уже установленным package. Existing version/Go/readiness/runtime controls.
Native macOS остаётся отдельным шагом владельца.
