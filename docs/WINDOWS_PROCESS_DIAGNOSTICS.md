# IDE-087: Docker и native process teardown

2026-11-10. Расследование открыто; исправление Docker/SDK не заявлено.

## Два события

| MSK | Наблюдение | Граница доказательства |
|---|---|---|
| 17:06:41 | com.docker.build exit status 15, backend/API остановлены; compose был только в 17:08:59 | Нет caller/kill PID, нельзя вывести причину по одному коду |
| 17:42:01 | CIM: backend 21656 → parent 22420, второй backend 24840 → 21656, build 20664 → 24840; creation около 17:12 | Исходный parent 22420 этим снимком не исследован; неизвестно, был ли он жив |
| 17:45:10 | Повтор com.docker.build exit status 15, backend остановлен | Совпало по wall time с native qa! profile 26725438645000, root PID 700 |
| 17:47:41 | Docker processes в повторном CIM не найдены, Linux pipe отсутствует; следующий compose не подключился | Контейнер не создавался; correlation не доказывает causation |

Cold UI profile 26725438645000 сохранил QuitPre/VimLeavePre/VimLeave,
exit_code/signal=0. В shutdown нет SIGTERM/SIGKILL, scope active_before=0,
terminated=false. Это исключает прямой signal/TerminateJob этого helper в
данном событии, но не исключает teardown дочерних jobs самим Neovim/плагинами.
Наблюдатель spawn сохранял argv, без PID дочернего CLI; точного kill target нет.

## Проверяемая гипотеза

