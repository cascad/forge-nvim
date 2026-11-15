# Design

## Context

SDK preflight уже bounded/read-only, private artifacts отделены. Не хватает действий после nonready. Текущий report create_new нельзя повторно писать по одному PID при retry; plan result сейчас создаётся до SDK decisions.

## Goals / Non-Goals

**Goals:** завершить пользовательский сценарий §245 с native TUI, явной SDK install confirmation, retry/skip/cancel, обновлённым plan и сохранением выбранных SDK locations.

**Non-Goals:** новый SDK manager, подбор всех project toolchains/версий, автоматическая установка package manager, глобальные PATH/profile правки самим fride, rollback standalone SDK, публикация release.

## Decisions

- SDK menu включается только при nonready и TTY, включая Default. Ready SDK переиспользуются. --check-sdks/preview без действий, --sdk-path DIR задаёт явный fallback bin для headless/advanced usage.
- Existing input принимает root/bin/Scripts. Выбранные SDK paths добавляются после caller PATH; broken SDK раньше в PATH не скрывается. Проектная venv/version manager имеет приоритет. Пути внутри заменяемого InstallPath отклоняются.
- Plan.sdk_paths — editor location metadata, не SDK profile. Backend получает JSON, после успешного staging пишет bin/sdk-paths.txt; launcher читает optional file и добавляет locations после caller PATH. HOME/config/cache/prefix SDK не трогаются.
- Стандартные команды: Windows winget exact IDs/no-upgrade; macOS brew install без install-upgrade; apt-get install --no-upgrade (через sudo, если доступен). Package manager должен уже существовать. Перед вызовом показываются repository/default version policy, команда и штатные места установки; отдельное подтверждение по умолчанию «Нет». stdout/stderr tee в log, stdin штатный. Никаких команд до подтверждения.
- После install/refresh — повторная проверка, Windows read-only registry PATH refresh; только подтверждённые SDK bin locations добавляются в plan. Ошибка или exit0 без SDK оставляет выбор доступным.
- Skip подтверждает конкретные зависимые components и пересчитывает SDK closure. Финальный plan после изменений подтверждается до IDE setup. Cancel130 сохраняет старый kit; уже подтверждённые standalone SDK остаются, не удаляются.
- Все retry snapshots имеют уникальные имена; --sdk-report записывается один раз как final state. --result отражает final plan и не создаётся при SDK cancel.

## Risks / Trade-offs

При Windows UI control найден реальный EPERM на первом rename staged runtime.
Повторный rename того же дерева после прогона успешен, исходный holder не снят.
Добавляется общий installer rename helper: Windows EPERM/EACCES/EBUSY — максимум
1.5s, остальные ошибки сразу; forward и rollback используют один helper.
Нативный deny-delete handle воспроизводит класс сбоя, transient и permanent
cases проверяются отдельно. SDK/Neovim binaries не меняются.

- Stock package versions задаются репозиторием менеджера; basic CLI readiness не обещает совместимость всех project/package versions. Existing healthy SDK не обновляются.
- SDK package install может потребовать штатного sudo/UAC. Real package installs не выполняются на машине агента; E2E используют native fixture manager и SDK, real integration/Mac проверяет владелец.
- Fallback location не исправляет broken SDK раньше в PATH; report объясняет проблему, пользователь может исправить PATH или выбрать другой способ/skip.
