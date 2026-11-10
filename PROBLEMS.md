# PROBLEMS — инбокс

Кидай сюда новые проблемы / хотелки в свободной форме (по одной на абзац).
После фикса они переезжают в `nvim_forge/FIXLOG.md` в формате
«Проблема → Решение → Файлы».

Для каждого исправления обязательны причина, изменение, проверка/e2e и
вывод. История читается через [единую хронологию](docs/HISTORY.md);
формат новой записи — [шаблон](docs/history/ENTRY_TEMPLATE.md).

Маршрут и приоритеты: [рабочий план nvim_forge](docs/IDE_ROADMAP.md).
Для новых пунктов используем следующий свободный ID `IDE-xxx`; исходный
симптом хранится здесь, этап и состояние — в плане. Следующий ID: `IDE-095`.

## IDE-094 — очистка E2E профиля оставляет dangling Windows junction

2026-11-10: негативные Rust probes завершили editor exit/signal0, own Job пуст,
но R.remove не удалил private home INetCache/Content.IE5. Read-only inspection:
directory junction указывает на отсутствующий IE внутри того же профиля на F:,
target содержит F:/ после extended prefix; uv.lstat/readlink возвращают nil,
scandir видит kind=link. Ручной uv.fs_rmdir одного проверенного собственного
link удалил только junction. Требуется постоянный native link regression и
удаление link без обхода target; увеличивать cleanup timeout бессмысленно.
§163: native malformed-junction source RED →3 link cases PASS; recursive
cleanup обходит только directory entries, links удаляет через unlink/Windows
nonrecursive rmdir. 13 Windows PASS/1 POSIX-only SKIP, quick353, strict78.
Четыре подтверждённых owned остатка §162 удалены. Новый negative debug probe
сохранён как history RED, но runtime уже удалён; target sentinel не затронут.
Production/SDK прежние, Ubuntu/Mac не запускались.

## IDE-093 — history assertion принимает terminal padding за потерю stdout

2026-11-10: настоящий Rust/CodeLLDB + resize UI140×45→140×35 между before и q
даёт history assertion RED. Raw capture: те же POLICY_BEFORE42/POLICY_STDERR,
тот же buffer/channel/session, отличаются только пустые строки внизу терминала.
Воспроизведение: tests/diagnostics/output-toggle.lua --trace --resize.
Нужно сравнивать смысловую историю без viewport padding и сохранить проверку
реальной потери текста. Production stdout этим опытом не признан потерянным.

## IDE-092 — SDK source gate пропускает staged изменения

2026-11-10: diff worktree/index не видел постороннюю staged правку. Настоящий
preparer в частном checkout с применимыми закреплёнными patch успевал изменить
оба target source до downstream отказа на dependencies. CLI E2E дал source RED;
unstaged вариант уже отвергался. Оба diff теперь относительно HEAD, включая index:
2 subcases PASS без изменения source/выбранного SDK. SDK CLI12, quick353,
strict76 PASS (§161). SDK не пересобирался; actual cached source соответствует
двум patch. Это follow-up IDE-BOOT-6/guard-windows-sdk-process-ancestry.

## IDE-091 — общий Debug toggle оставляет PTY или открывает sidebar вместо скрытия

2026-11-10, source 5d07d2b: native Rust/CodeLLDB probe после Space du
закрыл sidebar, но оставил dap-terminal (34018783081000). Два постоянных
E2E дали source RED: sidebar+PTY и только PTY (34156241548500/34168886075300).
В activities.debug_filetypes и close_debug отсутствовал существующий terminal
компонент. Добавлены две записи в общие visibility/close; новые Windows E2E
2 PASS с прежними buffer/channel/pause и последующим stdout в том же PTY.
§160: итоговый Windows regression32 PASS/26 captured profiles, quick353,
strict76/76. Change fix-debug-toggle-terminal, IDE-PANEL-13;
Ubuntu/Mac gates открыты. Это отдельный подтверждённый дефект, не доказательство
причины IDE-090 или Docker IDE-087.

## IDE-090 — Rust Debug toggle: единичный отказ скрыть sidebar после Output q

