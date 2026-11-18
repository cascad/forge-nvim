# Design

## Решение

Сохраняем реальные language servers, Cargo, CodeLLDB и native UI. Fixture
использует те же публичные paths, что пользователь. Длинный stdout проверяется
с учётом переноса PTY и отдельно сопоставляется с session.config.args. Состояние
до и после сохраняется в артефактах, причины отделяются от предположений.

## Проверка

Разобрать сохранённые отказы до правок. Запустить Rust language, DAP routes,
test runner, mixed project и UI capture одним пакетом на каждой доступной ОС.
Повторять только затронутые отказы; полный checkpoint не повторять.

Git: §275 сохранил живой show exit0, 525319 bytes, но тест требовал ещё и
необязательный следующий show exit!=0. Для live-case достаточно настоящего
незавершённого чтения, его правильных bytes, удаления и последующего stage;
искусственно требовать ошибку нельзя. Completed-case сохраняет прежний gate.
Git helper проверяется отдельным affected пакетом после уже запущенных пяти файлов.
Go callback вызывает native dap.async.run из main loop через vim.schedule:
асинхронный probe остаётся прежним, но больше не наследует чужой nio coroutine.
Повтор: test-runner, go-passive, dap-output и два Git файла вместе с UI capture.

## Non-Goals

Не менять Git backend или политику SDK, не устранять чужой process/trace
WIP в этом коммите и не объявлять полный regression/macOS PASS.
