# PROBLEMS — инбокс

Кидай сюда новые проблемы / хотелки в свободной форме (по одной на абзац).
После фикса они переезжают в `nvim_forge/FIXLOG.md` в формате
«Проблема → Решение → Файлы».

Для каждого исправления обязательны причина, изменение, проверка/e2e и
вывод. История читается через [единую хронологию](docs/HISTORY.md);
формат новой записи — [шаблон](docs/history/ENTRY_TEMPLATE.md).

Маршрут и приоритеты: [рабочий план nvim_forge](docs/IDE_ROADMAP.md).
Для новых пунктов используем следующий свободный ID `IDE-xxx`; исходный
симптом хранится здесь, этап и состояние — в плане. Следующий ID: `IDE-041`.

## IDE-038 — Windows: повторное удаление active worktree иногда даёт Permission denied

2026-11-02, интеграция IDE-035: после dirty cancel → внешний commit → visit
того же linked → повторное удаление Git вернул 255/Permission denied.
Лог показывает scheduled переход в main до remove; одно ожидание IDE-034
не доказывает отсутствие всех удерживающих каталог процессов/окон.
Сбор артефактов затем скрыл первичную ошибку: cleanup делал blocking e:lua
на confirm. Диагностика теста исправлена (xpcall, защищённый read cwd,
snapshot/stop), остаток собственного runtime сохранён в artifacts и удалён.
Исходный лог — `.tests/windows-ide035-final-active-worktree.txt`,
artifact 551474721600, neogit.log содержит настоящий exit 255.
Повтор с новой диагностикой — 2 PASS, но причина отказа не установлена и
пункт не закрыт. Нужны управляемое воспроизведение и точный владелец cwd/handle;
не маскировать ошибку force/retry/задержкой. Продолжение IDE-034.

## IDE-039 — ConPTY: эталон RU расходится на Ctrl+/

2026-11-02: unit/trace/ConPTY — 15 файлов PASS, 1 FAIL; из 66 ConPTY проверок
65 PASS, единственный FAIL — сравнение полного результата с RU fixture.
Отдельный прогон с сохранением реального результата снова дал отличие:
replay/right_ctrl Ctrl+/ в nvim `<C-_>` вместо `<C-N>`, в vt `1f` вместо `0e`.
Других отличий JSON нет; эталон не менялся. Наблюдатель в ignored
`.tests/observe-ide035-conpty.py` только сохраняет результат исходного probe,
артефакты — `ide035-conpty-actual.json`, `ide035-conpty-diff.txt`.
Гипотеза: foreground HKL и раскладка приватных ConPTY различаются; сейчас
harness помечает весь прогон языком переднего окна. Проверить фактическую
раскладку/параметры каждого reader и воспроизведение на обеих раскладках,
сохранять diff/provenance без перезаписи эталона. С Gitsigns связь не доказана.

## IDE-040 — единичный RPC timeout при открытии Git во время initial signs

Прерванная интеграция 2026-11-01: новый gitsigns-worktree.test.lua прошёл
первый сценарий, второй остановился на nvim_get_mode при фокусе NeogitStatus
(artifact 3279984278000). RPC сам завершил child по прежнему deadline;
stderr/notifications не установили причину. 2026-11-02 отдельный dirty
и оба сценария вместе прошли без изменения кода или таймаутов. Это не фикс.
Сохранять транспорт/время/живые процессы при повторе; не смешивать с
установленным ENOENT IDE-035 или CLI timeout IDE-031 без доказательств.

IDE-037 → [Чистый Docker по выбору владельца](docs/DOCKER_WINDOWS_SETUP.md):
после рестарта/ошибок IPC и сброса Desktop engine смотрел на новое пустое
хранилище C:, прежний диск 468,88 GiB остался на F:. Попытка копирования
отменена владельцем; настроено чистое хранилище F:/wsl/DockerDesktopWSL-clean,
лимит 128 GiB, Desktop AutoStart=false, container/volume write/read PASS.
Старые данные сохранены, незавершённая копия не используется; её удаление
заблокировано автоматической проверкой. Автоуправление Desktop/WSL ради
тестов запрещено без отдельного явного поручения. История — FIXLOG §98.

## IDE-036 — сильные задержки ввода и окон Windows

