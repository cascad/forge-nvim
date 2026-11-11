# Design

## Context

Python_case выбирает python/python3 и запускает class, печатая один SELF result. Общий runner передаёт FORGE_TEST_ID всем файлам; другие Lua cases используют check.matches. Source920e69e под --id IDE-PANEL-15 давал пять editor cases и три чужих SELF wrappers.

## Goals / Non-Goals

**Goals:** фильтровать до lookup/spawn общим matcher; прежний протокол выбранных suites; native cross-process regression без mocks Python/executable lookup.

**Non-Goals:** переписывать discovery/launcher/runner, менять timeout или interpreter policy, product runtime/SDK/pins. Windows PASS не заменяет Ubuntu/Mac.

## Decisions

- Полное case name остаётся SELF: + title. Ранний guard использует check.matches и FORGE_TEST_ID; отфильтрованный файл завершается0 без output, runner классифицирует NONE.
- Native E2E запускает отдельный Neovim с реальным helper и Python fixture в Unicode/space path. Python пишет JSON sentinel с argv/cwd/PID и stdout/stderr. Observer оборачивает exepath только для записи фактических вызовов, результат неизменён; ready/source copy доказывают запуск observer. Чужой ID должен оставить пустые lookup log и stdout, sentinel отсутствует.
- Семь vectors: чужой ID, неправильная граница prefix, чужой ID без Python PATH; unfiltered success, выбранный SELF prefix, выбранный failure7, выбранный missing-Python SKIP. Положительные vectors выполняют настоящий Python; missing PATH приватен дочернему процессу.
- Source override только в тестовом driver через явный путь module, production helper нового env/API не получает. Native source RED до fix; final bytes совпадают. Проверить четыре существующих wrapper и общий IDE-PANEL-15 run, чтобы нужные editor cases сохранились.

## Risks / Trade-offs

Отсутствующий host Python делает positive native cases неподготовленной средой; не считать их PASS по одному output. Unicode argv и Windows PATH проверяются реальным запуском, Mac/Ubuntu требуют своего native run. Artifact directories остаются под .tests на F:; test запускает только короткий controlled Python, дополнительных workers нет.
