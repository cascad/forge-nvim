# Verification: respect-terminal-platform-shell

2026-11-11, openspec-verify-change. Прочитаны proposal/design/spec/tasks из
CLI contextFiles, сопоставлены с runtime/test diff и native source/current
artifacts. Это доступные Windows/Ubuntu проверки, не готовность к архиву.

| Измерение | Результат |
|---|---|
| Completeness | 3/4 tasks; IDE-PANEL-19 реализован, task1.4 открыт |
| Correctness | 1/1 ADDED requirement найден в plugins/terminal.lua; все4 сценария покрыты native POSIX/Windows branches. Native Mac/physical GUI не проверены |
| Coherence | Один OS guard в существующем boundary, public ToggleTerm/job/file effects, private PATH до startup; нет global shell/runtime wrapper или нового framework |

Mapping: shell expression в nvim_forge/lua/plugins/terminal.lua;
tests/e2e/terminal-shell.test.lua в registry,4 platform cases. POSIX bash
с private executable pwsh fixture и sh без него; Windows actual Store
PowerShell7.6.9 (PSEdition Core) и native cmd fallback. По2PASS/2opposite-OS
SKIP на ОС. Shell command files доказывают выполнение, q/reopen сохраняет
PID/channel/buffer/history и следующая команда пишет FORGE_AFTER. Global
shell прежний, installs0/DAP false. Fixture LF закреплён для bind mount.

Source2fb9f8d Ubuntu —1RED/1control, реальный shim PID/argv и пустой
BASH_VERSION после ошибочного выбора; Windows source —2 controls PASS.
Current —31 positive native checks/profiles на ОС и29 прежних terminal/tool/
buffer/work checks в их числе. Вместе с source66 profiles: root0/signal0,
APIerrors[], native QuitPre/VimLeavePre/VimLeave, scopes empty; две Ubuntu
owned groups завершены graceful SIGTERM, hard-kill root нет. Точные test/
driver/fixture copies и63 normalized runtime/pin/patch sources сверены.
Quick360/trace11 +1manual-link SKIP на ОС, strict90. SDK/pins прежние.

Evidence: .tests/terminal-shell-evidence.json, audit.py, source/current logs,
native terminal-shell.json/kind/again files. Early F35 barrier failure,
Store-alias SKIP и replay orchestration LASTEXITCODE описаны в FIXLOG175;
они не названы product failures/green wrapper результатом. Итоговая native
проверка основана на индивидуальных logs/exits и source audit.

**CRITICAL для архива:** task1.4 не завершён. Пройти native Mac/physical GUI
с фактическими shell/keys результатами и повторить verify перед archive.
Там checks Not verified; одинаковая POSIX ветка не считается запуском Mac.
В проверенных средах нет новых code/design divergences или пропущенных
сценариев. Change остаётся открытым, никаких main specs не синхронизировалось.
