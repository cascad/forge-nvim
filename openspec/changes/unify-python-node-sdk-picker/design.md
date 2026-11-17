# Design

## Context

См. proposal. forge.python.resolve и forge.node.executable уже читают tools.json
и legacy overrides; Pyright/DAP/tests/Node commands используют эти резолверы.
ForgeSdk имеет native select/input и native restart/session/active work guard.

## Goals / Non-Goals

**Goals:** единое меню поверх существующих настроек, filesystem candidates и
bounded async version probes, сохранность venv и соседних JSON keys.

**Non-Goals:** установка/обновление SDK, новый менеджер версий, изменение SDK
homes/PATH, независимая политика installer или новая Python/Node интеграция.

## Decisions

- ForgeSdk UI выбирает backend: Go/Rust прежний, Python/Node отдельный provider
  с теми же choice/discover/probe/save методами. Общий flow/menu/restart один.
- Python/Node paths остаются в tools.json. Добавить атомарную запись/сброс ключа
  с проверкой прежнего JSON и сохранением неизвестных metadata/соседних tools.
  Отдельный sdk.json Python/Node отвергнут: два конкурирующих источника настроек.
- Сброс означает удаление ключа выбранной области, с явной подписью «наследовать».
  Это обычный settings reset; Go/Rust explicit Auto имеет прежнюю семантику.
- Discovery: effective setting, PATH executables, active/project venv и bounded
  directories штатных managers. Ручной путь покрывает прочие места. Python
  symlink не realpath-ится: он должен сохранить venv interpreter/prefix.
- CLI только при menu/manual/refresh, timeout3s/max2 concurrent. Python -I -B
  JSON probe, Node --version; project content/tools при version probe не запускаются.
- Сохранение читается следующими workflow; отдельная подпись не обещает сменить
  работающий LSP. Явный reopen использует готовый SDK guard/session restore.

## Risks / Trade-offs

- Existing LSP держит прежний interpreter → явное reopen, без private reload API.
- Corrupt config → source-aware отказ записи, файл исправляется пользователем.
- Не все managers имеют одинаковый layout → ограниченный read-only поиск и manual.
- Windows App Execution Aliases могут открывать Store → не предлагать WindowsApps.
