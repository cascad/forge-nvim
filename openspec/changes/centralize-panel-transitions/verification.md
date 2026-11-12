# Verification: centralize-panel-transitions

2026-11-12. Windows проверен; Ubuntu и Mac не проверены. Change не завершён
и не архивируется. Применён openspec-verify-change.

| Dimension | Status |
|---|---|
| Completeness | 2/5 tasks; 1.2/2.1 ждут Ubuntu, 2.2 — Mac |
| Correctness | IDE-PANEL-21: Windows scenarios покрыты; Ubuntu/Mac Not verified |
| Coherence | Соответствует design: state transitions, backend content, Edgy geometry; новых managers/deps нет |

## Evidence

Source 3ef37e0: final panel-transitions12 RED/1 control, dap-tab-scope1 RED.
Второй обнаруженный дефект PTY — Show при чужом видимом окне — отдельно RED
на промежуточном config-source1241505793500 после close fix, до open fix:
.tests/panels-dap-open-before-dap-tab-scope.test.txt, профиль1965903941300.
Это два этапа проверки IDE-110, а не два разных конечных теста.

Target: panel-transitions13 PASS, настоящий Rust/CodeLLDB/PTY1 PASS.
Предыдущие13 suites/53 checks PASS: Debug, Output/PTY, Code focus,
Outline/late tree, Files, Tests/Search/Tasks, Terminal/Trouble, Logs/late F5,
frame pilot и native project/session/legacy restore. Итого67 различных
Windows editor checks. Unit360+trace11 PASS, trace1 SKIP; OpenSpec strict96 PASS.
Это выбранный regression, не global full suite или физические клавиши.

Audit .tests/panels-evidence.py / panels-evidence.json проверяет66 profiles:
14 source,14 target,38 regression. Exact saved test bytes и normalized config
SHA; source/target различаются только ожидаемыми4 runtime files. Registry,
guard, DAP backend, frame pilot, lock прежние. Root exit0/signal0/APIerrors[],
без root hard kill; owned scopes empty, временные Windows runtime удалены.
Native session controller уже получает exited после пользовательского quit:
для этих5 profiles проверены Quit/VimLeave0 в native trace, а не повторный quit
из controller. Сам SDK прежний:74AFF15B3B6BC288753B721365B088AB44C9B2BFFF152F8D27F5885B4B1C6AD9.

Новые тесты ждут source/строки первого дерева и обработку ввода через F35;
nvim_input сам подтверждает только приём клавиш. Для двух вкладок используется
tabpage_list_wins, поскольку общий has_window намеренно смотрит все вкладки.
Ранний вариант hide fixture попадал в штатный late-tree cleanup; финальный
проверяет явный Files + native Locals. Это уточнения подготовки E2E.

## Mapping

| Scenario | Implementation | Permanent E2E |
|---|---|---|
| Native open/hide/toggle/focus/cycle | state.refresh_slot/show/hide/toggle/focus_slot/cycle | panel-transitions |
| Замена, точечный hide, same-window adoption | state.close_active, source-specific init close; controls без fallback | panel-transitions |
| Code layout и toggle snapshot | state.apply_layout/toggle_panels | panel-transitions |
| Другие вкладки, PTY/channel/pause/stdout | init dap.terminal open/close current tab | panel-transitions + dap-tab-scope |

Activities передаёт зарегистрированные компоненты в state. Legacy/popup
filetype cleanup и current-view q для Terminal/Trouble сохраняют отдельную
роль. Main discovery, registry/guard, SDK и dependency pins не переписаны.
В4 runtime files52 add/65 delete, net−13; ускорение по LOC не заявляется.

## Outstanding

2026-11-12: cached Ubuntu engine готов, Desktop/WSL не управлялись. Полный
source3ef37e0:12 RED/1 control + tab-scope1 RED; saved config/test SHA и
same-container root/API/scopes/runtime проверены. Whole target7aa0ba9:
12 PASS/1 FAIL + tab-scope1 PASS — новый IDE-116, поздний Files focus.
После fix-panel-restore-focus обе ОС проходят13 переходов + tab-scope1;
первая общая ошибка сохраняется в отчёте, а не заменяется повтором.

CRITICAL:2.1 — выбранный regression остаётся FAIL: Ubuntu scope probe
IDE-117, Windows RPC stall IDE-118.2.2 — actual Mac/physical keys.
Общие результаты, source identities и ограничения аудита описаны в
verification fix-panel-restore-focus и FIXLOG §192–193. Archive не заявляется.
