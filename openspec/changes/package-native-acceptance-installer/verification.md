# Проверка package-native-acceptance-installer

Дата2026-11-20, source f5b012b. Это отдельный приёмочный delivery этап,
не full regression и не native macOS/GUI acceptance.

## Реализовано

- Publisher stand использует существующие Core/Terminal/frontend packagers;
  official POSIX Neovim получает отдельный pinned input, system nvim не меняется.
- Local bundle с full files SHA, tracked allowlist, current frontend receipt;
  native PowerShell/Bash entrypoints вызывают прежний installer.
- Custom Core-only фильтрует Terminal files/probes/PATH и launcher даже из полного
  monolithic local runtime. Copy выполняется по выбранному manifest.

## Проверки Windows/Ubuntu

| Проверка | Windows | Ubuntu |
|---|---|---|
| prepare-native-neovim tests | 6 PASS/1 explicit native POSIX SKIP | 7 PASS, включая official archive/native probe/repeat |
| package/entrypoint/frontend | 10 PASS aggregate | 10 PASS aggregate |
| native install/launch/repeat + Custom + foreign-files control | 3 PASS | 3 PASS |

Всего20 unique cases/ОС: Windows19 PASS/1 SKIP, Ubuntu20 PASS. Package cases
используют настоящий frontend и shell, fixture runtime; это не полный installed
IDE. Отдельные3 cases используют настоящий private Neovim/install backend и
fixture config/setup, проверяют реальный kit/launch и сохранение user files.

Первичный package packet: Windows7 PASS/3 FAIL, Ubuntu8 PASS/2 FAIL. В Windows
entrypoint не нашёл Get-FileHash; причина отсутствия cmdlet в child environment
не устанавливалась, вместо зависимости использован штатный .NET SHA256.
Ubuntu/positive Windows fixture не содержала components.tsv — исправлен stand,
проверка обязательного source файла добавлена в publisher. Windows только4
failed/affected cases повторены PASS; Ubuntu только2 failed cases PASS.

Custom regression на source дал RED: backend попытался выполнить probe снятого
Terminal (EFTYPE на not-selected.txt). После фильтрации target3 PASS на каждой
ОС: новый Custom, обычный install/launch/repeat, external user-file protection.
Первичные logs сохранены; полный пакет повторно не запускался.

Windows actual publisher из готовых native inputs прошёл: private Neovim0.12.2,
33 parsers/queries, rg и Terminal, source/frontend hashes. Получен2510-file
baseline bundle; actual entrypoint Default plan и native runtime/files/probes
прошли. Этот первый bundle source f5b012b предшествует Custom fix и не является
финальным кандидатом для передачи владельцу; refreshed candidate отмечается
отдельно после commit. Clean-machine PASS ему не приписывается.

## Результаты

Все host logs/temp на F, `.tests/acceptance-installer`:
windows/ubuntu-install-native-neovim.txt, windows/ubuntu-install-acceptance-package.txt,
windows/ubuntu-package-affected.txt, windows-custom-source-red.txt,
windows/ubuntu-custom-target.txt, windows-publisher.txt, windows-runtime.json,
windows-actual-plan.json и frontend manifests. Source RED и target controls
не объединяются в искусственный single-run PASS.

Native Linux frontend собран offline с existing vendored crates в own guest
`/tmp`,2 CPU/3GiB/network none; image/Desktop/WSL не перенастраивались.
Первый prepare указал удалённый vendor path; исправлен только stand на existing
`.tests/ubuntu/installer-ui/vendor.tar.gz`, affected build прошёл.
Native archive11,368,705bytes получен напрямую upstream; API lookup вернул403,
SHA сверены с official expanded_assets. Публичные каталоги пусты и не менялись.

## Готовая fzf-native library — решение владельца

Владелец выбрал publisher-built native library в Core и существующий Lua fallback.
Core packaging проверяет pin/source/SHA/platform и реальную загрузку/C ABI,
копирует library/metadata/LICENSE. Explicit plugin setup копирует её в data,
не запускает CMake/compiler; отсутствие Core library оставляет Lua fallback.
Прежний installed artifact не требует нового SDK, source startup не компилирует.

Новые реальные search cases: по2 PASS Windows/Ubuntu — отдельный native setup
process без CMake, затем TUI editor и C scoring/file/content navigation либо
Lua fallback. По1 прежнему native control и7 setup cases/ОС тоже PASS.
Source RED: прежний build вызвал недоступный cmake и завершил task с ошибкой.
Итог с первой таблицей:30 unique cases/ОС, Windows29 PASS/1 SKIP, Ubuntu30 PASS.
Это targeted aggregate; full regression не повторялся.

Затронутый tests/install-parser-runtime.test.py дополнительно прошёл4/4 на
каждой ОС: native Core packaging/HTTP/install/captures, incomplete/invalid
с сохранением прежнего kit, publisher revision/ABI controls и unmanaged command.
Его прочие plugins/Mason stages — fixture. Общий итог34 unique cases/ОС:
Windows33 PASS/1 SKIP, Ubuntu34 PASS.

Первый Windows target копировал/загружал DLL, но выполнял setup после загрузки
Telescope, который уже выбрал fallback. Подтверждено exists1/ffi_ok=true;
producer не менялся ради PASS. Test исправлен на production sequence отдельного
setup process и нового editor process. В minimal init добавлен loadplugins=true,
без него Lazy setup завершался до initialization; это ошибка stand. Ubuntu
prepared image содержал прежние known backports: current applier применён к
собственной копии, check receipt обновлён настоящим результатом.
Только failed/affected новые cases повторены.

Linux publisher сначала указал host-mapping paths без ubuntu prefix; исправлены
только paths стенда. Output на Windows bind mount медленно обходил файлы;
собственный процесс прерван SIGINT, context cleanup завершился. Тот же producer
с native /tmp output прошёл примерно за9s, итоговый archive перенесён на F.
Низкоуровневая причина FS-разницы не утверждается; product timeouts не менялись.

## Открыто

Native macOS publisher/GUI/clipboard/SDK paths, реальный рабочий проект владельца,
public bootstrap/release inventory/publication остаются отдельными gates.
Omarchy отложена по указанию владельца. Change не архивируется.

## Финальные gates и выдача

Strict OpenSpec PASS; project trace9 PASS, каталог158 REGISTERED/0 MISSING/
0 PENDING (регистрация, а не158 runtime PASS). Проверены append-only prefixes
FIXLOG/commands против f5b012b;66 pins,6 backports,4 frozen .tools files,
прочие SDK/installer UI/main specs/WezTerm неизменны. Python AST и diff check
выполняются перед commit, результаты final-gates.json.

После commit publisher собирает clean-source candidate в
`.tests/acceptance-installer/windows-ready`. Его source commit, manifest digest,
Default plan и native runtime probes сохраняются в `final-candidate.json`,
`windows-ready-plan.json`, `windows-ready-runtime.json`. Эти локальные artifacts
содержат фактический результат после сборки; baseline/draft выше не подменяют его.
Это комплект для приёмки владельцем, не опубликованный production release.
