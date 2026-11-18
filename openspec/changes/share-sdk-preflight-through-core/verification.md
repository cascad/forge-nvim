# Verification

## Изменение

IDE-BOOT-40, согласие владельца2026-11-18: сначала Core, затем shared Lua SDK
settings. Доставка/Core SHA/manifest/platform/pins/tree проверяются до SDK;
старый kit остаётся до SDK readiness. JSON/path semantics в Rust не копировались.
Source/init/plugins пользователя preflight не загружает; private setup читает
тот же user scope, обычный runtime сохраняет project→user.

## Native проверки

- Rust offline build Windows и Ubuntu с прежним Cargo.lock; Python/Lua syntax.
- Пакеты после целого кода: Windows `1794989295171684900`, Ubuntu
  `1794989347596062342`: setup SDK7 cases и6 native suites.
- Первый запуск поймал собственные ошибки extraction (exe path) и logging до
  setup; исправлены. Обновлены старые ожидания Core-before-SDK downloads и
  missing Terminal (отдельного Rust archive уже нет).
- Повторены только failed/affected: `shared-preflight-{windows,ubuntu}-retry.txt`
  в `.tests/toolchain-research`. Новые SDK settings: по10 PASS; настоящие
  Go1.26/Rust1.96.1/Node24.11/Python venv и контролируемые CLI failure fixtures.
- Windows дополнительно повторены parent env и scope всех3 setup stages:
  `shared-preflight-windows-{parent-env,stage-scope}.txt`, PASS. Ubuntu проверил
  final scope в большом checkpoint: SDK settings11 PASS (10 SDK+1 cleanup).
  Windows cleanup control отдельно PASS. Нативный Mac не запускался.

## Большой checkpoint

Ubuntu `1794989655059525809`:120 registry files+24 native Python suites, source
Core acceptance inputs подготовлены офлайн из native parser и cached LuaLS3.19.2
с проверкой сохранённого SHA. Это source configuration, не installed Default.
Итог: complete=true/ok=false,2764.52s. Все24 native Python suites выполнены.
Registry:120 файлов/122 запуска —103 PASS/14 FAIL/5 SKIP,1851.05s;
1049 cases. Core acceptance5/5 PASS. SDK settings11/11 PASS. Полный PASS не заявлен.

Файлы с отказами registry; причины, кроме явно устаревшего SQL ожидания и
missing gopls в PATH, пока не подтверждены:

| Файлы | Наблюдение |
| --- | --- |
| test-runner.test.lua | gopls не найден в PATH/Mason при debug nearest |
| ide-logs.test.lua, ide-log-sources.test.lua, debug-focus-order.test.lua | missing Node/recovery: нет warning либо hit-enter |
| node-language.test.lua | missing adapter/Node: нет notify, блокирующий prompt |
| bash-language.test.lua, bash-debug.test.lua | missing tools/adapter/Node: notice/prompt |
| rust-language.test.lua | не получена Cargo diagnostic без Clippy |
| ui-capture.test.lua | Native scroll was not exercised |
| dap-launch-routes.test.lua | project args не переданы |
| mixed-project.test.lua | старое ожидание sqls при текущем Sqruff |
| gitsigns-live-read.test.lua | Git show при удалении worktree |
| posix-scope-probe.test.lua, tests/trace.test.lua | существующий WIP, не редактировался |

Перечисленные E2E находятся в tests/e2e; trace — tests/trace.test.lua. Полный
raw report: `.tests/ubuntu/report.json`, batch report/logs —
`.tests/ubuntu/batches/1794989655059525809`.

Native checkpoint первоначально дал6 failed suites. Пять исправлены через
обновление fixtures, без ослабления product readiness: merge Lua directories,
current setup dependency tree, явно controlled plugin_setup в parser stand,
Mason cmd=function в gopls observation, current explicit-path error, актуальные
SDK dependencies и выбор install log. Failed setUpClass теперь закрывает HTTP
через addClassCleanup; добавлен control. Уже завершившийся с ошибкой зависший
parser PID53737 остановлен SIGTERM только внутри own container; raw exit=-15
и235s сохранены. Docker/WSL engine не останавливался.

Affected повторы:
- Windows batch `1794992478419789100`: Parser4, SQL delivery5, readiness15+
  1 POSIX skip PASS; Search3 и UI4 PASS отдельно, gopls/missing-Node2 PASS
  (Windows entrypoint может быть штатным Mason gopls.CMD, не только .exe).
- Ubuntu batch `1794992697474789878`: Parser4, Search3, readiness16 PASS;
  UI4 и IDE tools2 PASS отдельно. SQL delivery уже PASS в полном checkpoint.
- Логи `.tests/toolchain-research/shared-preflight-*-fixture-final.txt`,
  `*-ui-controls.txt`, `*-tools-controls.txt`, Windows `*-tools-native-entry.txt`.

Оставшийся native gate: install-terminal-runtime.test.py не начал cases —
нет `.tests/ubuntu/terminal-runtime/linux-x64/prepared.json`. Fake terminal
вместо native inputs не подставлялся. Полный checkpoint после fixes не повторён:
повторялись только failed/affected suites/cases.

Windows — план121+24, ready=false без Core inputs; full не запускался,
поскольку registry включает также WSL.
Docker Desktop/WSL не запускались/не перенастраивались, build/pull не было;
использован существующий image с limits2CPU/3GiB. Host temp/artifacts на F,
guest SDK копии — /tmp. Ничьи lockfiles/native Neovim/WIP не менялись.

## Проверка изменений

OpenSpec strict и diff --check проходят. Frozen25/WIP совпадают с baseline
`.tests/toolchain-research/shared-preflight-baseline.json`. Финальные staged
allowlist35 и append-only prefixes проверены перед local commit; push не нужен.
