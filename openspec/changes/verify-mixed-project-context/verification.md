# Verification — 2026-11-13

Windows current9 PASS: mixed1 + Python8 (первые6 до owner pause, последние2
после resume через FORGE_PYTHON_CASE=IDE-DAP-5, без повторов). Native source
copies exact, exit0/signal0/APIerrors[]/scope ok. Финальный Ubuntu mixed+Python8:9 PASS, runtime Node/DAP copies exact,
native exits/scopes ok. Task1.2 закрыт после подтверждения владельцем engine.
Mac/physical и полная mixed Tests/rename/format/debug matrix не проверены.

## Подтверждено

- IDE-120 source23787689169800:4 LSP attach, Bash cmd(config.root_dir) fail.
  Directory fallback native fs_stat устраняет пропуск root/node_modules.
- Current mixed24822402791700:6 LSP/root/cwd, npm script cancel/select/cwd,
  nested Python venv/program/cwd/pause/output/continue/Go return, installs0.
  Native adapter budget30, event_initialized elapsed6716.4057ms > прежних4s.
- Windows Python8 profiles24875806548400,24957451926600,25022619776600,
  25088047040100,25135785752100,25155426047000,1242887837200,1280423674900.
  Последний case сохраняет настоящий adapter error/exit, не ждёт30 секунд.
- Ubuntu до Python budget17 PASS: mixed1/Node8/Bash8. Native exits/scopes ok,
  node.lua exact current; mixed16137869042836. Это не final Ubuntu Python budget.
- Windows прежние Node7 PASS/1 FAIL и Bash7 PASS/1 FAIL: native quit IDE-121,
  profiles24015434532700/24391104731200. Functional flows завершились; source
  deadline/SDK не менялись, failure не замаскирован повтором.

## Отказы и пауза

IDE-122 source23950668148100, diagnostic24472874457100. DAP timer4s покрывает
initialize+launch; debugpy initialized adapter D+4.136 после warning Press ENTER.
Standalone stdio initialize PASS, источник timeout найден в native session.lua.
Не утверждается pipe/ConPTY defect. Logs заранее сохранены даже при blocking RPC.
User pause2026-11-12 остановила controller32948/его descendants; незаконченный
Python driver INTERRUPTED, не product FAIL. После restart HEAD/results проверены.

## Артефакты и границы

.tests/mixed-project-{windows,target-windows,logs-windows,ubuntu,cold-python-windows}
и mixed-project-python-remaining-windows. Audit .tests/mixed-project-audit.json:
source/runtime SHA, states/timing, native shutdown/scopes,9 Windows PASS.
FIXLOG209–210/commands120; raw prefixes .tests/mixed-project-prefix.json.
SDK SHA74AFF15B3B6BC288753B721365B088AB44C9B2BFFF152F8D27F5885B4B1C6AD9,
67 plugin pins/6 patched dependencies прежние. Два completed tasks восстановлены
из cp1251 roundtrip в UTF-8, без переписывания журналов. Старые infra drafts
не входят в index; partial registry только mixed row поверх HEAD. Push нет.

Windows срез704044e первоначально содержал открытый task1.2. После engine
availability 2026-11-13 финальный mixed+python-language дал9 PASS, profiles
165377278508 и172404999344/178421438467/183972486640/189301809230/194465187763/
203114926106/208784464094/215653556525. .tests/mixed-rebase-final-ubuntu,
новый audit mixed-project-audit.json и append-only FIXLOG211. Private Neogit
6/14 overlay обслуживал параллельный Git change; Node/DAP sources exact.
Прежние native gates IDE-117/121 не закрываются этим результатом.
Следующая независимая очередь4 — interactive rebase editor, spec-driven test-only.
