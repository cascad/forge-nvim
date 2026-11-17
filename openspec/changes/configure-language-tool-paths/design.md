# Design

## Context

См. proposal.md. Python/Node/Bash уже имеют небольшие native discovery modules.
Config установленного kit находится отдельно от штатного stdpath(config).
До запуска инструментов нельзя устраивать version probes/downloads.

## Goals / Non-Goals

**Goals:** небольшой общий слой декларативных путей, понятные источники,
сохранение существующих consumers и реальный редакторный E2E.

**Non-Goals:** новый package/environment manager; изменение SDK installation,
Go/Rust/SQL consumers, providers/update policy, дополнительные DAP argv.
Аргументы пользовательских launch configs сохраняются штатно.

## Decisions

- User: stdpath(config)/tools.json, project: ближайший .fride/tools.json в
  границе .git/.fride. Формат {"tools":{"python":"...","node":"..."}}.
  Только данные; Lua проекта не исполняется. JSON выбран вместо нового DSL.
- project > user > прежний vim.g > прежний env > native language lookup.
  User relative paths относительно user config directory; project — project root;
  bare command name разрешается через PATH. Сохраняем symlink выбранной venv.
- Маленький resolver валидирует explicit executable/file/directory. Языковые
  модули сохраняют discovery. Bash host продолжает исключать WSL launchers.
- Чтение ограничено64KiB. Parsed config кешируется по mtime/size; обычный startup
  лишь регистрирует ForgeToolPaths, без probe и обхода SDK.
- Изменение выбора записывается в существующий log_store. Отчёт ловит ошибку
  каждого инструмента отдельно и открывает источник Tool paths в ForgeLogs.
- Ошибка explicit selection прерывает consumer; Python больше не игнорирует
  неверный override. JS entrypoint проверяется как файл, не executable.

## Risks / Trade-offs

- Новые JSON settings могут конфликтовать с legacy → documented priority,
  legacy E2E и отсутствие автоматической миграции/перезаписи configs.
- Текущий LSP не перезапускается при редактировании config → новый выбор
  действует на следующий запуск, активный LSP перезапускается штатно.
- Полный набор языков выходит за этот срез → остаток явно остаётся в roadmap;
  общий resolver не выдаётся за завершённую интеграцию всех consumers.
