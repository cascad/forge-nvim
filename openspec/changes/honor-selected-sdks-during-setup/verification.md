# Verification — 2026-11-18

IDE-BOOT-39 / IDE-TEST-10. Блок завершён. Windows24 PASS; Ubuntu23 PASS и один
Windows-only SKIP (caller PowerShell restoration), целевой aggregate. Полный
regression не запускался; его планы проверены на Windows и Ubuntu. Mac отдельно.

## Что проверено

- Native setup7: выбранная venv/Node с пробелами, отсутствие выбора, ненужный
  язык, invalid path, Node без npm, unsupported executable, late Mason snapshot.
  Настоящий pinned Mason process/spawn запускает native Python/Node с captured
  env, даже после восстановления текущего PATH в actor. Prefix venv и физический
  interpreter подтверждены, stdout не заменяется. Installs/downloads отсутствуют.
- Batch unit3: точный file selection, unknown/duplicate rejection, OS suites,
  native installer inventory, CLI dry plan/generated registry/filter clearing.
- Legacy setup7: реальные Windows/POSIX entrypoints,3 stages, negative readiness
  и backports; tools install command/readiness — контролируемые fixtures.
- SDK state7: native private install/launcher, SDK homes/env/defaults/project
  venv/queries и настоящий Lazy config/lock/rtp; Ubuntu caller case Windows-only.
  Это orchestration/env acceptance, не full installed IDE readiness.

## Raw logs и результаты

Все raw logs: `.tests/toolchain-research/`.

| Проверка | Windows | Ubuntu |
|---|---|---|
| Первый пакет | setup-sdk-batch-windows.txt | setup-sdk-batch-ubuntu.txt (остановлен собственный контейнер) |
| Исправленный пакет | setup-sdk-batch-fixed-windows.txt | setup-sdk-batch-fixed-ubuntu.txt |
| Только failed case | setup-sdk-lazy-fixed-windows.txt | setup-sdk-selected-fixed-ubuntu.txt |
| Большой dry plan | setup-sdk-regression-plan-windows.json | setup-sdk-regression-plan-ubuntu.json |

Batch reports: Windows `.tests/batches/1794986602487869900/` — registry3+7 PASS,
legacy setup7 PASS. SDK-state first6 PASS в1794986324373573100/02.log; failed
native Lazy после fixture fix —1 PASS, work `.tests/install-isolation/1794986643174604600 ü space`.
Ubuntu `.tests/ubuntu/batches/1794986615659721312/`: unit3 PASS, SDK6 PASS/1 failed
alias assertion; legacy7 PASS; SDK-state6 PASS/1 Windows-only SKIP. Только
selected retry —1 PASS, `.tests/ubuntu/setup-sdk/1649506281796 space`.
Current working tree full plans:121 Windows /120 Ubuntu registry files +22
native installer suites в первом плане. Final inventory также включает отдельный
release-inventory.test.py: всего23 native Python suites; counts включают прежние
WIP entries, не новый PASS. Dry-plan unit проверяет наличие release inventory.

## Причины отказов и коррекции

1. Generated Lua registry был записан одной writefile строкой с embedded LF,
   превратившимися в NUL. Запись разбита на строки; plan проверяет loadfile до
   E2E. Fast unit теперь также проходит этот путь.
2. Windows PowerShell5 удалил двойные Lua quotes в --cmd. Использованы single
   Lua quotes, source paths передаются через env без интерполяции в Lua.
3. Старые fixtures не копировали native_tools/parser_runtime, нужные нынешнему
   setup/Lazy. Добавлены настоящие модули, readiness assertions не ослаблены.
4. Batch перезаписал guest temp на Windows bind mount. Existing
   FORGE_INSTALL_STAND_ROOT перенесён в scoped guest /tmp, FORGE_TEST_TMPDIR
   сохраняет prepared temp. Только evidence копируется в host artifacts.
   Initial container остановлен по точному ID bcb4b802118a после docker top;
   Desktop/WSL не останавливались. Исходный SDK-state начал первый case после
   нескольких минут; исправленный весь файл занял18.34s (7.31s сами cases).
5. Ubuntu native provider штатно выбрал venv/bin/python3 вместо venv/bin/python.
   Prefix уже был правильный. Assertion сравнивает physical executable плюс
   прежний точный venv prefix; повторён только selected case. Production logic
   здесь не менялась. Windows прошедшие cases не повторялись.

## Границы

Mason сохраняет native package compatibility policy; это PATH preference до
snapshot, не private Python provider override. Installer --sdk-path остаётся
fallback, frontend/preflight ещё не читает runtime choices. SDK/provider update
policy/Go build toolchain/full Default/publication и physical Mac отдельно.
Были только existing deps/offline image, no build/pull/SDK installation. Host
temp/cache на F; guest private stand scoped. Полный tests/run/catalog WIP
не менялся и не коммитится. Strict/diff/frozen25/append-only prefixes/exact
owned index проверяются перед local commit.