2026-11-10: при Windows SDK regression тест IDE-PANEL-11 Rust PTY прошёл
первое manual reopen, затем после Output q + Space du sidebar остался виден
(`Debug-группа скрыта`, profile 32921392974800). Native exit/signal 0,
API errors пусты. Тот же полный трёхсценарный набор без изменения UI/source
на том же кандидате SDK прошёл повторно (Rust profile 33029843865800).
Причина неизвестна; связь с SDK guard не доказана и не исключена одним повтором.
Постоянный regression уже есть: tests/e2e/dap-output-policy.test.lua,
tests/lib/output_policy.lua. Первый log сохранён отдельно:
.tests/ide089-windows-dap-output-policy-first.txt. Нужен targeted timeline
видимости Debug и обработки q/toggle; не увеличивать timeout ради зелёного отчёта.
Targeted bounded probe 33904027358500: 6 циклов hide/reopen на той же паузе,
12 toggle calls, исходный отказ sidebar не повторился; native exit/signal0,
API errors пусты. Насыщенный Win-event trace 33829927736000 остановился раньше
на assertion Reopen потерял историю; before/after loss не установлен, этот
пилот не принимается за доказательство потери stdout. Новых runtime таймеров
или ослабления старого assertion нет.
§162: bounded in-memory trace и failure-preserving attempt сохраняют raw data.
Контроль6 и trace6 циклов прошли без исходного события. Отдельный настоящий
running Rust probe скрыл Debug до pending800ms watchdog; тот снова открыл
sidebar через plugins/dap.lua:1419. Profile37343177404900: hide89.6ms после
initialized, reopen716.4ms после hide, без нового stopped event. Механизм
воспроизводится; нужен постоянный startup-hide E2E и устранение watchdog,
с сохранением auto-open при initialized/новом breakpoint. Исходное разовое
событие не имело этой трассы, единственность его причины не утверждается.

## IDE-089 — Windows Neovim: PPID-only обход принимает более старый процесс за потомка

2026-11-10: exact pinned proc.c fragment в native harness получает controlled
stale snapshot edge и завершает older sibling (реальный процесс, exit 15).
Child действительно создан root; older создан раньше root, все три под own Job.
Creation-time guard prototype сохраняет older и штатно завершает root/child;
4 cases PASS; на этапе §158 SDK оставался прежним. Read-only host snapshot также обнаружил live
vctip/python age inversion, без завершения этих процессов. FIXLOG §158.
§159: backport выбран в Windows SDK с отдельными patch/hash, Schema 2,
staging и откатом. Native regression компилирует actual patched source:
4 guard PASS, 3 expected upstream RED. Итоговый Windows набор 49 PASS;
после продвижения quick 353, SDK CLI 11 и lifecycle 2 PASS. Linux/macOS
backend прежний. Это подтверждённый conditional defect; причинность
Docker IDE-087 ещё не установлена. [Доказательства/границы](docs/WINDOWS_PROCESS_DIAGNOSTICS.md).

## IDE-088 — Debug View возвращает фокус в terminal вместо кода

2026-11-10, native Windows/Ubuntu, source 7fe45bc: настоящий PTY в первом
окне, отдельное normal code окно существует. F7 подтверждённо переводит
в код; Space m d открывает sidebar/REPL и переводит фокус обратно в PTY.
activities.find_code_window отвергает лишь nofile/prompt и часть tool filetypes,
поэтому принимает terminal (и отдельный floating file fixture). State terminal
отвергает. Artifacts Windows 25722298083800 / Ubuntu 963889831727.
Probe — tests/diagnostics/code-window.lua, обзор §155. Fix §156: ordinary
predicate state + прежний tool filter, постоянные 3 source RED → Windows PASS;
22 Windows checks и 16 clean profiles. Ubuntu gate открыт: engine исчез во
время Windows (§157); Mac непроверен. F7 только фокусирует существующее окно,
Space w 0 может создать main. Создание/guard/session cleanup не объединены.
Change fix-code-focus-window-classification; [обзор](docs/CODE_WINDOW_REVIEW.md).

## IDE-087 — Docker backend исчез во время Windows E2E

2026-11-10: version 28.5.1 отвечал, затем Linux/default pipe исчезли. По host
журналу backend остановился в 17:06:41 MSK: com.docker.build exit status 15,
закрытие API. Первый compose run агента — 17:08:59, до создания контейнера
не дошёл. Команд управления Desktop/WSL в этом шаге не было; инициатор и
первопричина не установлены. После включения владельцем 19 Ubuntu checks
прошли, что не является исправлением остановки. Факты/границы — FIXLOG §154.

Повтор 17:45:10 во время Windows IDE-088: тот же build exit status 15 и
исчезновение всех Docker processes, следующий compose не подключился.
Совпало с cold UI qa! (root 700); signal=0, scope terminated=false. В native
Neovim proc.c ancestry основана на PPID без creation-time check; возможен
ложный потомок после PID reuse, но точный caller/target не записан.
[Расследование и ограничения](docs/WINDOWS_PROCESS_DIAGNOSTICS.md), §157.
До проверки механизма агент не провоцирует повтор массовыми запусками и не
просит бесконечно перезапускать Desktop. Причина пока не объявлена установленной.

## IDE-085 — Windows E2E: единичный SIGTERM после обычного qa!

2026-11-10, аудит IDE-081: Windows artifact 19482373991200 (missing library,
CMake есть) прошёл все search/health assertions, mode=n/blocking=false,
messages пусты. Native qa! не завершился за штатные 2 s; cleanup отправил
SIGTERM около 2068 ms, exit_code=1/signal=15, hard_kill=false, own scope пуст.
Остальные profiles этого прогона завершились штатно. Нет доказательства,
что RPC quit был обработан или причина связана с fzf/health/самим SDK.