2026-11-01, примерно 21:30: тормозит ввод и работа других программ; подозрение
владельца — терминал. Собственный Windows full остановлен. Живой `code --status`
показал три `RESULT_CODE_HUNG` GPU-процесса VS Code, ошибки Skia/shared context,
software fallback и несколько смен PID. До этого GPU-процесс Code занимал
почти одно ядро, WezTerm — около 0,2–0,9% CPU и отвечал CLI за 128 ms.
RAM свободно около 24–25 GiB, очереди диска пустые. AMD Graphics сообщает Code 43.
Общая причинная связь ещё проверяется; успешный поздний замер не считается
исправлением. Драйверы/глобальные настройки и рабочие приложения не менялись.
[Разбор и следующие проверки](docs/WINDOWS_UI_LAG_DIAGNOSTICS.md).
После попыток восстановления владелец подтвердил: помог только рестарт ПК.
Перезапуск GPU child VS Code не восстановил отзывчивость. Это не подтверждает
единственную причину в Code/WezTerm; IDE-036 остаётся открытым. Владелец
поручил продолжить план после перезагрузки, тесты разрешено возобновить.

<!-- пиши ниже -->

IDE-035 → [FIXLOG §99](nvim_forge/FIXLOG.md#99-gitsigns-незавершённый-diff-и-исчезнувший-worktree):
initial attach продолжал show с исчезнувшим process cwd и бросал ENOENT.
Контролируемые настоящие Git results воспроизводят ошибку; временный
pin/SHA backport Gitsigns передаёт путь через git -C и оставляет Git
возвращать nonzero/stderr. Два UI E2E и семь проверок подготовки прошли
Windows/Ubuntu; новый CLI --plugin выбирает одну декларацию, обычная загрузка
только читает. На установленном Forge: :Lazy build gitsigns.nvim и restart.
Mac/GUI не проверены. IDE-038/039/040 — отдельные открытые наблюдения;
исходные красные Windows прогоны не объявляются зелёными после повторов.

IDE-034 → [FIXLOG §96](nvim_forge/FIXLOG.md#96-neogit-удаление-текущего-worktree-после-смены-cwd):
Git запускался до scheduled chdir, удерживая удаляемый cwd. На Windows это
exit 255/Permission denied и пустой каталог; обычный CLI repro подтверждает
роль cwd процесса Git/редактора. Временный однострочный патч закреплённого
Neogit ждёт перехода в main. Явный Lazy build/CLI, проверки pin/SHA,
apply/check/revert и provenance тестовых архивов; обычный запуск только читает.
Два real editor и пять проверок подготовки/CLI/Lazy build прошли Windows/Ubuntu.
Существующей установке нужен `:Lazy build neogit` и перезапуск.
Mac/GUI не проверены; IDE-035 — отдельная открытая гонка.

IDE-032 → [FIXLOG §95](nvim_forge/FIXLOG.md#95-удалённый-файл-буфер-остаётся-доступным):
Neogit refresh запускал checktime для оставшегося открытым удалённого файла,
Native E211 мог блокировать ввод. Общая политика FileChangedShell сохраняет
текст/modified, освобождает Gitsigns watchers и удерживает autosave до write/
Save As; warning через Fidget не требует Enter. Контроль старого config-source
в финальном сценарии даёт E211 (36164862736900), пять новых E2E и исходный
IDE-GIT-3 прошли Windows/Ubuntu. Mac/GUI не проверены. IDE-034 разобран в §96,
IDE-035 (до готовности initial attach) остаётся открытым.

IDE-033 → [FIXLOG §94](nvim_forge/FIXLOG.md#94-conpty-регресс-не-должен-менять-плагины-владельца):
старый ConPTY набор запускал Forge из source config с настоящим user data,
Lazy переписал neogit/neotest pin в source lazy-lock. Изменённый lock
сохранён как улика, исходные байты восстановлены. Набор переведён на
private config/data/cache/state с подготовленными pinned plugins и SDK
общего runner; реальные child stdpath и source lock invariance проверяются.

## IDE-031 — единичный timeout Windows CLI entrypoint

Полный регресс IDE-028: CLI quick/e2e прошли, но отдельный запуск Windows
PowerShell `-NoProfile -File .../scripts/test.ps1 unknown-mode` превысил
10 секунд в TestEntryPointsCLI. Процесс запускался в изолированной fixture
на F:, до нормального завершения неверного режима. Причина не установлена;
timeout не увеличивался, launcher IDE-028 этот путь не использует.
Исходный отчёт: `.tests/windows-worktree-refresh-full-report.json`, stderr:
`.tests/windows-worktree-refresh-full-logs/tests__e2e__entrypoints.test.lua.log`.
Это существующий постоянный e2e; результат повторного запуска сохраняется
отдельно в `.tests/windows-worktree-refresh-recheck.txt`.
Повтор обоих CLI случаев прошёл (0,5 секунды), код/timeout этого набора не
менялись. Исходная причина timeout остаётся открытой; один повтор не фикс.

Диагностика расширена в [FIXLOG §93](nvim_forge/FIXLOG.md#93-cli-timeout-сохраняем-доказательства):
10 повторов/30 CLI процессов прошли, deadline 10s сохранён. Каждая попытка
оставляет PID/argv/cwd/время/вывод/exit в `.tests/entrypoints-e2e`, ошибка
также сохраняет fixture scripts. Timeout остаётся FAIL без retry;
постоянные E2E проверяют частичный вывод, завершение child и spawn error.
Исходная причина не установлена, IDE-031 не закрыта.

В полном регрессе IDE-032 также единственный FAIL — SDK CLI:
TestWindowsSDKCLI дошёл до missing manifest и сообщил ERROR, но внешний
Python runner не получил завершённую unittest сводку. Артефакт
`.tests/windows-deleted-files-full-logs/tests__e2e__windows-sdk.test.lua.log`.
Точная причина/связь с прежним PowerShell timeout не доказана. SDK CLI теперь
тоже сохраняет started/result с PID/argv/cwd/выводом в `.tests/sdk-cli`,
а внешний assert включает code/signal. Deadlines 10s/30s не менялись,
retry нет. Это диагностика семейства CLI ошибок, не объявленный фикс.

IDE-030 → [FIXLOG §90](nvim_forge/FIXLOG.md#90-тестовые-runtime-заполнили-диск-c):
569 копий editor runtime (551 старый + 18 оборванных) и 9 Go cache заняли
22,90 GB логических данных на C:. Собственные данные перенесены с журналом в
`F:/forge-nvim-tmp/`, C TEMP/nvim.0 больше не содержит файлов. Windows temp
тестов теперь в `.tests/tmp`, compiler cache переиспользуется, редакторские
профили удаляются после сохранения артефактов и при ошибке подготовки.
Четыре пустые оболочки профилей на C: не занимают полезных данных; прямое
удаление отклонено автоматической проверкой. Регресс: editor-runtime.test.lua.

IDE-029 (гонка File Explorer e2e после создания файла) → FIXLOG §88:
убран однократный toggle `l` по устаревшему снимку между созданием файла и
show_new_children. Locator ждёт строку UI и раскрывает выбранную родительскую
папку только если она закрыта; наличие на диске само по себе не завершает ожидание.
Red: `.tests/ubuntu/editor-e2e/4604061566637/`.

IDE-028 → [FIXLOG §91](nvim_forge/FIXLOG.md#91-neogit-согласованный-граф-при-быстром-visit-worktree):
после commit/push быстрые visit между разными HEAD давали async traceback
`git/log.lua:218` / `No commit found for oid` (4764282243200).
Причина подтверждена real Git gate: ASCII текст и граф получались двумя
запросами с меняющимся repo. Штатный Unicode renderer строит их из одного
снимка. Новый red — `.tests/editor-e2e/13710146467500/`;
`worktree-refresh.test.lua` проверяет split/full tab, поздний callback,
естественную серию visit, правильные Head/recent/log и сохранность Git/файлов.
Три e2e Windows/Ubuntu прошли; Mac/GUI не проверены.

IDE-027 → [FIXLOG §92](nvim_forge/FIXLOG.md#92-windows-terminal-conpty-lifecycle-и-временный-sdk):
native access violation `nvim.exe!pty_proc_resize+0x1a`, нулевое чтение.
Чистый Neovim без Forge воспроизводит сбой на первом цикле resize при
завершении terminal echo. Указатель ConPTY остаётся доступен resize при
background free/nested uv_run; патч убирает его заранее и защищает поздний
resize. Исходники одного commit/компилятор: upstream red, patched 50 циклов
green и 8 исходных buffer E2E green. Официальный 0.12.5 тоже падал в Forge.
Владелец выбрал временный SDK Windows: `scripts/prepare-windows-sdk.ps1`,
lock/patch, проверка manifest/SHA256 в `nvim_forge.cmd` и `scripts/test.ps1`.
Linux/macOS используют официальный SDK; системный Windows nvim не заменён.
Прямой `nvim` остаётся подвержен upstream ошибке. Mac/GUI не проверены;
после подтверждённого upstream исправления убрать временный SDK отдельным шагом.

IDE-026 → [FIXLOG §89](nvim_forge/FIXLOG.md#89-diffview-закрытие-во-время-загрузки):
ранний close после списка истории давал async traceback/hit-enter
(`file_history_view.lua:98` / `use_entry`; исходные artifacts 3719241169500,
3783993574400). Запрос close теперь возвращает фокус в исходный контекст,
cleanup ждёт backend и адресуется конкретному view. Постоянный регресс —
`tests/e2e/diffview-close.test.lua`, включая real git show gate. Новый red
исходной сборки: `.tests/editor-e2e/7764921880500/`.

IDE-024 (Windows hunk stage) → FIXLOG §86: upstream Neogit #1977,
абсолютный путь в patch заменён относительным обновлением pin. Red:
`.tests/editor-e2e/4217973742200/neogit.log`, Git `does not exist in index`.

IDE-025 (worktree cwd сбрасывается при фокусе старого файла) → FIXLOG §87:
корень рабочей папки теперь меняется явно; project.nvim не меняет cwd на
каждом BufEnter. Red: `.tests/editor-e2e/4692036212000/`.

## IDE-023 — стандартный выход из terminal перехватывается ToggleTerm

В ходе E2E файловых вкладок настоящий `:terminal echo ...` получил
Ctrl-\, Ctrl-n; вместо normal открылся дополнительный ToggleTerm. Native
Ctrl-\ совпадает с open_mapping ToggleTerm. Проверенный маршрут возврата — F7
(он выходит из terminal без remap), также настроен Esc Esc для normal.
Конфликт прямого native выхода остаётся для этапа terminal/jobs; конфигурация
ToggleTerm в задаче буферов не менялась. Воспроизведение — windows-buffers-first.txt,
artifact 1353158363400: обычный terminal и дополнительный toggleterm.

## IDE-013 — Windows: Starship прерывает Git при первом prompt в cs2d

Новая вкладка/переход в `D:/rust_repo/cs2d` сообщает:
`Executing command "C:\Program Files\Git\cmd\git.exe" timed out`, затем
предлагает увеличить command_timeout. Повторно сообщение не видно.

Диагностика 2026-10-31: Starship 1.21.1, command_timeout=500 мс (default),
профиль PowerShell включает `starship init powershell`. Trace git_status:
`git -C <repo> --git-dir <repo>/.git -c core.fsmonitor= --work-tree <repo>
status --porcelain=2 --branch`. Текущий Git вызов 205.844 мс; четыре повторных
запуска модуля 223.1 / 212.0 / 216.3 / 211.9 мс, без WARN. Trace сохранён
в `.tests/starship-cs2d-git-trace.txt`. В session log найден исходный WARN.

Starship 1.21.1 подавляет одинаковые WARN по session log: отсутствие повторного
сообщения не доказывает отсутствие новых таймаутов (src/logger.rs, строки
157–171). Превышение 500 мс на первом обращении пока не воспроизведено;
холодный filesystem cache/проверка защитником — гипотезы, не установленная
причина. Настройки prompt, Git и cs2d не менялись. Дальше: замер первого
обращения в новой сессии, определить длительную операцию, затем выбрать
исправление с регрессом. Не смешивать с Mac/zsh/Go IDE-001.

## IDE-001 — macOS: медленный shell и повторная загрузка Go

Новая вкладка WezTerm и даже `clear` подвисают; есть подозрение на повторный
`source`. Владелец подтвердил: происходит **до запуска Neovim**, shell — zsh.
Пример вывода:

```text
go: downloading go1.26.0 (darwin/arm64)
go: download go1.26.0: golang.org/toolchain@v0.0.1-go1.26.0.darwin-arm64: verifying module: checksum database disabled by GOSUMDB=off
```

Ожидание: быстрый prompt, открытие вкладки и clear без установки SDK.
Известно: попытка автозагрузки конкретного toolchain не проходит проверку
при `GOSUMDB=off`. Пока не известны инициатор команды и причина выбора версии;
повторный `source` — гипотеза. [Диагностический лист](docs/MACOS_STARTUP_DIAGNOSTICS.md).

2026-10-31: подготовлен пассивный сборщик `nvim_forge/scripts/diagnose-shell.py`
и проверки в change `diagnose-macos-shell-startup`. На Mac запуск ещё не выполнен.
Дополнительный кандидат: Go-модуль Starship вызывает `go version` при построении
prompt; наличие и причинность на Mac нужно подтвердить. IDE-001 не закрыта.

Отдельно editor e2e выявил фоновые установки Treesitter/Mason и refresh
registry внутри Neovim. Они перенесены в явные команды, см. FIXLOG §62.
Это происходит после запуска редактора и не объясняет исходную задержку zsh.

## IDE-002 — macOS: Cmd+C продолжает не работать

После предыдущих исправлений Cmd+C в WezTerm всё ещё не работает по отчёту
владельца. Уточнить источник выделения (WezTerm/copy mode/Neovim Visual),
раскладку, активный режим и фактически загруженный конфиг.
Ожидание: выделенный текст попадает в системный clipboard, пустое выделение
не затирает clipboard. Не закрывать проблему ссылкой на старый фикс:
сверить `fix-copy-clobbers-clipboard`, FIXLOG §42 и последующие записи,
затем воспроизвести на Mac.

## IDE-003 — DAP: перестало открываться окно вывода

«Запускал дебаг, после этого в какой-то момент, когда fatal перестал
происходить при запуске дебага, перестало открывать окно с выводом,
я не вижу вывод». Язык/адаптер и последовательность ещё не установлены.
Ожидание: вывод доступен при первом и повторных запусках независимо от fatal;
обычное завершение не прячет и не стирает нужный вывод.

2026-10-31: Go/Delve E2E подтвердил скрытый REPL при сочетании
outputMode=remote + console=integratedTerminal и потерю ранних output events
из-за повторной очистки. Исправлено, Windows/Ubuntu PASS (FIXLOG §65).
Первый/повторный обычный запуск тоже покрыт. Точное совпадение с конфигом
владельца и Mac/Python/Rust ещё не подтверждено; IDE-003 полностью не закрыта.

## IDE-004 — DAP: текст panic после остановки

При panic и остановке отладчика на ней нужен текст ошибки в Output.
Ожидание: соответствующий вывод доступен во время паузы и после завершения,
включая текст panic/стек, который реально передал процесс или адаптер.
Проверить источник stdout/stderr, DAP output events и порядок доставки:
не считать, что текст обязательно пришёл раньше события остановки.

2026-10-31: подтверждено на настоящем Go/Delve: panic text приходит в stopped
и exceptionInfo до runtime stderr, но REPL его не показывал. Добавлен вывод
на паузе и защита от устаревших ответов; Windows/Ubuntu PASS (FIXLOG §66).
Mac и другие адаптеры ещё не проверены.

## IDE-005 — DAP: непонятно, как сфокусировать Locals и Output

Нужно без мыши переводить курсор в `v Locals`, Output/DAP и обратно в код,
раскрывать переменные, не продолжая paused-сессию.
В текущем коде normal mode: `Space D v` — Scopes/Locals,
`Space D c` — существующий DAP output/bottom, `Space D 0` — код.
Проверить установленный конфиг и включить эти действия в общую модель панели.

## IDE-006 — тесты: неубираемый «No active session»

После «запустить тест под курсором» появляется табличка поверх текста
`No active session`, которую не получается убрать.
Ожидание: обычный запуск теста не требует активной DAP-сессии; сообщения и
временные окна можно закрыть, текст редактора остаётся доступен.
Установить точную команду запуска, источник overlay и поведение debug-теста
отдельно от обычного теста.

2026-10-31: Go-часть исправлена и покрыта настоящими E2E на Windows/Ubuntu:
nearest/file/debug, eval только на паузе, Esc/q закрывает DAP float (§68–70
FIXLOG). Источник текста — expression widget DAP; обычный neotest его не
вызывает. Исходная последовательность владельца на Mac пока неизвестна,
поэтому не объявляем всю жалобу закрытой. Mac/Python/Rust ждут проверки.
При debug Go neotest показывает skipped; итог теста находится в DAP REPL.

## IDE-009 — единая клавиатурная модель панелей

Референс — понятное управление в Claude Code: выбрать область через
`<prefix> h/j/k/l`, затем одинаково перемещаться, раскрывать/сворачивать,
подтверждать/отменять. Думать о всех основных панелях, первый пилот — Debug.
Ожидание: видимый фокус, общие действия и подсказка, безопасный возврат в код;
перемещение фокуса не запускает debug и не убивает задачи. Точный префикс и
семантику действий проверить на конфликты/терминалы прежде переназначений.
Для терминала и полей ввода сохранить обычный ввод текста.

## Ранее зарегистрированные проблемы

### IDE-010 — универсальная поддержка Windows/macOS/Ubuntu, Mint позже

Решение владельца 2026-10-31: сборка универсальная. Активная матрица:
Windows native, Ubuntu headless в Docker на Windows, macOS отдельно на Mac.
Mint временно отложен по последнему решению владельца.
Общее поведение IDE едино, системные различия выносятся на границы вместо
разрозненных Windows-спецслучаев в плагинах. [Архитектурный план](docs/PORTABLE_ARCHITECTURE.md).
Runtime-перенос ещё не выполнен.

### IDE-011 — e2e каждой фичи и регресс каждого бага в VM

Решение владельца 2026-10-31: общий подход по примеру cs2d; для каждой фичи
и исправленного бага обязателен end-to-end сценарий. Нужны простые команды
запуска/прогона. Владелец обеспечивает нужную машину/VM и запускает там тесты.
Путь к cs2d запрошен; его устройство пока не изучено.
[Контракт, команды и матрица покрытия](tests/e2e/README.md). CLI диагностики,
entrypoints и 10 базовых сценариев настоящего редактора проходят на
Windows/Ubuntu (FIXLOG §61). Mac, исходная задержка shell, языки, DAP,
тестовая панель и Git ещё не закрыты этими проверками.

### Прежние замечания Windows

Windows/WezTerm: Ctrl+] на русской раскладке приходит в nvim как `<NL>` —
сдвиг вправо nvim_forge (`<C-]>`) там не срабатывает (на английской работает).
Найдено пробой через conpty.dll (change add-nvim-chords-on-windows, design,
«Итог пробы»). В подмену WT-KEYS-10 не взято: запись нажатия зависит от
раскладки, а колбэк WezTerm её не знает. Нужен отдельный change.

Windows/WezTerm: Shift+F1 приходит в nvim как `<F13>` — та же клавиша, что шлёт
Ctrl+[ (WT-KEYS-6, сдвиг влево). Подтверждено пробой add-nvim-chords-on-windows.
Заодно F-клавиши с модификаторами приходят как `<F13>`–`<F63>` (Shift+F5 →
`<F17>`, Ctrl+Shift+F5 → `<F41>`): привязки вида `<S-F5>` в nvim_forge на
Windows не срабатывают. Решить: псевдонимы в nvim_forge или другая клавиша
для Ctrl+[.


<!-- ────────── разобрано (переехало в nvim_forge/FIXLOG.md) ────────── -->

IDE-021 → [FIXLOG §83](nvim_forge/FIXLOG.md#83-файловые-вкладки-общая-модель-и-reopen):
единый файловый цикл/BufferLine/picker, unloaded/readonly, панели/terminal,
Space b r и 8 editor E2E. Mac/GUI и persistent/session reopen открыты.

IDE-022 → [FIXLOG §84](nvim_forge/FIXLOG.md#84-закрытие-файла-решение-до-смены-окон-и-autosave):
прежний close менял окна до confirm, BufLeave запускал autosave. Решение
Save/Discard/Cancel принимается до мутаций, таймер закрываемого буфера отменяется
штатным событием; Cancel/ошибка записи сохраняют данные/фокус.

IDE-016 → [FIXLOG §78](nvim_forge/FIXLOG.md#78-дерево-файлов-операции-и-общий-маршрут):
создание/rename/move/cut-paste/отмена/конфликт, source selector и общий Space w e;
7 E2E. Mac/GUI, несохранённые буферы, copy/delete и LSP file operations открыты.

IDE-017 → [FIXLOG §79](nvim_forge/FIXLOG.md#79-move-полный-путь-в-диалоге):
полный путь назначения больше не добавляется к каталогу повторно.

IDE-018 → [FIXLOG §80](nvim_forge/FIXLOG.md#80-reveal-повторный-navigate-после-rename):
при первом открытии исключён второй отложенный reveal старого пути.

IDE-019 → [FIXLOG §81](nvim_forge/FIXLOG.md#81-neo-tree-выбранная-строка-после-zoom):
Enter и rename из развёрнутого дерева используют выбранный элемент;
курсор/view переносятся после возврата в исходное окно.

IDE-020 → [FIXLOG §82](nvim_forge/FIXLOG.md#82-neo-tree-два-владельца-esc):
штатный <esc> и наш <Esc> были одной клавишей с разными действиями;
override использует исходный ключ, E2E проверяет каноническую уникальность.

IDE-008 → [FIXLOG §76](nvim_forge/FIXLOG.md#76-outline-слева-и-общий-маршрут-панели):
единый модуль Aerial, Space w a, прежние aliases через менеджер, q/Esc/help/zoom;
6 E2E Windows/Ubuntu. Outline и дерево заменяют друг друга в left-слоте.
Mac/GUI и проверка на установленной сборке владельца остаются в roadmap.

IDE-015 → [FIXLOG §77](nvim_forge/FIXLOG.md#77-neo-tree-повторное-открытие-и-отложенные-события):
регресс Outline нашёл Neo-tree follow ERROR на закрытом tree-буфере и
позднее открытие Explorer после смены слота; исправлена интеграция событий.
Постоянный E2E проверяет быстрые переключения и валидность ссылки на буфер.

IDE-005/009, пилот Debug → [FIXLOG §74](nvim_forge/FIXLOG.md#74-панели-debug-общий-маршрут-space-w):
Space w, focus/help/hide/zoom, 4 E2E Windows/Ubuntu; перенос остальных панелей
и Mac/физическая доставка клавиш остаются в roadmap.

IDE-014 → [FIXLOG §75](nvim_forge/FIXLOG.md#75-satellite-нулевая-высота-при-закрытии-debug-панелей):
во время пилота найден Satellite Invalid height при закрытии source окна;
добавлены нынешние DAP filetypes в штатные исключения, ERROR не подавляется.

IDE-012 → [FIXLOG §72](nvim_forge/FIXLOG.md#72-codelldb-проверка-инструмента-при-запуске):
поиск и сообщение перенесены с общей загрузки DAP на запуск codelldb.
Три E2E Windows/Ubuntu; Mac и настоящая Rust/C/C++ отладка ещё не проверены.
Исходная IDE-001 до Neovim остаётся независимой открытой проблемой.

IDE-007 → [FIXLOG §71](nvim_forge/FIXLOG.md#71-snippet-ручной-ввод-отменяет-нетронутые-параметры):
параметры LuaSnip после completion очищаются при вводе вне активного поля;
введённые аргументы сохранены. 11 E2E Windows/Ubuntu; Mac/ответы реальных LSP
ещё не проверены, долг остаётся в roadmap.

<!-- 2026-06-22 → §28 широкая колонка номеров строк (адаптивный statuscolumn);
                  §29 плейсхолдеры сниппета бледнее/курсивом, печать заменяет -->
<!-- 2026-06-27 → §30 Esc сворачивает сниппет-сигнатуру до foo();
                  §31 Ctrl+[ = outdent (wezterm → F13);
                  §32 wezterm: размер окна + запоминание (Ctrl+Shift+S);
                  §33 Go ++/-- видно после выхода из insert (связано с §36);
                  §34 :Format показывает ошибку gofmt (формат молчал на синтакс-ошибке);
                  §35 Go: версия в статуслайне + :GoToolchain/:GoVersion;
                  §36 нотификация о падении LSP + <leader>lR рестарт;
                  §37 DAP: показываем падение delve на старте + watchdog панели -->
<!-- 2026-07-12 → §38 диагностика не раскрывается сама; оверлей по `gl` / <C-W>d;
                  §39 alpha: убраны номера строк и линейка (единый apply_window_chrome);
                  §40 neo-tree: «(N hidden items)» больше не открывается как файл -->
<!-- 2026-09-27 → §41 Windows/WezTerm: Shift+кириллица и русская запятая (kitty → win32-input-mode);
                  §42 macOS/WezTerm: Cmd+C затирал буфер при пустом выделении + симлинк конфига -->
