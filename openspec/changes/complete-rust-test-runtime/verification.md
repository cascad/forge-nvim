# Verification — §289, 2026-11-18

## Result

Rust Tests готовятся отдельно от SDK через официальный upstream binary installer
в обычный Cargo home. Ready версия/явный executable переиспользуются; конфликт
не перезаписывается. Shared Lua resolver используется frontend/setup/runtime.
Opening/discovery не выполняют version probes/downloads. Native Neotest RunSpec
получает выбранный executable; публичные run/run_last/Run all проверяют prerequisite
до native run state. Cargo/CodeLLDB debug не требует nextest.

На прежнем neotest-rust pin root-file filter выбирает actual discovered IDs и
нужный Cargo target. Previous SHA поддерживает upgrade прежней подготовки;
companions/lock/SDK не менялись. Это исправление IDE-TEST-3, не новый adapter.

## Affected packet

Один coherent пакет каждой ОС: rust-test-runtime(5), rust-language(15),
plugin-backports(16), go-rust-paths(7), setup-sdk-paths(7), trace(8+2 info SKIP),
install-nextest(10), install-sdk-settings(12), install-sdk-actions(12).

- Windows `.tests/batches/1795024355458326500`: initial Rust3 PASS/2 FAIL,
  installer7 PASS/3 FAIL, остальные PASS. Далее только failed/affected repeats.
  Итоговое покрытие этих cases:58 source +34 native installer PASS,2 info SKIP,
  **aggregate**, не единый повтор полного пакета.
- Ubuntu `.tests/ubuntu/batches/1795027649048450487`: все9 файлов PASS,
 58 source +34 native installer,2 info SKIP. Registry162.72s; installers
 25.40/25.10/33.34s. Existing native image,2CPU/3GiB; сеть только для явно
  включённого official installer case. Обычный offline режим этого case — SKIP.
- Windows failed Rust run/run_last/Run all guards исправлены через public consumer
  API. Последний missing-tool case затем выполнил все assertions, но Neovim
  не завершился за2s; native signal15, артефакт43178795119400 сохранён. Тот же
  case без ослабления deadline PASS в44086422881800; причина первого cleanup
  timeout неизвестна, продуктового исправления этой причины не заявляем.
- Windows installer03 исправлен JSON ensure_ascii=False;08 — неверный raw ANSI
  URL assertion. Official10 выявил смешивание PowerShell7 modules с WinPS5.1
  в изолированном USERPROFILE. Python copied env имеет uppercase PSMODULEPATH:
  прежний pop mixed-case ничего не удалял. Case-insensitive удаление только в
  стенде/observer даёт native Get-FileHash. A/B native-scope logs сохранены;
  upstream script не менялся, SHA verification не обходилась.
  Official10 PASS в install-isolation/1795027824334184200 ü space,27.04s;
  actual cargo-nextest0.9.152, repeat сохраняет SHA/версию. Ubuntu тот же install
  и repeat PASS; inherited NEXTEST_INSTALL_DIR не меняет reviewed target.
- Дополнительные affected controls: Windows прежние Rust nearest/file,
  integration и debug-nearest3 PASS; Go/Python/Node public Run3 PASS.
  Ubuntu Rust controls включены в15 cases, Python/Node public Run ещё2 PASS.
  Первые два прямых Ubuntu control вызова выбрали0 cases из-за default ID
  контейнерного wrapper; они не засчитаны. Повтор с explicit IDE-PY-1/
  IDE-NODE-4 действительно выполнил по1 case, logs *-selected.txt.

Синтаксическая ошибка временной PowerShell TLS строки исправлена до сборки и
запуска; upstream вызывается рекомендованным Invoke-Expression. Неуспешные CLI
invocations (comma-array/неверное имя test method) не запускали тесты и сохранены
отдельно. Общий full/regression не повторялся.

## Actual installed acceptance

Source/Core/Terminal archives и native frontend, реальные67 Git plugins/20 Mason
packages, готовые SDK и cached inputs прежнего §285. Новая nextest.lua явно
включена в временный source archive. Ready nextest установлен official script
в обычный Cargo home **собственного тестового пользователя**, вне kit/PATH.

| Проверка | Windows | Ubuntu |
|---|---|---|
| Default archive upgrade |23.03s PASS|7.88s PASS|
| Custom Core archive upgrade |15.47s PASS|3.90s PASS|
| Rust DAP breakpoint/eval42/continue/stdout, Neotest1 PASS/0 FAIL/output |4.67s PASS|3.02s PASS|
|20 Mason receipts |unchanged|unchanged|

Windows installed stand `.tests/default-acceptance/windows-x64/1795014050793199700`;
runtime report `installed-workflows/1795027928879135200/observed/report.json`.
Ubuntu exported stand `.tests/ubuntu/default-acceptance/linux-x64/fride-default-f3fzzdaq`;
runtime report `installed-workflows/1795027921352451075/observed/report.json`.
Reports include actual nextest path/version, eval42, test counts/stdout,
native cleanup exit0/signal0. `rust-upgrade-acceptance.json` preserves receipts
count and profiles.270 regular report/log files exported via copyfile, no venv/
symlink/project/chmod copy. Вместе с Go/Python/Node §288 four-language installed
workflow имеет actual PASS; исходный Rust RED §288 сохранён.

## Cleanup and bounds

Owned preparation container261d5816a414f51e83c37bbb5cbf8057b45be2f6cc85a416b06e7abd07b60f14
остановлен после проверки exact ID/owner label и export; штатный --rm удалил его.
Первый мгновенный poll был раньше завершения removal; следующий docker ps пуст.
Desktop/WSL/чужие containers не запускались, не останавливались и не менялись.

Ранее automatic review дважды отклонил удаление incomplete host project:
`.tests/ubuntu/default-acceptance/linux-x64/fride-default-f3fzzdaq/installed-workflows/1795021147210439842/project`.
Ответ только `blocked by policy`, без подробной причины. Остаток не удалён,
другим инструментом/обходом удалять не пробовали.

Native Mac, Windows WSL/Bash debug, Terminal GUI, cold SDK bootstrap и публикация
артефактов остаются gates. Ни cached acceptance, ни source E2E не объявляют их
проверенными. SDK рабочей машины/пользовательский Cargo home не изменялись.
FIXLOG289/commands197/history/guides фиксируют причины и этот вывод.

Final checks: Python AST и Lua loadfile PASS, trace8 PASS/2 info SKIP, оба
изменённых OpenSpec changes strict valid, git diff --check PASS. Frozen SDK/
старый UI/Cargo.lock/lazy-lock неизменны; registry меняет только новый case,
plugins.json только rust primary/previous. Current Windows/Linux frontend
source manifest и binary SHA совпадают. Raw и staged FIXLOG/commands append-only,
в index только38 перечисленных owned файлов. Local commit без push;
2.1 остаётся открытым, change не архивируется.