Локальный pinned Neovim 4b35336f6f850ce68a230716401cdaa21bdb6a25 имеет в
`src/nvim/os/proc.c:os_proc_tree_kill_rec` рекурсивное сравнение
`pe.th32ParentProcessID == pid`, затем TerminateProcess. Creation times не
сравниваются. Файл не менялся нашим ConPTY patch: git status source показывает
только pty_proc_win.c. В просмотренном upstream master механизм тот же:
[Neovim proc.c](https://github.com/neovim/neovim/blob/master/src/nvim/os/proc.c).

Windows повторно использует PID. ParentProcessId может указывать на процесс,
который переиспользовал номер завершившегося родителя; Microsoft рекомендует
сравнивать CreationDate. [Microsoft Win32_Process](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process),
[process handles/IDs](https://learn.microsoft.com/en-us/windows/win32/procthread/process-handles-and-identifiers).

Отсюда гипотеза: новый CLI job получает номер старого родителя Docker, и
native tree traversal принимает старый Docker process за его потомка. Она
совместима с source и timeline, но пока нет доказательства, что такой PID
был выбран в этих двух событиях. Не называть это установленной причиной.

Read-only CIM audit 314 процессов после события не подтвердил пользовательских
stale edges. Две инверсии creation time у Secure System/Registry относительно
System — особые kernel records; их нельзя выдавать за воспроизведение PID reuse.
Security/Sysmon чтение не дало пригодного caller trace; отсутствие результата
не доказывает отсутствие события или включённого аудита.

## Следующие действия

1. Сохранить native source/hash, два host timestamps, process snapshots и
   editor shutdown; это уже сделано, FIXLOG §157.
2. Подготовить read-only/dry-run проверку ancestry и фиксирование creation times,
   без завершения чужих процессов и без массового churn PID на рабочем ПК.
3. Проверить механизм на собственных ограниченных native fixtures/SDK candidate.
   Любое исправление SDK требует отдельного change, source/pin/hash и regression;
   основной SDK и поведение Linux/macOS не меняются по одной гипотезе.
4. После проверки границы teardown вернуться к Ubuntu gate IDE-088 на engine,
   который включил владелец. Desktop/WSL агент автоматически не управляет.

## Native доказательство механизма — §158

Добавлены два независимых инструмента:

```powershell
python -B tests/diagnostics/windows-process-parents.py --output .tests/ancestry-read-only.json
powershell -NoProfile -File tests/diagnostics/build-process-ancestry.ps1
```

Первый читает Toolhelp snapshot, открывает query-only handles, держит их до
окончания классификации и получает native GetProcessTimes. В нём нет API
завершения процессов. `unknown`, `parent_missing` и `kernel_special`
выделены отдельно. Creation order — необходимая проверка, не полное
доказательство владения. [Microsoft GetProcessTimes](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes).

Первый native snapshot (18:14:50 MSK) обнаружил не-kernel инверсию: vctip.exe
PID 22640, parent 21796, creation 134387968496450016; под PID 21796 уже
python.exe с creation 134387972906175591. Разница около 441 s. Это реальная
несогласованная parent edge, а не контролируемый fixture. Self PID/source SHA
добавлены в audit после первого снимка; followup уже не нашёл живого parent
этой записи. Первый JSON не переписывался. Для Docker это не caller evidence.

Второй инструмент требует MSVC C++ Build Tools и существующий pinned SDK source.
Он извлекает точные две функции proc.c, сверяет revision/full source SHA и
компилирует native harness. SDK/исходный proc.c не меняется. Guard prototype
добавляется только в частный fragment: query должен быть успешен, child creation
не раньше parent. Неполные timestamps не разрешают обход потомка.

Каждый запуск создаёт три настоящих процесса под собственным Job Object:
older sibling, root и child, реально созданный root. Родство child проверяется
через настоящий Toolhelp, membership всех трёх — IsProcessInJob. Snapshot
для исследуемой функции контролируемый: в stale case меняется одна edge,
older sibling получает PPID root. Clock/PID системы не меняются; PID reuse не
провоцируется. Open/termination wrappers допускают только эти три held PID.

| Сценарий | Pinned upstream fragment | Guard prototype |
|---|---|---|
| Настоящий child, unrelated older sibling | PASS: root/child завершены, older жив | PASS с тем же полезным поведением |
| Older process с stale PPID root в snapshot | RED: older тоже получает exit 15 | PASS: older остаётся жив |
| Не удалось прочитать время child | RED относительно новой fail-closed политики | PASS: root завершён, child сохранён |
| Не удалось прочитать время root | RED относительно новой fail-closed политики | PASS: root завершён, child сохранён |

Два query-failure case — проверка новой политики при инъекции API failure,
не два отдельных установленных пользовательских бага. Stale edge демонстрирует
дефект traversal — IDE-089. Это native integration с реальными процессами/
timestamps/завершением, но контролируемым snapshot. Это не полный Neovim E2E
и не доказательство естественного PID collision в двух событиях Docker.

Финальные ASCII и Unicode/space build paths: по 8 executions (1 upstream PASS,
3 expected RED, 4 prototype PASS), по 24 собственных worker processes;
outside_attempts=0, scope_clean=true. SDK binary SHA до/после совпадает с
установленным manifest. Negative проверки отклоняют изменённый proc.c и build
вне .tests до создания output. Артефакты: `.tests/ancestry-native/final-ascii/`,
`.tests/ancestry-native/проверка с пробелами/`, evidence.json/source/binary hashes,
build logs и отчёты каждого case. Ранние пилоты без scope-clean assertion либо
SDK before/after hash сохранены отдельно и не подменяют финальные результаты.

## Альтернативный caller: приложение выполнения команд

Read-only осмотр установленного OpenAI.Codex 26.1103.4239.0 нашёл в двух bundle
функции вызова `taskkill.exe /pid <PID> /t /f`, timeout 2000 ms. В worker путь
условный: killProcessTree или processOwner. Это статический факт установленного
app.asar; он не доказывает использование данного пути нашим exec_command,
вызов в 17:06/17:45 или конкретный target PID. Пакет/настройки не менялись;
в artifacts сохранены только filenames/offsets/hashes/call shape, не bundle.

Официальные [Windows sandbox docs](https://learn.chatgpt.com/docs/windows/windows-sandbox)
и [troubleshooting](https://learn.chatgpt.com/docs/reference/troubleshooting)
не устанавливают caller этих событий. Bounded CIM ProcessStartTrace observer
не запустился (HRESULT 0x80041032); это не отрицательный trace taskkill.
Публичные похожие reports не используются как доказательство нашей машины.
Нельзя обещать, что одна поправка Neovim устранит все возможные caller пути.

IDE-089 исправлена в §159: отдельный Windows SDK process patch проверяет
GetProcessTimes обоих handles и child creation>=parent creation. Неизвестное
время пропускает связь; явно выбранный root завершается. Manifest Schema 2
связывает оба patch SHA, нормализованный proc.c SHA, binary SHA и probes.
Старый manifest больше не считается подготовленным SDK.

Явная подготовка собирает отдельный stage (parallel=2), выполняет native source
fixtures, реальные Neovim jobstop/quit и 50 ConPTY циклов перед продвижением.
`-StageOnly` оставляет кандидата отдельно. Продвижение использует rename внутри
checkout, отвергает reparse ancestors, сохраняет прежний SDK и откатывается,
если stage нельзя переместить. Существующий редактор не завершается ради замены.

Финальный Windows regression: 49 PASS (24 captured editor profiles, native
exit/signal 0, без API errors, own scopes после cleanup пусты). Actual patched
source guard: 4 PASS и 3 expected upstream RED. После выбора SDK: quick 353,
SDK CLI 11 и native lifecycle 2 PASS; strict OpenSpec 75/75. Два lifecycle
сценария проверяют гибель root/child до cleanup и выживание отдельного worker;
учёт Job Object может запаздывать после native exit callback, поэтому тест ждёт
опустошения Job до проверки отсутствия принудительного scope cleanup.

Первый Rust toggle regression один раз оставил sidebar; полный повтор на том
же SDK без UI/source изменений прошёл. Это IDE-090, причина открыта; первый
log сохранён, не объявлен исправленным. Артефакты §159:
`.tests/ide089-evidence.json`, `ide089-promotion.json`, `ide089-windows-*.txt`,
`ide089-selected-*.txt`, `.tests/neovim-native/stage-1618cc145fbf469b9f05a6247bb94b58/ancestry/`.

IDE-087 остаётся открытым, пока нет caller/target trace или отдельного
воспроизведения Docker. Linux/macOS не используют этот Windows SDK;
их process backend не меняется. Ubuntu engine отсутствовал при read-only
проверке; Desktop/WSL не запускались. Mac native не запускался.

Артефакты: `.tests/ide088-docker-evidence.json`, `ide088-docker-processes-*.json`,
`ide087-process-parent-audit.json`, `ide088-ubuntu-run.txt`; первый event —
`.tests/ide086-docker-interruption.txt`. В persisted выжимке нет auth/settings
payload. Эти локальные данные не заменяют постоянный regression при исправлении.
