# Verification — 2026-11-18

## Implementation

IDE-BOOT-45, MODIFIED22: setup_tools использует существующий tool_paths resolver
с user scope для подключённых runtime keys, без новых version managers. Native
MTI condition откладывает чтение настроек до явной установки, пропускает external
до применения preserve/baseline и не меняет обычную unpinned policy. Для прямой
native команды invalid condition сообщает ERROR и возвращает skip, чтобы не
оборвать async refresh с бесконечным sync wait. Production setup проверяет plan
строго до вызова MTI. При полностью external наборе install command не вызывается.
Publisher/strict readiness API прежний, остальные packages проверяются как раньше.

## Native evidence

Один affected пакет Windows1795013112867992000/Ubuntu1795013124141035037:
четыре registry files и пять Python suites. Registry: native Go/Rust paths,
общие tool paths, version unit и trace. Suites: external tools, tool versions,
Go toolchain, IDE tools, SDK settings. Native runtime controls включают LSP,
formatters, Go tests, Delve и CodeLLDB. Полный regression не повторялся.

Новый external suite14 cases использует настоящий frontend/private Neovim,
готовый gopls/Prettier/Node/Delve и реальный Mason provider с локальными Rust
releases fixture v1/v2. Проверяет external-only без Go в PATH, repeat, baseline,
mixed install, invalid previous-kit preservation, project/user isolation,
JS/Node, existing Mason payload byte preservation, unknown key, replaced kit path,
исчезновение файла на native MasonToolsUpdateCompleted, Delve -> dlv и native
MTI invalid-path completion с timeout20s. Это проверка setup policy; fixture
package не выдаётся за LSP, реальный gopls запускается отдельно и в runtime controls.

Initial Windows12 PASS/1 FAIL, Ubuntu11 PASS/2 FAIL (13 cases до добавления14).
Тест неверно ожидал exit0 прямого MTI при ERROR; native command корректно дал
exit1 без зависания. В Ubuntu positive JS test не выбрал уже подготовленный
Node, которого нет в обычном PATH image. Исправлены fixtures/ожидание, product
не менялся после initial batch. Added missing-Node negative14, повторены только
affected6/13/14 на каждой ОС. Ubuntu3 PASS4.884s, Windows3 PASS17.101s.
Latest aggregate: Windows77 PASS2 informational SKIP, Ubuntu74 PASS5 SKIP
(3 native SDK skips, 2 informational). Trace SKIP относятся к отсутствию manual
links и прежнему pending IDE-SQL-9 без registered E2E. Сводка
последних случаев сохранены в .tests/toolchain-research/external-tools-composite.json
и external-tools-windows/ubuntu-affected.txt. Первичные FAIL logs сохранены.

## Bounds

User tools.json, существующие runtime keys; отдельные legacy vim.g/env tool paths
не становятся новым setup policy. JS readiness проверяет file и Node, CodeLLDB
ожидает целый готовый upstream bundle. Это не совместимость любых версий или
full Default delivery. Native macOS остаётся задачей владельца. Все исходные
SDK/locks/backports/UI payloads прежние; host tmp F, Docker existing/offline/
2CPU/3GiB, без Desktop/WSL lifecycle/config. Raw/staged journal prefixes и
точный index проверяются перед commit. MODIFIED22 ждёт синхронизации предшественников;
strict advisory не означает их archive или завершение Mac gates.
