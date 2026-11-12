# Проверка IDE-114

2026-11-12. Source driver af982a9, frozen git archive tests/lib; config/SDK
и product Lua прежние. Spec checks не применяются: skip_specs=true, это
наблюдение тестового harness. Design и existing cleanup contract соблюдены.

| Измерение | Результат |
|---|---|
| Полнота |4/5 tasks: реализация/Windows/Ubuntu/история готовы, Mac открыт |
| Correctness |3 source RED/2 controls → target5 PASS на каждой ОС |
| Регресс | Windows37 PASS/2 SKIP, Ubuntu39 PASS;6 прежних suites |
| Native audit | Source/target по10 profiles на ОС; selected21 Windows/23 Ubuntu без unexpected failures |
| Unit/trace | На каждой ОС371 PASS/1 SKIP,18 файлов PASS |
| Strict |102 items PASS |
| Не проверено | Native Mac; whole E2E повторно не запускался |

## Причинная проверка

Source stop_process проверял только generic cleanup.ok. Permanent test
запускает настоящую nvim_forge и завершает её cquit23, SIGKILL собственного
handle или cquit23 с primary_error. Cleanup.ok=true, scope empty, runtime
удалён, но исходный wrapper не сообщает ошибку —3 RED. Target добавляет
code0/signal0 assertion в wrapper и использует прежний pcall/merge/remove;
те же три scenarios проходят, normal0/0 и generic clean cquit24/0 сохранены.
rpc=nil preparation path проверен existing editor-runtime case.

Windows intentional SIGKILL code1/signal9, Ubuntu code0/signal9. Таким
образом code и signal проверены независимо. Generic editor_process.stop
по-прежнему возвращает cleanup.ok=true для intentional cquit24, cached
verdict неизменён. Ошибка обычного stop содержит Native exit/code/signal,
primary_error сохраняется в исключении и shutdown.json. Повторный stop
после removal безопасен, generic quit/RPC deadline прежние.

Test SHA256 c60a9e2cc442f9128fc99b6a7004e9f350bba006f7c53745f64e316e0b1e0a6d.
Actual loaded editor-source.lua source SHA256
5f9ff598e5e9e8cc3c4f1ed5e168ada2d269995faf79409cf39ff69a974b7838;
target c93029a95ffce14c5baf10500f5b82206b3b4bc270144732735c2daa86735adb.
Native audit сверяет реальные bytes теста/editor/driver/config, outcome/
APIerrors[]/scope. Для8 Forge profiles source+target на ОС runtime FS removal
проверен в той же среде; два generic clean controls не создают editor runtime.
Ubuntu audit выполнен до удаления соответствующего pod. Intentional receipt
не освобождает от actual expected code/signal, PASS case и cleanup assertions.

## Уточнение fixture

Первый Linux запуск SIGTERM ошибочно ожидал signal15, но Neovim обработал
его и вышел1/0. Это ошибка ожидания теста: два cquit RED верны, signal case
не считается причинным воспроизведением IDE-114. Initial raw test/logs
сохранены в .tests/native-exit-initial-* и Ubuntu native-exit-initial-ubuntu.txt.
После выбора unhandled SIGKILL source/target обеих ОС повторены с теми же
финальными test bytes; все5 native profiles каждой фазы проверены отдельно.

## Выбранная интеграция

editor-process1/2, editor-runtime4/5, plugin-backports15, SQL Tests12,
project-session1, legacy4 — Windows/Ubuntu соответственно. Native metadata
21/23 profiles: normal roots0/0, APIerrors[], own scopes empty, source files
совпадают. Ubuntu два intentional stopped-child SIGKILL fixtures имеют
actual PASS case/hardkill/RPC/primary и ожидаемый cleanup FAIL; они проверены
отдельно, общего исключения nonzero exit нет. Metadata review не считается
независимой FS проверкой всех regression profiles.

Source/target/regression evidence: .tests/native-exit-* и
.tests/ubuntu/integration-20261112/native-exit-*. Windows/Ubuntu heavy по
очереди, Windows temp/build F:. Cached Ubuntu2 CPU/3 GiB/256 pids/network
none/checkout ro; Desktop/WSL не управлялись. SDK74AFF15B...C6AD9 прежний,
67 pins/6 patched dependencies прежние; SDK не пересобирался.

CRITICAL: task2.1 native Mac не выполнена; archive readiness не заявляется.
Новые selected PASS не изменяют §191–193 FAIL и не устанавливают причины
IDE-085/117/118. Следующий шаг IDE-117 — capture полного ps probe result.
