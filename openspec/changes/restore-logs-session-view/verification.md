# Verification — 2026-11-13

## Result

Windows10 distinct selected PASS/0 FAIL/0 SKIP, Ubuntu10 PASS/0 FAIL/0 SKIP.
Новый Logs workflow1 + session-files1/project-session1/legacy4/ide-logs3.
Windows controls9 один раз на конечном runtime; исправлен только UI fixture
нового case, затем выполнен он один. Ubuntu10 одним итоговым script.
По10 native profiles: exit0/signal0/APIerrors[]/hard_kill=false/scope empty.
Полный regression PASS и native Mac/physical не заявлены.

## Evidence

- Source22494463154400 RED: после quit/relaunch два Logs окна закрыты,
  source/minimum/query сброшены. До quit heights18/14, разные view/scroll.
- Target22642014015600: restore/A→B→A/скрытые filters/refresh уже прошли,
  весь E2E FAIL по UI fixture. Host45 оставлял native child42, как до resize.
  Тест уменьшает относительно saved.lines и сохраняет реальные JSON sidecars.
  Runtime не менялся, неизменённого green retry нет.
- Final Windows22801368794900 и Ubuntu main из target-ubuntu:6 различных
  native PID на quit/relaunch/restart, code focus, installs0, views равны до/
  после переходов. Общий фильтр B возвращается и при всех скрытых окнах.
  Refresh сохраняет читаемую строку. Малый UI42→29 адаптирует height18→12.
- Actual version1 sidecars содержат один общий source/minimum/query и per-tab
  geometry; A/B различимы, скрытый tab=false. Старые native legacy/file restore
  проходят controls. Чтение прежнего Files-only формата допускает nil Logs;
  отдельной миграции/нового backend/процессов нет.
- Source modules Logs/session_views/editor и67 pins/6 plugin dependencies16
  files сверены, старого runtime session_files.lua больше нет. Nvim SDK SHA
  74aff15b прежний, frozen drafts не менялись.

## Commands / Artifacts

`<nvim> -l tests/e2e/session-logs-view.test.lua` после обычной подготовки plugins.
Также session-files-view/project-session/session-legacy/ide-logs — теми же
отдельными `nvim -l` командами; новый SDK/tool/network не нужен.
Raw .tests/session-logs-source-windows/run.txt, target-windows/*.txt,
resize-windows/run.txt, target-ubuntu/run.txt. Audit .tests/session-logs-audit.json
проверяет реальные verdicts/profiles/native host/views/metadata и prefix guards.

Docker использовал existing imagef63a05ca/network none/private Neogit overlay;
build/download/Desktop/WSL lifecycle не выполнялись. Windows и Ubuntu serial.
По одному прогону версии; source/fixture FAIL сохранены. Mac/physical и
остальные панели WF-01 открыты, старые IDE-117/121/124 этим PASS не закрыты.

История FIXLOG218, commands126, HISTORY/guides/roadmap обновлены. Baseline
.tests/logs-session-prefix.json: журналы append-only, frozen5/lock/backports/SDK
exact. Registry index содержит только new Logs row поверх текущего HEAD;
frozen2 строки остаются working copy, полный test runner не использовался.
