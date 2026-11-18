# Design

## Decisions

Использовать уже существующий platform URL/SHA256 catalog как источник выбора.
Проверка локальной binary.sha256 сама по себе доказывает целостность, но не
соответствие выбранной версии source. Source digest позволяет повторно взять
ту же локальную binary без скачивания; другой digest не запускается.
Explicit --installer-ui-path сохраняет осознанный developer override.

Неопубликованный developer frontend запускается явно, после существующей
build command. Это не требует от обычного пользователя скачивать binary:
release catalog и one-liner остаются штатным download route.

## Non-Goals

Новый JSON parser для Bash, проверка compatibility по версиям, автоматический
Cargo build, изменение уже подготовленных .tools binaries и full Default.

## Evidence

Отдельно подготовлены все20 настоящих Mason packages Windows/Ubuntu production
tools stage (154.56s/142.99s). Первое архивное Windows выполнение остановилось
на Git-less E2E plugin cache: это fixture preparation error, не product defect.
Для фактической установки нужны полноценные native Git repos.
