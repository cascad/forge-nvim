# Design

## Decisions

Options/Plan сохраняют отдельный allow/deny для данной операции. Preview/check
не спрашивают и не загружают; interactive Go selection предлагает default No,
headless требует CLI opt-in. Не наследовать разрешение из случайного parent env.

Frontend передаёт private installer только согласованную policy. Plugins/parsers
и probes работают local, tools получает auto до старта child/init/Mason snapshot.
Прямой explicit tools stage применяет ту же policy до загрузки Mason.
Missing/invalid policy не разрешает downloads. Неполная/ошибочная установка
сохраняет прежний kit; ошибка native Go и лог доступны без автоматического retry.

Go1.21+ поддерживает native toolchain switching. При allow build_sdks проверяет
локальную рабочую Go installation, но не требует предварительно нового compiler:
go install module@version сам выбирает необходимый toolchain. Ready pinned tools
не требуют compiler probe. Обычный runtime не читает setup policy.

## Non-Goals

Собственный SDK downloader/version solver, замена Mason providers, установка SDK
внутрь fride, изменения SDK проекта, политик checksum/proxy либо иных языков,
пересборка native Neovim и полный regression на каждую правку.

## Verification

Сначала закончить feature, затем один affected batch Windows/Ubuntu. Native
installer PTY/CLI/real private Neovim проверяет выбор и stage env; настоящий Go
проверяет запрет, переключение доступного compiler и ошибку недоступной загрузки.
Фикстуры установки не выдаются за full Default; macOS проверяет владелец.
