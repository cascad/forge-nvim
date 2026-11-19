# Design

## Context

Root specs не содержат IDE baseline. Прочитаны active IDE-BOOT-50/51, native
sdk_install/sdk_actions/lib/language, private installer, fixture/PTY/cold helper.
Core/Terminal доставляются как готовые IDE archives; sdk_install уже имеет
native argv/log/exit handling и DEBIAN_FRONTEND внутри sudo boundary.

Observed: readelf upstream wezterm-gui использует RUNPATH=$ORIGIN/../lib;
ldd на Ubuntu test image показывает недостающие системные XCB/X11/fontconfig/
Wayland client. AppImage содержит остальные NEEDED libraries, включая OpenSSL1.1.
GL/EGL загружаются отдельно и нужны для реального GUI; DISPLAY/GPU остаются
натурным gate. Mason Unix требует archive/download commands. Rustup cold warning
подтвердил отсутствие cc. Стандартный Default не должен готовить Rust SDK/build.

## Goals / Non-Goals

Goals: повторно использовать готовые OS utilities/libraries; устанавливать только
недостающее штатным APT; объяснять команды/политику/отказ, повторно проверять;
разделить платформенную механику и общий install/prepare workflow.

Non-Goals: SDK version matrix, private copy системного desktop/SDK, собственный
APT solver, установка GUI session/драйверов, pacman реализация в этом срезе,
изменения Windows/macOS package managers, старт/перенастройка Docker/WSL.
IDE-143 отдельно планирует Omarchy/pacman и настоящие desktop tests.

## Decisions

### Общий contract, Linux provider

system.rs читает shipped неверсионный requirements JSON из config/scripts.
Источник одинаков в source/installed layout, без второй копии canonical data.
Scope Core всегда; Terminal только если выбран; Rust/Go дополнительные OS
требования только при explicit prepare/eager. Windows/macOS возвращают
not-required без Linux probes/APT. На Linux os-release выбирает Debian/Ubuntu
provider; ID/ID_LIKE Arch/Omarchy не маршрутизируются в APT.

Проверка commands через native PATH resolver, library SONAME через read-only
ldconfig -p с bounded timeout/output. Нет CLI SDK version/download probes.
Existing commands/libraries пропускаются независимо от distro. Если на иной
Linux чего-то не хватает, выдаётся честный unsupported-provider/manual путь.
Это точка расширения pacman, а не обещание Omarchy acceptance.

### Явное действие и повторная проверка

--check-system выводит JSON/exit0 либо2, без package actions/Core downloads.
Preview/print-plan не запускают OS probes. Политика --system-deps ask (default),
install или check: ask показывает команды и спрашивает в TTY; без TTY сообщает
явный automation flag; install выполняет показанные команды; check не ставит.
Отмена даёт130. Обычный missing/failed case не пишет ready и не заменяет kit.

APT update и install идут отдельными native argv recipes через существующий
runner. Package names валидируются, версии/OS release SDK не пинятся; install
имеет --no-upgrade/--no-remove, только недостающие direct packages. Транзитивные
зависимости решает APT; не заявляем, что он никогда не меняет зависимости.
DEBIAN_FRONTEND только в дочерней env boundary (внутри sudo). Готовые SDK,
Neovim и project/user config не переустанавливаются этим шагом.
После команды повторный probe обязателен; exit0/no-op — ошибка, не ready.

Шаг normal install — до Git/SDK/artifact stages; installed prepare — после
проверки owned kit/плана, до SDK decisions. Логи/report — стандартный log-dir,
в IDE доступны в task output/общей Languages history. Rust cc/ar относятся к
явной языковой подготовке; Core не получает Rust/C toolchain из desired mask.

### Проверки и fixtures

Delivery-only stands объявляют пустой fixture requirements catalog, поскольку
их tools/Terminal stages контролируемые, а не настоящие Mason/WezTerm. Новая
специализированная suite использует production reader/flow и native manager/
ldconfig fixture: install/reuse/cancel/no-op/error/preview/scopes/privilege env.
Это не скрытый production bypass. Distro parser имеет regression Arch/Omarchy.
Real cold Default использует production catalog и обычный APT в отдельном
owned Ubuntu контейнере, после реализации всего блока.

## Risks / Trade-offs

Системные packages требуют прав: команды и источник видны, unattended opt-in
явный. Existing manager config/locks/repositories не переписываются.
ldconfig cache не доказывает GUI/DISPLAY; native font probe сохраняется, GUI
gate остаётся. Набор SONAME привязан к уже поддерживаемой WezTerm runtime
policy; обновление runtime требует нового genuine dependency/cold acceptance.
Shared SDK/tool settings и выбранные версии остаются выше fallback paths.
Один affected packet Windows/Ubuntu на финальном checkpoint, затем только
failed/affected repeats; full unrelated E2E не запускается на каждую правку.
