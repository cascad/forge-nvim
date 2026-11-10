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

Артефакты: `.tests/ide088-docker-evidence.json`, `ide088-docker-processes-*.json`,
`ide087-process-parent-audit.json`, `ide088-ubuntu-run.txt`; первый event —
`.tests/ide086-docker-interruption.txt`. В persisted выжимке нет auth/settings
payload. Эти локальные данные не заменяют постоянный regression при исправлении.