Новый search E2E теперь проверяет exit_code/signal=0 после stop; первичный
artifact/log сохранён отдельно. Ограниченный зелёный повтор не закрывает
расследование. Нужен bounded capture доставки quit, состояния child и exit
без увеличения timeout и без глобального завершения чужих nvim/процессов.
Не объединять автоматически с startup ui_attach IDE-073 или DAP IDE-074.
Факты/границы — FIXLOG §151/152; product fix для IDE-085 пока отсутствует.

Повтор на source b679227 снова RED (21014452051400, code=1/signal=15).
Test-only capture до init теперь пишет quit-controller/native JSONL и exact
helper source/SHA; API nvim_error_event больше не теряется. Он проверен на
настоящих normal/delayed QuitPre и invalid API notification fixtures, включая
detail cap. Три подробных и два unhooked followup завершились code=0; это
ограниченные наблюдения, а не установленная причина/фикс. Capture остаётся
включённым в следующих обычных E2E; при повторе смотреть QuitPre/exit/error
timeline. Новый намеренно задержанный fixture не доказывает механизм старого RED.

## IDE-080 — большой обзор фич и наслоений перед рефакторингом

2026-11-10, уточнение владельца: не изобретать LSP и костыли ради полной
матрицы языков; перед рефакторингом повторить обзор возможностей, возможно
убрать лишнее. Готовые инструменты предпочтительны, ограничения остаются явными.

Нужны карта фич/плагинов/собственного glue/backports, пользовательская ценность,
пересечения, цена и условия удаления. Сначала конкретные решения, затем
изменения с E2E. Первичная инвентаризация — docs/FEATURE_REVIEW.md и полный
docs/PLUGIN_INVENTORY.md; живые плагины и рабочие фичи пока не удаляются.
Карта DAP/panel ownership и границы regression — docs/PANEL_OWNERSHIP_REVIEW.md;
по 9 native E2E Windows/Ubuntu с trace. Выбор Output и поиск code window —
кандидаты на отдельные небольшие изменения, не объявленные исправления.
Фактический срез обзора дополнен project/focus/idle baseline, общей coverage
картой и конкретными рекомендациями (§147). Выбор удаления optional UI открыт;
материалов достаточно для отдельных исправлений IDE-082/083 без большой переписи.

## IDE-076 — оформление рамок и заголовков панелей по примеру Termide

