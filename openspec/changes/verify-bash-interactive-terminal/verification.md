# Verification — 2026-11-13

## Result

Windows21 distinct selected PASS/0 FAIL/0 SKIP; Ubuntu21 PASS/0 FAIL/0 SKIP.
Windows: последние7 Bash cases и14 неизменных Bash-language/DAP-panel controls.
Ubuntu: все21 в одном итоговом script. Полный regression PASS не заявлен;
неизменённая версия ради зелёного не повторялась.

- bash-interactive.test.lua:4 cases — Unicode stdin, keyboard scroll/search,
  возврат к вводу, normal exit и Stop из terminal-mode при read. Независимый
  Editor child остаётся live; fixture Unix PID проверяются до Editor stop.
  Явные Lua SDK prepare/guard/repeat/unknown/no startup или F5 writes;
  CLI LF/CRLF apply/repeat/unknown preservation.
- bash-debug.test.lua:3 — прежний native default/edit-repeat/launch.json/Stop
  и missing adapter/Node. Bash-language8, debug-panels6.
- По15 native profiles: exit0/signal0, APIerrors[], hard_kill=false,
  scope ok/active_after0. Runtime source,67 pins/6 plugin backports16 files
  сверены; Windows nvim SHA74aff15b прежний.

Ubuntu input17188896812659: Editor15, debugger56/parent55, Node24 live после
exit. Stop17193691836694: Editor3080, debugger3121/parent3120, Node3090 live.
Обе backend пары отсутствуют до закрытия IDE. Windows21635357162800/
21646432086700 подтвердили то же через WSL. Normal output без Killed,
scrollback остаётся доступным поиску.

## Source / Iterations

Original Windows2 PASS ещё не включал sentinel. Первый Ubuntu0/2 выявил две
ошибки наблюдения: mutable frame table через RPC и ожидание завершения Editor
PPID. Исправлены bool-result/owned PID list. Source sentinel15383345973860
затем FAIL: Editor15, Bash54/PPID15, посторонний Node24 исчез после Stop
(jobwait=-3). Это IDE-128, не общий диагноз прежних системных зависаний.

Официальный0.3.9 disconnect делает pkill по PPID debugger. Native Bash -c
exec-оптимизация превращает в этого родителя Neovim. Upstream src/bashDebug.ts
blobb27ee925edceca7d803cb78637e828f3cccc2a43 сохраняет ту же логику:
https://github.com/rogalmic/vscode-bash-debug/blob/master/src/bashDebug.ts

Первый command patch сохранил отдельного родителя. Windows3/4 interactive,
old3/3 PASS: normal exit всё ещё оставлял Bash до Editor close. Adapter шлёт q
и сразу TerminatedEvent; pinned nvim-dap закрывает adapter по этому событию.
Промежуточный teardown Windows21/21 PASS показал вводящий в заблуждение Killed
при успешном exit. Конечный второй fragment ждёт native bashdb That's all,
folks..., останавливает только proxy children, затем шлёт TerminatedEvent.
Новых protocol/polling/tree walker/proxy/process manager нет.

Final OpenVSX JS normalized SHA f231e6118693fbc4b30763e7aa30431af9b0cd3d5e95fd8564ddc1eaca7b1b88;
Mason/GitHub JS f85047f8c035d9ca1a89d9988f03ffd0cacec0abad25d897e1f89ca2e862ba7d.
Original archive/before/after hashes и две точные замены — bash_debug_patch.json.
Extra official Mason CLI LF/CRLF/apply/repeat/unknown PASS. User cache не менялся.

## Artifacts / Limits

Raw .tests/bash-isolation-ack-windows/{bash-interactive,bash-debug}.txt,
.tests/bash-isolation-final-windows/{bash-language,debug-panels}.txt,
.tests/bash-isolation-ack-ubuntu/run.txt; audit .tests/bash-isolation-audit.json.
Source .tests/bash-interactive-{windows,ubuntu}, sentinel-ubuntu и
bash-isolation-windows сохранены вместе с промежуточным final-windows.
Compose отверг --no-build до выполнения; затем private script CRLF дал shell
ошибки до Editor tests. Оба raw error сохранены отдельно; script исправлен на LF.

Команды: <nvim> -l tests/e2e/bash-interactive.test.lua и bash-debug.test.lua.
Явный SDK: python -B tests/e2e/prepare_bash_dap.py --download;
установленный Mason: :BashDebugPrepare. Startup installs/writes нет.

Docker: existing imagef63a05ca/network none, offline VSIX/private Neogit overlay.
Build/download/Desktop/WSL lifecycle не выполнялись. Dockerfile late metadata
COPY добавлен, чистый image build не проверен. Mac/physical/cold WSL/UNC/custom
mounts/full Locals открыты. IDE-127 explicit console ENXIO видим и отдельный;
старые IDE-117/121/124 не закрыты.

.tests/bash-interactive-prefix.json защищает append-only journals/frozen drafts/
lock/SDK. Exact staging исключает frozen catalog/probe; registry index содержит
только новую строку поверх HEAD6e74859. Документ переведён на русский без смены
технических фактов при следующем обновлении истории (§218).
