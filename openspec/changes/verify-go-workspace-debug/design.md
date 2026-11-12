# Design

## Context

См. proposal. Current Go package уже задаёт program=fileDirname,
cwd=workspaceFolder/outputMode=remote. Editor fixture создаёт настоящий Git
root; ready SDK содержит Go/Delve. IDE-DAP-1 требует вывод первого и повторного
запуска, очистку старого и сохранение после exit.

## Goals / Non-Goals

Goals: проверить реальный go.work/local module resolution и цикл edit→F5
через существующий UI, не добавляя настройку launch.json.

Non-Goals: mixed-language матрица целиком, Go LSP/Tests matrix, новый root
resolver, adapter mock, запуск сетевых зависимостей, новый LSP/backend.

## Decisions

- app/shared соединяются go.work без replace; require v0.0.0 разрешается только
  локальным workspace. GOPROXY=off/GOENV=off/GOTOOLCHAIN=local исключают внешний
  toolchain из результата. GOWORK очищен, native Go сам находит файл.
- Пользовательские F9/F5 и Telescope picker выбирают Current Go package;
  DAP RPC используется только для наблюдения/evaluate. Без подмены adapters.
- Shared возвращает42; после первого exit пользователь меняет число на43
  обычным редактированием и запускает main снова. Проверяются stdout/stderr
  до паузы, значение локальной переменной, нижняя панель, вывод после exit,
  отсутствие старого marker во втором запуске.
- Готовые Editor/Go/Delve плюс имеющийся gopls в PATH; установка/новая test
  framework не нужны. Runtime меняется только через отдельную delta, если
  тест найдёт поведенческий дефект.

## Risks / Trade-offs

- Две реальные сборки → existing Go cache и по2 workers, bounded timeouts.
- Ошибка POSIX cleanup → честный Ubuntu FAIL с workflow evidence, без повтора.
- Native Mac/physical keys → явный owner gate; Windows не подменяет macOS.
