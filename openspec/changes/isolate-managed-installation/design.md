## Context

См. proposal.md. Поддерживаемый Windows Neovim имеет два native patches, поэтому системный nvim не является эквивалентом. Нужен один общий installer после получения native runtime; Lua доступна в уже доставленном Neovim без Python bootstrap.

## Goals / Non-Goals

Граница этой итерации — независимый комплект и доставка подготовленного runtime. Полнота языковых release assets, Mac acceptance и публикация остаются явными gates IDE-138. Старые direct scripts сохраняются как legacy и не входят в безопасный source entry.

## Decisions

- Source entry вызывает private backend, минуя прежние global package scripts. Корень по умолчанию — LOCALAPPDATA/forge-nvim/installation или XDG_DATA_HOME/forge-nvim/installation. Source cache остаётся рядом в sources.
- Runtime содержит forge-runtime.json: schema/platform/components/nvim/bin directories, readiness probes и SHA256 файлов. Проверка выполняется до изменения целевой конфигурации. Внутренний SDK можно скопировать; изменение общего PATH/запись в найденный host SDK запрещены.
- Общий Lua installer использует native fs/process API. Два тонких bootstrap backend выбирают executable runtime. Launcher применяет окружение только в дочернем процессе, задаёт все stdpath и private temp, не добавляет себя в shell profile.
- Config/runtime/bin коммитятся из staging после успешного setup. На повторе старые файлы сохраняются в backup; ошибка setup сохраняет прежний launcher и возвращает nonzero. Обновление plugin data самого Forge не является общей транзакцией; чужие данные не затрагиваются.
- Ссылки/непустые чужие targets отклоняются. Безопасный install root не бывает родителем source/runtime. Artifact index публикуется только после подготовки и проверки bundle; пустой индекс — честная ошибка, не fallback на global package manager.

## Risks / Trade-offs

- [Release artifact ещё не опубликован] → advanced локальный RuntimePath для стенда; не публиковать пока one-liner как полностью готовый Default.
- [macOS ABI/системные требования] → отдельный native gate владельца, Ubuntu contract не считать Mac acceptance.
- [Runtime может содержать несовместимый инструмент] → manifest, SHA256, probes и существующие языковые E2E; marker компонента сам по себе не доказывает фичу.

## Migration Plan

Старый nvim не мигрируется автоматически и не перезаписывается. Новый InstallPath обозначает корень комплекта. Для отката Forge сохранён предыдущий config/runtime/bin; пользовательские данные остаются на месте.
