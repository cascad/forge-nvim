# Verification — 2026-11-13

## Result

Windows21 distinct selected PASS/0 FAIL/0 SKIP; Ubuntu21 PASS/0 FAIL/0 SKIP.
Windows latest7 Bash cases plus14 unchanged Bash-language/DAP-panel controls;
Ubuntu all21 in one final script. No full-suite claim, no unchanged green retry.

- `bash-interactive.test.lua`:4 cases. Unicode stdin, keyboard scroll/search,
  return to input, normal completion and Stop from terminal-mode while read waits.
  Both retain a live independent Editor child and check owned Unix PIDs before
  Editor stop. Explicit Lua SDK prepare/guard/repeat/unknown/no startup or F5
  writes; CLI LF/CRLF apply/repeat/unknown preservation.
- `bash-debug.test.lua`:3 existing native default/edit-repeat/launch.json/Stop
  and missing adapter/Node controls. `bash-language`:8; `debug-panels`:6.
-15 native profiles per OS: exit0/signal0, APIerrors[], hard_kill=false,
  native scope ok/active_after0. Runtime source,67 pins/6 plugin backports16
  files checked; Windows nvim SHA74aff15b unchanged.

Ubuntu input17188896812659: Editor15, debugger56/parent55, independent Node24
live after exit. Stop17193691836694: Editor3080, debugger3121/parent3120,
Node3090 live after Stop. Both owned pairs absent before Editor shutdown.
Windows21635357162800/21646432086700 establish the same across native WSL.
Normal exit output has no Killed message; scrollback remains searchable.

## Source / justified iterations

Original Windows2 PASS did not yet include the sentinel. First Ubuntu0/2
exposed two observer mistakes: whole mutable frame table over RPC, and waiting
for Editor PPID to die. Corrected to bool and owned PID list. Source sentinel
Ubuntu15383345973860 then failed: Editor15, Bash54/PPID15, unrelated Node24
disappeared after Stop (`jobwait=-3`). This is IDE-128, not a broad system diagnosis.

Official0.3.9 JS disconnect runs pkill against debugger PPID. Native Bash -c
exec optimization makes Editor that parent. Upstream src/bashDebug.ts
blob b27ee925edceca7d803cb78637e828f3cccc2a43 retains the same logic:
https://github.com/rogalmic/vscode-bash-debug/blob/master/src/bashDebug.ts

First SDK command patch retained a private parent. Windows3/4 interactive,
old3/3 passed: normal exit still left Bash waiting before Editor close.
Adapter sends q then immediately TerminatedEvent; pinned nvim-dap closes the
adapter on that event. Intermediate teardown Windows21/21 passed but showed
misleading Killed on normal exit. Final second fragment waits native bashdb
"That's all, folks...", stops only proxy children and then emits TerminatedEvent.
No new protocol, polling tree walker, proxy or process manager.

Final OpenVSX JS normalized SHA f231e6118693fbc4b30763e7aa30431af9b0cd3d5e95fd8564ddc1eaca7b1b88;
Mason/GitHub JS f85047f8c035d9ca1a89d9988f03ffd0cacec0abad25d897e1f89ca2e862ba7d.
Both official original archive hashes/before/after and exact two replacements
are in bash_debug_patch.json. Extra official Mason CLI probe LF/CRLF,
apply/repeat/unknown PASS. Installed user caches were not modified.

## Artifacts / commands / limits

Raw `.tests/bash-isolation-ack-windows/{bash-interactive,bash-debug}.txt`,
`.tests/bash-isolation-final-windows/{bash-language,debug-panels}.txt`,
`.tests/bash-isolation-ack-ubuntu/run.txt`; audit `.tests/bash-isolation-audit.json`.
Earlier source `.tests/bash-interactive-{windows,ubuntu}`,
`.tests/bash-interactive-sentinel-ubuntu`, `.tests/bash-isolation-windows` and
intermediate final-windows preserved. Compose rejected unsupported --no-build
before running anything; next private script CRLF failed before any Editor test.
Both errors retained separately, then shell script normalized to LF.

Run directly after explicit prepared plugins/Node/Bash SDK:
`<nvim> -l tests/e2e/bash-interactive.test.lua` and
`<nvim> -l tests/e2e/bash-debug.test.lua`.
SDK preparation `python -B tests/e2e/prepare_bash_dap.py --download`,
installed Mason `:BashDebugPrepare`; no startup installs/writes.

Docker used existing imagef63a05ca/network none, cached offline VSIX and private
Neogit overlay. No image build/download, Desktop/WSL lifecycle changes.
Dockerfile late-layer metadata packaging updated; clean image build untested.
Mac/physical/cold WSL/UNC/custom mounts/full Locals remain open; IDE-127 explicit
debugConsole ENXIO is visible and separate. Old IDE-117/121/124 are not closed.

Append-only journals/frozen drafts/source lock/SDK guarded against
`.tests/bash-interactive-prefix.json`. Exact staging excludes frozen catalog/
probe changes; registry index contains only this new row over HEAD6e74859.