2026-11-09, пожелание владельца: понравились обрамления окон Termide;
исследовать, можно ли перенять оформление для nvim_forge.
Предварительный референс — [Termide](https://github.com/termide/termide),
[описание рамок/заголовков](https://github.com/termide/termide/blob/main/doc/en/architecture.md).
Перед реализацией сверить выбранный образец с тем, который смотрел владелец.

Изучить цельные рамки, встроенные заголовки, оформление активной/неактивной
области и свёрнутых панелей. Проверить ограничения обычных Neovim split и
текущих Edgy/winbar/statusline; сначала небольшой прототип на одной панели.
Сохранить Space w, читаемость, рабочую площадь, zoom/resize/возврат фокуса,
клавиатурное управление и переносимость Windows/macOS/Ubuntu. Полный стиль
применять после проверки прототипа; визуальный референс не означает миграцию
на другой редактор. Нужны постоянные UI E2E и отдельная visual/GUI проверка.
Это запланированное исследование/UX, не реализованная возможность.

## IDE-074 — Rust default F5: редкий CodeLLDB timeout после runInTerminal

2026-11-09: Rust batch 7 PASS/1 FAIL (30484781261100), default F5.
CodeLLDB initialize/initialized/setBreakpoints прошли, runInTerminal получил
успешный response, после «Launching ...forge_app.exe» нет ожидаемого ответа/
breakpoint и nvim-dap WARN открыл hit-enter. Причина неизвестна. Изолированный
тот же F5 прошёл без изменения runtime; это не доказательство исправления.
Сохранены dap log/screen/notifications, отдельный повтор; FIXLOG §135.

## IDE-073 — E2E startup: редкий RPC timeout на nvim_ui_attach

2026-11-09: один Node nearest/file case не дошёл до сценария: request id 1
nvim_ui_attach, 10000 ms, child PID 8432. Артефакт 29678239013200 содержит
rpc-error/start-error/shutdown; child завершён SIGTERM, hard_kill=false,
оставшихся собственных nvim/node/sqls процессов не обнаружено. Причина не
установлена; не объявлять следствием Root/SQL и не считать исправленным
успешным новым прогоном. Связано с прежней диагностикой primary RPC IDE-047.
Нужны transport/startup evidence при следующем воспроизведении; FIXLOG §135.

## IDE-062 — SQL: отдельный test framework и references workflow

Полная матрица SQL ещё требует выбора/реального Neotest сценария (например,
SQLLogicTest/DB-specific tests), не подменённого успешным SELECT. Sqls 0.2.48
не объявляет references provider; gd/rename/query и текстовый поиск не закрывают
семантические references. Продолжить после edit/query этапа, с постоянными E2E.

2026-11-09: native SQLLogicTest/SQLite SDK готов отдельно (12 process E2E
Windows, FIXLOG §129). Editor adapter/UI прошёл 12 native UI E2E Windows (§130–135);
Windows integration gate закрыт в §136, semantic references ещё открыты.
SQLite assertion readiness не заменяет UI/проверки других ОС. План —
openspec/changes/add-sql-test-workflow/tasks.md.

Проверка источников 2026-11-09: SQLS 0.2.48 не имеет references handler;
RainLib/lsp_sqls 5a3c530 имеет provider/SQLite, но columns references сравнивают
token names без schema binding, а project index не содержит column kind.
Это не закрывает semantic references при одинаковых именах разных таблиц.
Postgres Language Server текущего среза также не объявляет references.
Нужен готовый backend с настоящей binding/scope моделью; подсветка/grep не
заменяют требование. Исходники исследования — `.tests/sql-references-sources`.

2026-11-10: source RED forge.1 подтверждён в 341aba2/§142: provider=false,
raw -32601, gr без quickfix. Собственный resolver/index prototype отменён
после уточнения владельца: это существенный private fork LSP. Код/tooling
убраны из текущего дерева, рабочий SQLS forge.1 не меняется (§143). Change
`add-sql-semantic-references` сохраняет IDE-SQL-9 для будущего готового backend;
пока references остаются ограничением. IDE-062 не закрыт, текущий этап IDE-080.

## IDE-057 — Bash debug: выбор отдельного Linux backend для Windows

2026-11-09, аудит следующего языкового этапа. Официальный bash-debug 0.3.9
требует Bash 4+/cat/mkfifo/rm/pkill и жёстко использует WSL launcher в win32
ветке; Git Bash не является его штатным backend. Git Bash 5.2.37 здесь умеет
mkfifo (реальный probe PASS), но pkill отсутствует; это не доказательство
совместимости adapter. WSL не запускался, внешняя среда не менялась.
Владельцу задан выбор Docker/WSL/другого Linux host/VM. DAP остаётся отдельной
открытой работой полного Bash roadmap; текущие язык/run/tests его не подменяют.
Источники: .tests/bash-debug-readme.md, pinned VSIX SHA и bash-fifo-probe.json.

## IDE-048 — completed Gitsigns E2E не дождался следующего Git-read

2026-11-02, общий Ubuntu после изменения cleanup: 43 PASS/1 FAIL/3 SKIP,
653 checks. Единственный FAIL — initial show/remove в gitsigns-worktree,
ожидание «следующий real show вернул ошибку Git». Artifact 31150409957837:
gate содержит один завершённый held show code=0 и успешный remove; следующий
show не зарегистрирован. Snapshot доступен, mode n, shutdown.ok=true,
hard_kill=false; первичная ошибка сохранена и профиль убран. Это отдельный
симптом от RPC/незавершившегося child IDE-047.
Гипотеза — attach был отменён после удаления файла и тест требует read,
который уже не нужен. Пока отмена не подтверждена, условие не ослабляется.
Нужно наблюдение lifecycle Gitsigns/attach и устойчивый исходный RED;
простое повторение PASS не закроет проблему. Raw report/logs сохранены как
ubuntu-ide047-full, новые полные прогоны без изменений не запланированы.

## IDE-047 — Ubuntu: RPC timeout, зависший child и потеря первичной ошибки

2026-11-02, второй serial Ubuntu full IDE-043: gitsigns-worktree dirty и
gitsigns-live-read clean завершились «Дочерний Neovim не завершился». Snapshot
первого содержит исходный RPC timeout nvim_get_mode при открытии linked файла,
но исключение e:stop перекрыло первичную ошибку. Child напечатал SIGTERM /
Finished в stderr и остался жив Sl, два собственных процесса видны в docker
top спустя 1–3 минуты. Артефакты 29211834204778 и 29296420074026; raw отчёт
ubuntu-ide043-verified: 41 PASS/2 FAIL/3 SKIP, 650 checks. Предыдущий serial
Ubuntu full прошёл оба этих файла, но имел иной дефект теста (IDE-046).
Причина первичного зависания не установлена. Сохраняются process/thread
observations; SIGKILL cleanup в helper пока отсутствует. Тестовый --rm
контейнер завершился и удалён; Desktop/WSL не менялись. Нужны отдельные
проверки завершения child и сохранения исходной ошибки, затем диагностика
первичного RPC. Зелёный повтор не закроет эту проблему.

Часть cleanup/доказательств исправлена в [FIXLOG §107](nvim_forge/FIXLOG.md#107-editor-e2e-завершение-child-и-первичная-rpc-ошибка):
конечный SIGKILL только своего handle, fail verdict, первый rpc-error.json,
этапы shutdown и code/signal, сохранение первичной ошибки caller, удаление
профиля после exit/сохранения artifacts. Normal и реальный POSIX stopped child
проверены отдельными E2E, включая полную цепочку editor stop. Причина
первоначальных двух RPC timeout ещё не установлена; пункт остаётся открытым.

## IDE-042 — Ubuntu: единичный 60s timeout key-ownership unit

2026-11-02, первый Ubuntu full IDE-038 при параллельном Windows регрессе:
key-ownership.test.lua завершён runner по 60s deadline (exit 124/signal 9),
в stdout виден 21 ok без законченной сводки. Это не указывает точное место
остановки: исходный stdout мог быть буферизован, внутреннего stage/PID нет.
Полный report — `.tests/ubuntu-ide038-full-report.json`, raw log сохранён.
Отдельный запуск с прежним 60s deadline, небуферизованным stdout и observer
NK.collect прошёл 46 PASS; collect занял примерно 2,16s. Файл
`.tests/ubuntu-ide038-key-ownership-observed.txt` сохраняет начало/конец.
Причина не установлена; повтор без изменения runtime не является фиксом.
Не смешивать с Windows CLI IDE-031/RPC IDE-040 без причинных доказательств.
Повтор полного Ubuntu без параллельного Windows прошёл: 41 PASS/0 FAIL/3 SKIP,
303s против 612s первого запуска. Это наблюдение о нагрузке, не доказательство
причины конкретного timeout. Тяжёлые наборы на этом хосте идут поочерёдно.

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

В change fix-repeated-worktree-delete установлен класс живого object read:
git -C linked show удерживает cwd и даёт Windows remove 255; тот же read
через явный git-dir без -C сохраняет linked HEAD и позволяет удалить каталог
при живом Git из main. Для уже текущего linked нужен явный process cwd
в common git-dir: наследовать cwd недостаточно (5849083854000 RED).
Класс защищён CLI и тремя UI путями, история — FIXLOG §100.
Это не устанавливает владельца handle исходного случайного отказа 551474721600.
Проверяемое исправление object read и остаточная диагностика различаются.

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
Новая постоянная команда `python -B tests/diagnostics/conpty-layout.py`
сохраняет полный результат, эталон, diff и metadata 11 сессий. Повтор
conpty-layout-qz8hcow8 поймал смену RU → EN после начала пробы: следующие
reader primary HKL EN, те же четыре поля FAIL. В этом повторе смешаны
раскладки; для двух исходных нет ретроспективного доказательства.
Контроль conpty-layout-xkb7szf1 — EN, 66 PASS, diff пустой; определённые
foreground samples только EN, один sample без foreground (не доказательство
непрерывно фиксированной раскладки).
Исходный fixture неизменён. Это диагностика, не закрытие IDE-039:
нужны изоляция/проверка actual input HKL и устойчивый RU прогон. История — §101.

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

IDE-041 → [FIXLOG §108](nvim_forge/FIXLOG.md#108-подсветка-сверхдлинного-слова-без-e339):
vim-illuminate строил regex по слову 512 КиБ; ошибка возникает при match_line,
одной компиляции для воспроизведения недостаточно. Общий should_enable
ограничивает слово 4096 UTF-8 bytes в обычном/large-file режимах. UI RED на
исходном config сохранён; по 3 новых и 10 smoke E2E Windows/Ubuntu PASS,
включая редактирование, Unicode границу, 5003 строки и длинную строку.
Pin/SDK/подготовка не менялись; Mac/физические клавиши пока не проверены.

IDE-043 → [FIXLOG §104](nvim_forge/FIXLOG.md#104-neogit-читаемый-вывод-без-terminal-title-и-osc):
CSI filter удалял начало OSC, оставляя title/BEL. Общий util companion
удаляет завершённый OSC до CSI и сохраняет UTF-8/видимые ссылки/обычные пути.
3 настоящих Git UI сценария + matrix 10 строк, 9 проверок подготовки;
baseline RED сохранён. Обновление явно: Lazy build neogit и restart.

IDE-045 → [FIXLOG §105](nvim_forge/FIXLOG.md#105-sdk-e2e-отдельный-deadline-каждого-сценария):
все SDK unittest методы делили один 30s, обрывая допустимую CLI команду.
Discovery и отдельный процесс для каждого метода, прежние 10s/30s/60s,
argv/PID/result artifacts. Холодное замедление shell не объявлено исправленным.

IDE-046 → [FIXLOG §106](nvim_forge/FIXLOG.md#106-git-e2e-готовность-панели-после-checkout):
Git CLI уже сменил ветку, UI ещё обновлялся и восстанавливал старый курсор.
E2E ждёт status Head до поиска файла; исходный FAIL и три targeted повтора
сохранены. Production Neogit и timeout не менялись.

IDE-044 → [FIXLOG §103](nvim_forge/FIXLOG.md#103-diffview-редактируемый-результат-merge-и-rebase):
Alt+e выбирал правую неизменяемую :3: версию вместо среднего результата
diff3. Selector теперь ищет modifiable normal buffer; обе карты view/file
panel проверены с завершением/отменой merge/rebase: 4 E2E Windows/Ubuntu.

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

2026-11-02: Debug/Outline/Files/Git дополнены Tests/Test Output/Search/Tasks:
Space w t/r/f/b, общие q/Esc/help/zoom/focus и сохранение состояния.
По 6 новых + 19 прежних UI проверок Windows/Ubuntu PASS —
[FIXLOG §109](nvim_forge/FIXLOG.md#109-рабочие-панели-общий-space-w-и-сохранение-поиска).
Mac/GUI, terminal/Trouble и физические клавиши остаются отдельными проверками.

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

IDE-077 → [FIXLOG §137](nvim_forge/FIXLOG.md#137-posix-editor-jobs-входят-в-собственный-scope):
native jobstart создавал другую group, orphan переживал root. Startup JSONL
регистрирует реальные собственные группы, cleanup завершает их до удаления
runtime. Exact scope 054ee05 RED; Windows 6 PASS, Ubuntu 5 PASS/1 SKIP и
весь Ubuntu 119 PASS/1 SKIP. Mac/daemon sessions вне spawn API остаются отдельно.

IDE-082 → [FIXLOG §148](nvim_forge/FIXLOG.md#148-go-metadata-без-фоновой-работы-и-поздний-delve):
label/version только читают подтверждённый cache/режим, GoVersion/GoToolchain
явные async, Delve выбирается на public DAP launch callback. Исходные SDK
правила и готовый gopls сохранены. По 27 E2E Windows/Ubuntu, 42 native profiles,
по 2 diagnostic profiles, 365 unit/trace и strict 66/66. Старый RED — §146/148.
[Команды](docs/GO_TOOLS.md), change fix-passive-go-discovery; native Mac gate
остаётся открытым. Исходная IDE-001 (zsh до nvim) этим не закрывается.

IDE-083 → [FIXLOG §149](nvim_forge/FIXLOG.md#149-peek-штатные-клавиши-вместо-строковых-действий):
семь строковых Glance mappings удалены, используются готовые callbacks.
Настоящий gopls/клавиатура: по 7 новых + 22 прежних E2E Windows/Ubuntu,
по одному повтору исходной диагностики без E21, исходники неизменны.
Управление — [QUICKSTART](nvim_forge/QUICKSTART.md#peek-как-ctrlclick-в-ide).
Change fix-peek-keyboard-mappings; native Mac/GUI отдельно.

IDE-084 → [FIXLOG §150](nvim_forge/FIXLOG.md#150-outline-фокус-при-закрытии-позднего-дерева):
trace установил цепочку late Neo-tree → наш close → Edgy on_hide/goto_main.
Guard сохраняет действительное выбранное окно через public Neo-tree API;
явный переход в code split также сохраняется. Source RED постоянного E2E,
по 3 новых + 23 прежних E2E и по 3 cold samples Windows/Ubuntu.
Change preserve-focus-during-tree-cleanup; Mac/GUI gate открыт.

IDE-086 → [FIXLOG §153](nvim_forge/FIXLOG.md#153-debug-output-общий-выбор-канала-и-сохранение-pty):
ручной Debug View терял REPL после Go exit и PTY после Rust hide, cold view
открывал Console; разные правила выбора сведены в resolver, passive reuse
сохраняет buffer/channel/history, новый запуск создаёт свежий PTY.
По 19 native checks Windows/Ubuntu, по 13 clean editor exits/scopes.
Change unify-debug-output-policy, IDE-PANEL-11; Mac/GUI открыт.
Dv остаётся Variables, opener — Space m d / dD / du.

IDE-081 → [FIXLOG §151](nvim_forge/FIXLOG.md#151-поиск-native-fzf-без-runtime-компилятора-и-явный-fallback):
готовая DLL/SO используется без CMake; missing/corrupt сохраняют рабочий Lua
sorter. Режим/причина видны в health. [Подготовка и клавиши](docs/SEARCH.md).
По 5 новых checks (4 UI + native health) и 25 прежних Windows/Ubuntu,
реальные C scores/rg/Enter/F5 проверены; Mac/ARM64/GUI отдельно. Единичная
аномалия qa! осталась IDE-085, не скрыта новым PASS.

IDE-078 → [FIXLOG §138](nvim_forge/FIXLOG.md#138-sql-e2e-перенос-terminal-не-скрывает-pass):
terminal переносил `8 SQL checks` между rows, observer ошибочно ждал цельную
строку. Native JSON/code/DB были PASS; исправлена только проверка header.
Исходный exact test 054ee05 RED; Windows case и Ubuntu SQL tests 12 PASS.

IDE-079 → [FIXLOG §139](nvim_forge/FIXLOG.md#139-sql-e2e-crash-notices-по-настоящему-exit-tuple):
observer ожидал два crash notices на всех ОС. Native tuple Windows 1/0,
Linux 0/15; Neovim core предупреждает по-разному. Сохранён raw exit journal,
ожидаются реальные сообщения без blocking child Lua на prompt. Оба SQL query
набора 20 PASS; product LSP/SQLStop logic не менялась.


IDE-075 → [FIXLOG §136](nvim_forge/FIXLOG.md#136-e2e-завершение-editor-охватывает-собственных-потомков):
Windows test runtime больше не полагается на exit одного Neovim. Job Object
установлен до init, остаток собственных потомков завершается до удаления
профиля. Реальный orphan/file lock, чужой child и native attach failure:
5 PASS, тот же final test на driver eeae06c — 4 RED. Полный Rust 8 PASS,
общий затронутый Windows регресс 111 PASS/2 POSIX SKIP, 365 unit/trace.
Исходный orphan cargo clippy (30860580344400) описан §135; его внутренняя
причина не приписывается scope. Ubuntu/macOS/native POSIX verification
остаются открытыми в fix-editor-descendant-lifetime, IDE-073/074 отдельно.


IDE-072 → FIXLOG §134: Neotest: один pytest workspace получает два namespaces.

2026-11-09: Python nearest/file дал 1 passed + 1 failed вместо одного nearest.
Артефакт содержит два neotest-python roots одной физической папки с разными
separators. Root adapter-group теперь canonical через fs_realpath, согласован
с discovery/library boundary. Точный upstream adapter-group даёт устойчивый
RED «2 namespaces, expected 1», patched — один namespace и верные результаты.
Синхронизация cursor test усилена; гипотеза потери фокуса не подтверждена.
Change add-sql-test-workflow, IDE-TEST-6; история FIXLOG §134.

IDE-071 → FIXLOG §133: Node E2E observer: ещё не готовый tree другого adapter.

2026-11-09: общий регресс дал Node 7 PASS/1 FAIL до Jest debug. Diagnostic
snapshot вызывал n.state.positions(id):to_list() без nil guard, хотя API
допускает pending root. Наличие другого adapter изменило timing; test не дошёл
до backend. Снимок теперь сохраняет pending отдельно. Настоящие Jest/debug
assertions не изменены, полный повтор Node 8 PASS; история FIXLOG §133.

IDE-070 → FIXLOG §132: Neotest: бесконечное объединение trees после смены SQL файла.

2026-11-09: реальные stop→другой script и invalid→empty UI зависали в child
после BufAdd. Диагностический watchdog сохранил stack wrap_with_parent/merge
в Neotest; directory path и file path Windows имели разные separators.
Нормализовать только adapter file недостаточно: directory parse получает
путь события. Исправление на общей границе _update_positions, pinned companion
backport Neotest; source replay точного upstream client, постоянные UI без
watchdog. Change add-sql-test-workflow, IDE-TEST-6; системные тормоза не объясняет.

IDE-069 → FIXLOG §131: Run all выбирает пустой adapter того же workspace.

2026-11-09, SQL UI regression: в корне активны пустой forge-bats и SQL tests;
Space T A вызывает nt.run.run(cwd), Neotest выбирает первый tree корня,
SQL runner не запускается. Нужен общий consumer Run all для adapters с tests
в cwd, без предпочтения порядка регистрации. Native counters/PID доказывают
source RED; исправление и регресс — add-sql-test-workflow, IDE-TEST-5.

IDE-068 → FIXLOG §128: SQL Results: видимая панель после смены workspace.

2026-11-09: видимая Results оставляла rows/header другого workspace; пустой
root наследовал чужой вывод. select менял root/record без render, а общий
ide.show пропускает open видимого component. Source d43c094: три точных RED.
Выбор теперь обновляет buffer; постоянные UI проверяют cache двух SQLite,
пустой root, late reply и counters без повторного SQL. История — FIXLOG §128,
change fix-sql-results-workspace-switch; Windows проверен, Ubuntu/Mac открыты.



IDE-067 → [FIXLOG §127](nvim_forge/FIXLOG.md#127-sql-sdk-readiness-проверка-без-build-scratch-и-compiler):
SDK readiness использует отдельный temp profile, не требует build scratch/
compiler, сохраняет payload/manifest и запрещает implicit variant switch.
Два real CLI E2E PASS Windows, исходный prepare_sql.py 79230c3 даёт RED.

IDE-066 → [FIXLOG §126](nvim_forge/FIXLOG.md#126-sqls-комментарий-перед-select-больше-не-теряет-rows):
native SQLS 0.2.48+forge.1 выбирает Query/Exec после AST comments, сохраняя
исходный SQL. 17 SQL UI PASS Windows, official upstream сохраняет RED.
Pinned source/patch/build/SHA и Go locks проверены; Ubuntu/Mac не PASS.


IDE-065 → [FIXLOG §123](nvim_forge/FIXLOG.md#123-sqlstop-штатный-выход-не-становится-crash):
SQLStop/Connect помечают ожидаемый exit своего backend; native false crash
устранён, unexpected exit остаётся видимым. Lock/PID death/reconnect UI PASS.

IDE-064 → [FIXLOG §122](nvim_forge/FIXLOG.md#122-sqruff-parse-diagnostics-через-native-cli):
Sqruff CLI/stdin сохраняет parse errors/dialect, потерянные его LSP 0.44.0;
один debounce/cancellable lint и public diagnostics. Реальный parse/gl/fix PASS.

IDE-063 → [FIXLOG §121](nvim_forge/FIXLOG.md#121-autosave-публичные-события-вместо-старых-callbacks):
устаревшие callbacks заменены public User write events и buffer-local guard.
Autosave сохраняет набранный текст, явное save форматирует; исходный RED и регресс.

IDE-061 → [FIXLOG §120](nvim_forge/FIXLOG.md#120-sqls-первый-символ-rename-и-unicode-координаты):
SQLS 0.2.48 protocol boundary: UTF-32 и character+1 только rename request.
ASCII/emoji edits/соседние statements проверены реальным UI, исходный RED сохранён.

IDE-060 → [FIXLOG §119–125](nvim_forge/FIXLOG.md#119-sql-схема-запросы-и-общие-results):
SQL edit/query core — 16 UI PASS Windows, общий регресс и история сохранены.
Это не закрывает IDE-066 backend comments/IDE-062 tests/references и остальные ОС.


IDE-059 → [FIXLOG §118](nvim_forge/FIXLOG.md#118-trace-project-fixtures-отделены-от-самостоятельных-suites):
пять исходных trace FAIL для .sh data; fixtures имеют явную границу,
настоящие suites вне неё по-прежнему требуют реестр. Selfcheck/mutations PASS.

IDE-058 → [FIXLOG §117](nvim_forge/FIXLOG.md#117-bash-rename-uri-aliases-больше-не-стирают-аргументы):
повторные edits под percent-URI aliases применялись дважды и стирали args.
Bash handler объединяет дубли; настоящий shorter rename и source replay
подтверждены. Windows PASS, Ubuntu/Mac требуют прогона.

IDE-056 → [FIXLOG §116](nvim_forge/FIXLOG.md#116-bash-язык-native-tasks-и-bats-tests):
guarded Bash-LSP/shfmt/native Tasks/Bats, 8 UI Windows PASS с source RED;
67 pins неизменны, подготовка явная. DAP отдельно IDE-057, Ubuntu/Mac открыты.

IDE-055 → [FIXLOG §115](nvim_forge/FIXLOG.md#115-rust-debug-tests-результат-сохраняет-настоящий-output):
Rust debug получал passed, но translate_results терял ссылку на настоящий
stdout. Result сохраняет output path; path-only intermediate source RED
6332668693900, GREEN 6304221991400 с marker 42 и raw stdout. Ubuntu/Mac открыты.

IDE-054 → [FIXLOG §114](nvim_forge/FIXLOG.md#114-rust-cargo-workspace-язык-и-переносимый-запуск-тестов):
Rust test IDs смешивали разделители, Cargo discovery использовал shell/regex
JSON. Общая path/argv/JSON граница исправляет nearest/file/integration/debug;
source RED 6311864893500/6318353725000/6324948175500, 8 Rust UI Windows PASS.
67 pins/4 прежних backports сохранены; startup ничего не ставит. Ubuntu/Mac открыты.

IDE-053 → [FIXLOG §113](nvim_forge/FIXLOG.md#113-dap-ожидаемый-shutdown-и-настоящие-ошибки-adapter):
успешный pytest debug перекрывался WARN adapter exit 1 после client close.
Pin/SHA backport различает запрошенную остановку и неожиданный отказ;
raw exit остаётся в логе, настоящий exit 23/stderr виден. Исходный source RED
14376411621700, Windows GREEN 14281600243600/14299729697900; Ubuntu/Mac открыты.

IDE-052 → [FIXLOG §112](nvim_forge/FIXLOG.md#112-python-project-venv-и-реальный-workflow):
Pyright не получал project interpreter и не находил dependency в неактивированном
.venv. Общий selector LSP/DAP задаёт pythonPath до initialize и сохраняет
explicit setting. Исходный runtime 6988af1 RED 14425984911000; 8 Python UI
Windows PASS, включая definition в site-packages. Ubuntu/Mac открыты.

IDE-051 → [FIXLOG §111](nvim_forge/FIXLOG.md#111-node-язык-задачи-debug-и-jest):
Neotest nearest не находит обнаруженные тесты при разных разделителях пути
буфера и дерева. Общий системный realpath на границе nearest/file, явный
pin/SHA backport; точный исходный plugin source даёт RED, Node UI Windows
GREEN. Ubuntu/Mac пока не проверены. Обычный startup исходники не переписывает.

IDE-050 → [FIXLOG §110](nvim_forge/FIXLOG.md#110-go-lsp-реальные-сценарии-и-fallback-форматирования):
общие trim formatter блокировали LSP fallback при отсутствии golines/gofumpt.
Исправлена общая политика и callers/health; исходный RED и 6 language UI PASS
Windows. Ubuntu ожидает доступного engine; Mac/GUI/прочие языки не проверены.

IDE-049 → [FIXLOG §109](nvim_forge/FIXLOG.md#109-рабочие-панели-общий-space-w-и-сохранение-поиска):
Search → Tasks → Search стирал запрос: close удалял backend buffers.
Скрытие сохраняет buffer/context; конечный E2E RED на fe64757, GREEN Windows/Ubuntu.

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
