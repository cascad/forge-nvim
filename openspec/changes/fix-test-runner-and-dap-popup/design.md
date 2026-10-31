## Context

См. proposal.md. Neotest общий, для каждого языка адаптер. Pinned neotest-go
main 59b5050 не обновляется при обычном bump: upstream main тот же. Его
build_spec склеивает cd/path/go test, не фильтрует выбранный test. DAP expression
widget показывает No active session, входит в dap-float, но Esc/q не назначены.
Esc сборки сейчас закрывает только diagnostics. Реальный Go parser нужен
для discovery; в минимальном E2E профиле его ещё нет.

## Goals / Non-Goals

Goals: разделить обычный/test debug/eval, проверить реальный результат и
закрытие popup без мыши. Общие scenarios Windows/Ubuntu, Mac запускает владелец.
Non-Goals: замена neotest целиком, DAP/UI/FSM rewrite, общее переназначение
панелей, полное Python/Rust test coverage, скрытая установка при startup.

## Decisions

- Сначала red E2E существующего адаптера и popup. Проект с пробелами и
  соседним падающим тестом различает настоящий nearest и запуск всего пакета.
- Для Go после подтверждённого red используем pinned neotest-golang
  65b2be63c3de00e6f15c05388ebdc8d603dbd727. Он поддерживает текущий main
  Treesitter и DAP. Сохраняем go test -v -count=1 -timeout=60s; race не добавляем.
  Не поддерживаем собственную копию shell/filter/results логики старого адаптера.
- Сам neotest закреплён на 27bf921498043f7ecd821d6db68d05de244bbd02:
  старый worker требовал недоступный ему модуль nvim-treesitter и уходил в
  fallback. Новый upstream убрал это требование; E2E проверяет enabled worker.
- Общий runner — gotestsum, пишет JSON в файл, не через PTY. На промежуточном
  Windows-прогоне go runner потерял успешный результат (0 passed/2 failed вместо
  1/1). Это не доказано исправленным обновлением core: integrated strategy
  между ревизиями совпадает. Выбираем рекомендованный upstream файловый канал
  для всех ОС, без Windows-ветки. В E2E готовим gotestsum v1.13.0 явно;
  в рабочей сборке — :MasonToolsInstall или go install, без startup-install.
- Debug DAP использует -test.v для t.Log и хранит итог в REPL. Upstream
  намеренно возвращает skipped в neotest, поскольку DAP не выдаёт go test -json;
  этот статус не подменяем эвристическим passed. E2E проверяет настоящий PASS
  в REPL, eval 42 и отсутствие исполнения соседнего теста.
- Go parser собирается отдельным prepare_tests.py из ревизии каталога
  pinned nvim-treesitter. C compiler — часть явной подготовки; runtime без сети.
  Общий editor harness копирует только подготовленный site в private data.
- Небольшой eval helper проверяет paused/frame, делегирует widgets.hover.
  Esc закрывает только DAP float (вместе с существующим diagnostics flow),
  buffer-local q/Esc закрывают его изнутри. Панели/sidebar и сессия не трогаются.
- E2E использует mappings, настоящий neotest/parser/go test/Delve. Наблюдение
  через публичные API и буферы; adapter/session не подменяются.

## Risks / Trade-offs

- Новый Go adapter может иначе определять root/results → real nearest/file/debug
  тесты с маркером соседнего теста и путями с пробелами до широкого регресса.
- Native parser ABI/compiler → pinned revision и preflight загрузки parser в
  том Neovim, которым выполняется E2E. Отсутствие подготовки — FAIL с командой.
- Исходный запуск владельца неизвестен → различать найденные дефекты и
  гипотезу о последовательности на Mac; не объявлять всё IDE-006 закрытым.
- Остальные адаптеры остаются прежними → реальный Python/Rust прогон ещё нужен.

## Migration Plan

После обновления выполнить явное восстановление плагинов по lock и подготовку
Go parser. Версии тестовых инструментов и локальные профили разделены.
Откат Go adapter — прежняя lock-запись/config; регресс остаётся воспроизводимым.
