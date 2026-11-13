# nvim_forge — рабочий план мини-IDE

Обновлено: 2026-11-13. Основная сборка: **nvim_forge**.
Статус: базовые e2e настоящего nvim_forge работают на Windows и Ubuntu;
фоновые установки инструментов редактора перенесены в явный setup.
IDE-001 параллельно ждёт диагностических данных с Mac.

## Текущая очередь продукта — решение владельца 2026-11-12

Уточнение владельца2026-11-13 после §226: натурные проверки будут позже,
они не останавливают самостоятельные пункты. Отложены и не объявляются PASS:
большой рабочий проект/отклик Files и Rust, A→B→A с реальными панелями,
Mac startup/Go/Cmd+C и физическая оценка рамок. Плавающие IDE-129/133 и
worktree IDE-038/048 ждут нового воспроизведения. Продолжать обзор наслоений
и отдельные продуктовые улучшения; без повторных общих прогонов ради зелёного.

**Приоритет после натурной проверки владельца2026-11-13:**

1. IDE-130 — первый запуск установленного профиля: восстановить plugins из
   lock, явно подготовить все6 backports, проверить native Files/Tests/Debug.
   User cache исправлен offline, инструкция исправлена. §226 завершил native
   gate: legacy3 даёт точную config ERROR Neo-tree, all открывает Files/Tests/
   Locals без ERROR/install/adapter/patch writes. Source RED → target PASS на
   Windows/Ubuntu. Исторический timeout IDE-133 с неизвестной причиной сохранён.
2. IDE-131 — Rust: cargo check без обязательного Clippy исправлен §223,
   Windows/Ubuntu source1 RED → target1 + control1 PASS. Ранний native warmup
   теперь реализован §224: до первого Rust-файла, тот же client ID; selected16
   PASS на ОС. Стандартный Cargo cache, без своего storage. Mac/large cold и
   принудительный pending metadata cancel gate остаются открытыми.
3. IDE-132 — cold first-file нагрузка разобрана §224:451→262ms Windows,
   общие UI plugins подготовлены на VeryLazy. §225 убрал подтверждённый sync
   scan ручного раскрытия через native always: source RED → target10 PASS/ОС,
   Code/input при held IO113/12ms Windows/Ubuntu. Большой рабочий проект,
   native Mac/physical и возможная стоимость Git/render ещё открыты.
   Отклик UI измеряется отдельно от LSP ready, startup cost не скрывается.
4. IDE-134 / §227 — Rust F5 metadata теперь native async coroutine; результат
   прежнего cwd даёт ABORT. Windows/Ubuntu source2 RED → target2 + настоящий
   debug control1 PASS, held input40/8ms. Нет нового backend/cache/framework.
   Native Mac/рабочий проект отложены; прежний quit IDE-121 остаётся открытым.
5. IDE-080 / §228 — сравнение Comment.nvim со штатным gc завершено. Плагин
   сохраняется: explicit line/block и действующие Ctrl+/ RU/EN; собственного
   block operator ради удаления dependency не добавляем. Статический review,
   новых behavioral PASS здесь нет. Продолжать другие конкретные наслоения.
6. Затем вернуться к оставшейся очереди ниже. IDE-048 probe остановился раньше
   remove: RPC timeout/forced native cleanup класса IDE-047, raw26364912087090
   сохранён; отмена Gitsigns этим запуском не подтверждена, условие не ослаблено.

Пока владелец работает в IDE, тяжёлые language/container suites не запускаем.
Одно короткое plain-text native E2E подготовки допустимо без Cargo/LSP builds.

**Последний результат — §227:** F5 больше не блокирует UI синхронным Cargo
metadata при разрешении Rust program. Bin/example/target picker и настоящий
CodeLLDB control сохранены, смена cwd отменяет старый результат. По3 selected
PASS на Windows/Ubuntu. Натурные проверки записаны выше и не блокируют очередь.

**Предыдущий результат — §226:** постоянный регресс полной подготовки профиля
завершён: шесть исходных payloads → all/check → Files/Tests/Locals. Windows/
Ubuntu по legacy1 RED с точной ошибкой владельца → target1 PASS; native hooks
выключены, SDK/pins/deadlines прежние. Старый обрыв Locals не повторился,
причина не установлена; отдельный инцидент IDE-133 сохранён.

**Предыдущий результат — §225:** ручное раскрытие Files теперь читает каталог
асинхронно средствами Neo-tree. Source dc23a30 RED на sync opendir, target
scan-order8 + filter2 PASS на Windows и Ubuntu; ввод до окончания чтения
113/12ms.22 final native profiles штатно завершены, SDK/pins/backports прежние.
Mac/большой проект остаются открыты; IDE-133 этим исправлением не закрыт.

**Предыдущий результат — §224:** Cargo workspace готовится до первого .rs;
native async metadata и rust-analyzer, input56ms/first txt262ms/Rust221ms
Windows,35/4/49ms Ubuntu. Compiler build script реально занят во время UI
проверки, client ID переиспользуется. После cold-load fix общие6 UI plugins
VeryLazy, функции сохранены. Selected16 PASS на каждой ОС/16 profiles всего,
source без warmup RED. Mac/large cold/pending cancel открыты; Files scan — §225.

**Предыдущий результат — §223:** compiler diagnostics Rust больше не требуют
Clippy. Native source отказал с no such command clippy; target показывает
rustc error через gl и убирает её после correction/save. Windows/Ubuntu по2
selected PASS, по3 native profiles со штатным выходом. Новых SDK/plugins/
backports нет. Срез установки §222 и его IDE-133 gate остаются открытыми;
документация подготовки сохранена отдельно в a9758ed. Project warmup и Files
latency — следующие продуктовые пункты, не объявляются исправленными.

**Прежний результат — §221:** подтверждён Linux fix managed Python debug
(IDE-119): старая версия2 RED/2 explicit PASS → текущая4 PASS, ещё15 соседних
language/debug checks PASS. Native adapter и debuggee используют разные venv;
startup install0, все16 target profiles вышли штатно. Runtime уже исправлен
в §196, новых обёрток/SDK/плагинов здесь нет. OpenSpec5/6: остался настоящий Mac.
Ubuntu unit/trace из чистого HEAD:18 файлов PASS,371 cases PASS/1 SKIP.

**Предыдущий результат — §220:** Tests возвращает открытость/ширину штатного
окна; Terminal/Debug после restart скрыты, сохранённые размеры применяются
при явном открытии/F5, без новых процессов из restore. Три новых native cases
PASS Windows/Ubuntu. Ubuntu selected22 PASS; Windows selected21 PASS/1 FAIL:
однократный медленный quit Logs (IDE-129, SavePre→SavePost13.9s). Отдельное
phase measurement1 PASS не закрывает этот FAIL. Реализация готова, строгий
Windows gate остаётся открытым. Все изменения выполнялись в F:/repo/forge-nvim.

Ближайшие оставшиеся работы после этого среза:

1. IDE-129: при новом медленном quit собрать save phases, не повышать timeout
   и не повторять неизменённый общий набор. Один текущий probe не воспроизвёл
   задержку; причинного исправления сейчас нет.
2. Натурный проход владельца: своё рабочее место A→B→A, смешанный проект,
   Debug/Tests/Terminal и клавиши WezTerm. Mac startup/zsh/Go и Cmd+C требуют
   настоящего Mac; Windows/Ubuntu не заменяют этот gate. Managed Python debug
   IDE-119 также ждёт Mac; Ubuntu source/target завершены в §221.
3. Git worktree IDE-038/048 — нужен воспроизводимый текущий кейс; старых данных
   недостаточно для нового причинного fix. SSH/OAuth также отдельные gates.
4. Постоянные рамки Termide — оценить готовый Code/Locals pilot в повседневной
   работе перед сменой default; zoom borders уже реализованы.
5. Готовые provider limits: SQL references и full Tests expansion snapshot.
   Свой LSP/renderer/private tree serializer не разрабатываем.

**Текущая точка 2026-11-13:** mixed context завершён Windows9 PASS/Ubuntu9
PASS (§209–211):6 language roots, Node script, Python venv/debug/output/Go return.
Native interactive rebase также проверен (§212): reorder/fixup/submit, отмена
изменённого todo и настоящий конфликт/abort; Windows18 PASS/Ubuntu18 PASS с
preparation guards. Исправлен ложный ERROR при отмене редактора, для установленной
сборки нужен `:Lazy build neogit` и перезапуск. HTTP credentials завершены
(§213–214): исправлены быстрый Push до refresh и пустой пароль из CR+LF; native
cancel/rejection/retry, masked input и реальный pre-push. Windows24 distinct
checks на конечном runtime, Ubuntu final24 PASS; полный regression не заявлен.
Очередь5 Bash debug готова Windows+WSL2/Ubuntu (§215): default native PTY,
F9/F5/evaluate/output/edit-repeat/launch.json/Stop, missing Node/adapter;
по17 distinct selected PASS. Продолжение §217: interactive stdin/scrollback/Stop,
исправлен IDE-128 (Stop завершал чужие Editor jobs); Windows21 distinct selected
PASS/Ubuntu21 PASS, явный :BashDebugPrepare. Mac/physical/cold отдельно.
Очередь4 worktree IDE-038/048 остаётся открытым расследованием: прежних logs
недостаточно для нового причинного исправления. Проверка следующего кандидата
показала: passive window lookup уже объединён в §185, повтор этого refactor
не нужен. Выбор владельца 2026-11-13 (§216): breadcrumbs (navic+barbecue)
и Satellite нужны и сохраняются; удаление исключено из очереди. Дальнейший
refactor сохраняет эти функции. SQL references ждут готовый provider.
Отдельные Windows native quit IDE-121 и старый rebase-start timeout IDE-124
не закрыты исторически; old rebase-abort на новой версии PASS (§214), причина
исходного timeout без лога не установлена. Полный Windows regression PASS не заявлен. Mac/physical
и полная mixed матрица отдельно. Docker engine использован без lifecycle изменений.

Продолжение WF-01 (§218): Logs возвращает открытость/высоту/scroll по tabs,
источник и фильтры проекта, в том числе при всех скрытых окнах. Windows10
selected PASS/Ubuntu10 PASS; прежние Files/project/legacy сохранены. Один
sidecar/session backend, без возобновления процессов. Следующий срез —
Outline завершён первым срезом (§219): открытость/ширина и native symbols/follow,
Windows6 PASS/Ubuntu6 PASS вместе с Files/Logs/Outline focus. Tests и размеры console/debug реализованы §220, с открытым Windows quit gate IDE-129.

Решение владельца 2026-11-13: Terminal/Debug после полного перезапуска
скрыты до явного открытия/запуска; тогда применяется сохранённый размер.
Новые shell/debug процессы восстановление сессии не запускает. Реализовано
§220; новый функционал PASS Windows/Ubuntu, полный Windows gate IDE-129 открыт.
Tests: первым срезом native открытость/геометрия. У Neotest есть open/close/
expand/target, но нет public getter полного состояния раскрытий; private
summary internals не сериализуем и собственный parser дерева не добавляем.

Один ограниченный пункт → изменения → один прогон нужных тестов → отчёт и
commit при успехе. Затем самостоятельно следующий пункт. Остановка — по
завершении плана, при полном упоре в натурные проверки владельца или отсутствии
продвижения, с явным объяснением. Общий автономный goal остановлен. Развитие тестовой
инфраструктуры отложено до отдельного понятного плана прогресса; существующие
E2E используются для защиты изменений продукта.

Последнее уточнение владельца: итерации продолжаются в одном заходе без
нового «дальше». FAIL сохраняется и разбирается; обоснованная правка открывает
следующую итерацию с одним прогоном новой версии. Повтор неизменённой версии
ради зелёного запрещён. Остановка — при реальном блокере или завершении очереди.

| Очередь | Результат | Статус |
|---|---|---|
| 1. Этап 6: упрощение панелей/DAP | Сократить доказанные дубли по готовому review | §185: два window lookup цикла объединены; §197: общая подготовка восьми navigation-команд. Breadcrumbs/Satellite сохранены по выбору владельца (§216), их удаление исключено |
| 2. Оформление Termide | Довести Code/Locals pilot до решения для повседневной работы, затем остальные панели | Общий цветной zoom готов на Windows (§199); постоянные рамки split и physical review открыты |
| 3. Реальные проекты | Go/Cargo workspace, Python venv, Node scripts, выбор цели и launch.json/default | Go.work §206–208 и mixed context/Node script/Python venv debug Windows/Ubuntu9 PASS (§209–211); остальная mixed матрица открыта |
| 4. Git | Credentials, interactive rebase и оставшиеся ошибки worktree | Sequence и HTTP credentials Windows/Ubuntu (§212–214); worktree IDE-038/048 и real OAuth/SSH/Mac открыты |
| 5. Языковые пробелы | Bash debug с готовым backend; SQL references при наличии подходящего provider | Bash default/launch.json и interactive input/Stop Windows+WSL2 и Ubuntu21 selected PASS (§217); Mac и explicit console IDE-127 отдельно. SQL references ждут готовый provider |
| 6. Переносимость | Чистый setup Windows/Ubuntu/macOS, terminal/SSH; Mac startup/Go и Cmd+C | Частично; native Mac и физические клавиши не проверены |

Завершён Windows срез `restore-files-session-view` (§205): видимость/root,
раскрытия/выбор/scroll/width Files по вкладкам и проектам.16 distinct checks
PASS на конечном runtime; расширенный case дополнительно проверил меньший UI,
нативный Ctrl-w > и same/new-file follow. В Ubuntu конечный workflow завершился
успешно, но весь E2E FAIL из-за известного POSIX scope probe IDE-117 при cleanup;
общий предыдущий Ubuntu selected15 PASS/1 FAIL по той же причине. Gate открыт,
повтором не маскируется. Mac/physical и остальные панели WF-01 остаются открытыми.
Следующий шаг очереди3 выполнен: Go.work debug/edit-repeat Windows1 PASS /
Ubuntu1 PASS (§206), без изменений runtime. Go.work Tests также завершены (§207): Windows12 PASS/Ubuntu12 PASS selected,
исправлен backend infinite walk без новых зависимостей. Следующий конкретный
шаг Go.work LSP выполнен (§208): Windows1 PASS/Ubuntu1 PASS, gd/back/gi type/
gi method/gr/выбор через один настоящий gopls, runtime не менялся. Теперь —
mixed context Windows/Ubuntu9 PASS (§209–211); остальная mixed матрица/Mac/physical
открыты. Очередь4: interactive rebase и HTTP credentials готовы (§212–214);
далее worktree IDE-038/048, real OAuth/SSH/Mac отдельно.

Последняя итерация пункта 1: `deduplicate-panel-navigation`, FIXLOG §197.
Повторная подготовка заменена одной локальной функцией, net−8 строк runtime.
Единственный selected Windows прогон: Debug5/work-panels6/Outline6/Git6/frame1,
итого24 PASS/0 FAIL/0 SKIP,15 native profiles. Ubuntu/macOS этой итерацией
не проверены. Это не закрывает весь этап 6 и не является новой фичей.
Дальше — очередь ниже по последнему уточнению владельца.

Последняя итерация пункта 2: `style-panel-zoom-borders`, IDE-PANEL-24, §199.
Один исправленный debug-panels прогон дал6 PASS/0 FAIL/0 SKIP, включая12 native
RGB состояний Locals/Output/Files/Logs и прежний сценарий после него. Суммарное
выбранное покрытие Windows —34 разных checks: эти6 плюс28 из пяти неизменных
файлов предыдущей итерации. Runtime прежний; исходный33 PASS/1 FAIL сохранён
в §198. Ubuntu/macOS/physical review отдельно; постоянные рамки split открыты.
Пункт3 продолжен Cargo picker (§200); следующий конкретный пробел по уточнённым
кейсам владельца — WF-01/02, состояние Files (текущий результат выше).

## Основные пользовательские сценарии — уточнение владельца 2026-11-12

Это целевые рабочие кейсы, по которым принимается продукт. Наличие плагина
или зелёного теста части сценария не закрывает весь кейс. «Частично» означает,
что есть работающие части, но весь описанный цикл ещё не подтверждён.
Windows/macOS/Ubuntu — целевые ОС; натурные проверки владельца отмечаются
отдельно. Основной проект может одновременно содержать все поддержанные языки.

| ID | Кейс | Текущая точка |
|---|---|---|
| WF-01 | Открыть проект и восстановить рабочее место | Files/Logs (§218), Outline visibility/width/native follow (§219): Windows/Ubuntu6 selected PASS. Tests/native deferred Terminal/Debug §220: core3 PASS Windows/Ubuntu, Win quit gate IDE-129; Mac/full view-state открыты, старый IDE-117 не закрыт |
| WF-02 | Перейти в другой репозиторий и вернуться | Files/Logs/Outline A→B→A Windows/Ubuntu PASS (§218–219), hidden panels и filters проекта. Tests/deferred console/debug §220, core3 PASS Windows/Ubuntu; Mac/IDE-129/full view-state открыты |
| WF-03 | Управлять файлами через дерево | Create/rename/move/copy/delete/filter проверялись; единый цикл и сохранение вида дерева входят в приёмку |
| WF-04 | Работать в проекте со смесью языков | 6 native roots/cwd + Node script/Python venv debug Windows (§209–210); полная mixed matrix/Mac открыты |
| WF-05 | Запустить файл или конкретный debug-кейс | Cargo/Go.work есть; mixed Node script и Python default из nested venv Windows/Ubuntu (§209–211) |
| WF-06 | Отлаживать с Output, консолью, переменными и стеком | Основные панели/пауза/output есть; Bash stdin/scrollback/Stop с живым чужим job Windows/Ubuntu PASS (§217). Полный mixed цикл/Mac/physical открыты |
| WF-07 | Исправить код и перезапустить тот же кейс | Go.work dependency edit→F5→42/43 проверен Windows/Ubuntu (§206); смешанный workflow целиком открыт |
| WF-08 | Посмотреть цветной diff и выбрать изменения для коммита | Hunk/stage/unstage/diff/history есть; выбор отдельных строк обязателен в полном кейсе |
| WF-09 | Commit и push с понятным результатом | HTTP Basic cancel/rejection/retry и pre-push Windows/Ubuntu (§213–214); real OAuth/SSH/Mac и оставшиеся ошибки отдельно |
| WF-10 | Навигация по коду, включая реализации | Go.work gd/gi type+method/gr/back Windows/Ubuntu (§208); остальные языки имеют отдельные workflows, mixed/Mac открыты |
| WF-11 | Поиск файлов/текста и палитра команд | Основные действия есть; единая проверка из кода и панелей входит в приёмку |
| WF-12 | Тесты проекта в общей панели | Go.work discovery/nearest/file/all/fix/Output Windows/Ubuntu (§207); по языкам есть отдельные workflows, смешанный проект открыт |
| WF-13 | Единая навигация внутри рабочих панелей и чтение вывода | Space w есть; native Bash Output scroll/search→stdin→Stop Windows/Ubuntu PASS (§217). localvox-light референс, общий кейс/оформление открыты |

### WF-01. Открытие и восстановление проекта

1. Открываю репозиторий, файлы, несколько вкладок и при необходимости split.
2. Раскрываю каталоги в Files, выбираю файл, прокручиваю дерево.
3. Расставляю панели, меняю их размеры и положение, прокручиваю содержимое.
4. Закрываю редактор штатно и снова открываю этот проект.

Ожидается: те же файлы и порядок вкладок, выбранная вкладка/файл, позиции
курсоров и прокрутка кода; дерево с теми же раскрытыми каталогами, выделением
и прокруткой; видимые панели, их стороны, размеры и доступное сохраняемое
состояние. При изменении размера терминала раскладка адаптируется. Удалённый
извне файл не ломает восстановление. Несохранённый текст не теряется молча.
Завершённый процесс после открытия проекта не выдаётся за живой.

### WF-02. Другой репозиторий: A → B → A

Из проекта A открываю B штатной командой выбора проекта/папки, затем возвращаюсь
в A. У каждого своё рабочее место из WF-01. Cwd, Files, Git, поиск, языковые
tools, запуск и тесты относятся к выбранному проекту; старый буфер другого
репозитория не переключает root самовольно. Незавершённые правки защищены.
Сценарий применяется и к linked worktree; чужой процесс не останавливается молча.

### WF-03. Операции с файлами в дереве

Из Files создаю каталог и файл, открываю и редактирую его; переименовываю
или перемещаю. Копирую файл либо каталог, выбираю другую папку и вставляю;
повторно открываю копию и проверяю содержимое. Удаляю выбранный файл/каталог.
Операции доступны с клавиатуры; дерево отражает реальное состояние диска.
Открытые буферы согласованы с новым путём. Удаление защищает несохранённые
правки и корректно обрабатывает отмену. Коллизия имени сообщает результат;
пробелы/Unicode в путях не мешают. После действия сохраняется понятный фокус
и положение дерева, а не требуется искать рабочее место заново.

### WF-04–05. Смешанный проект и запуск

В одном репозитории переключаюсь между Go, Rust, Python, JS/Node.js, Bash и
SQL. Для текущего файла доступны подходящие язык, completion, diagnostics,
format и навигация. Project env/venv/workspace учитываются по смыслу языка,
выбранный root проекта остаётся стабильным.

Запускаю текущий файл/пакет/target или выбираю конкретную конфигурацию отладки.
Явная конфигурация использует свои program/cwd/args/env; без неё доступен
разумный default. При неоднозначности выбираю цель, отмена не запускает первую
попавшуюся программу. Для SQL run означает запрос, DAP применяется к языкам
с готовым debugger. Отсутствующий tool явно отражается в сообщении/IDE Logs
с действием подготовки; обычное открытие проекта ничего не устанавливает.

### WF-06–07. Отладка, исправление и повторный запуск

1. Ставлю breakpoint и запускаю выбранный debug-кейс: открывается Debug.
2. Внизу вижу stdout/stderr; при исключении/панике вижу текст причины.
3. Переключаю нижнюю область между Debug Output, интерактивной DAP-консолью
   и встроенным shell/терминалом по задаче. Вернувшись, вижу прежний вывод.
4. Сбоку смотрю Locals/Watch и стек, раскрываю вложенные значения с клавиатуры,
   выбираю frame; код и значения соответствуют выбранному frame.
5. Делаю step/continue, останавливаю запуск; закрытие/смена панели само по себе
   не продолжает и не завершает программу.
6. Исправляю файл, сохраняю и снова запускаю нужный кейс с его аргументами
   и окружением. Вижу новый вывод и актуальное состояние отладки.

Весь цикл выполняется без мыши. Для панелей одинаково доступны переход
фокуса, скрытие/возврат, zoom, подтверждение/отмена и помощь. Используются
штатные данные и UI готовых backend; нет нарисованных копий переменных или
параллельного владельца процесса ради размещения вывода.

### WF-08–09. Изменения → diff → stage → commit → push

Открываю diff файла и репозитория: добавления, удаления и изменения видны
цветом. Перехожу между hunks, выбираю для stage файл целиком либо конкретные
строки; проверяю staged diff, снимаю часть из stage. В commit попадает ровно
выбранное, прочие правки сохраняются. Пишу сообщение, коммичу и делаю push.
Виден результат либо понятная причина отказа; после исправления повторяю
действие без потери текста/commit. Авторизация реального remote проверяется
отдельно от локальных fixture. Diff/merge/history и работа в worktree сохраняются.

### WF-10–11. Навигация, поиск и команды

Из символа перехожу к definition, references и **implementation**, при
нескольких результатах выбираю, затем возвращаюсь назад. Работает переход
между файлами и применимыми модулями/workspace. Неподдерживаемый сервером
действительный semantic переход явно обозначается; текстовый grep не выдаётся
за implementations. Outline/Peek помогают просмотреть контекст и вернуться.

Быстро нахожу файл по имени и текст по содержимому, открываю выбранный
результат на нужной строке. Из кода или панели открываю поиск команд и нахожу
действие по названию, как в палитре VS Code. Отмена сохраняет рабочее место.

### WF-12. Тесты проекта

Открываю Tests, запускаю тест под курсором, файл или нужный набор проекта.
Вижу результат и вывод, перехожу к упавшему тесту, исправляю и перезапускаю;
при поддержке adapter запускаю его под debugger. Могу остановить исполнение
и вернуться в код. Смешанный проект не запускает посторонний язык/набор без
явного выбора; отсутствие test backend показано в общей консоли логов.

### WF-13. Панели Debug/Tests/Console/Files/Git

Уточнение владельца: референс localvox-light относится прежде всего к
управлению рабочими панелями, а не к переключению файловых вкладок.
Актуальный источник: D:/rust_repo/localvox-light, commit8900c58; просмотрены
terminal-workspace.md, app/input.rs, app/navigation.rs, app/paging.rs,
render.rs и пример native TUI. Репозиторий-референс только читался.

1. Явно выбираю панель; её рамка/заголовок показывают фокус. Общие команды
   Space w сохраняются. Ввод текста в terminal/REPL/поиске остаётся вводом.
2. В списках перемещаюсь j/k или стрелками, перехожу страницами и в начало/конец.
   В деревьях раскрываю/сворачиваю узлы и выбираю действие Enter. Выбранная
   строка и прокрутка не теряются при возврате в панель.
3. В Debug раскрываю вложенные Locals/Watch, выбираю stack frame; в Tests —
   тест и его output; в Files — узел/файловую операцию; в Git — файл/hunk/строки.
4. Esc возвращает на ближайший уровень: закрывает подсказку/диалог/zoom;
   из обычной панели позволяет вернуться в код. Скрытие не убивает jobs.
5. В Output/консоли читаю уже напечатанное: двигаю курсор и viewport,
   ищу текст, повторяю поиск, выделяю и копирую. Затем возвращаюсь к концу
   вывода и к вводу. Просмотр истории не посылает команды запущенной программе.
6. Действия и клавиши видны в контекстной подсказке/списке действий,
   пользователь не должен читать конфиг ради обычной операции.

Из localvox-light заимствуем модель фокуса, возврата, сохранения выбора/
прокрутки и обнаруживаемости действий. Конкретные сочетания учитывают
штатные команды backend и Vim; принятые Space w сохраняются.
Визуальное направление владельца — стиль Codex: спокойный фон, тонкие
разделители/рамки, приглушённые неактивные области, один заметный акцент
фокуса и компактные подписи действий. Termide остаётся референсом цельных
рамок. Это предпочтение для следующего UI шага, не объявление смены темы.
Практические текущие клавиши чтения вывода — [PANEL_KEYS](PANEL_KEYS.md).

Порядок доводки: использовать эти кейсы для поиска конкретных пробелов
текущей очереди; отдельное развитие тестовой инфраструктуры по-прежнему
требует собственного понятного плана прогресса. Каждый feature/fix защищается
постоянным E2E, одним нужным прогоном за итерацию и историей результата.
После Cargo picker следующий конкретный продуктовый пробел — WF-01/02:
Files view завершён на Windows: последовательный native restore и точные views,
меньший UI и follow (§205). Ubuntu workflow прошёл assertions, полный gate
блокирует ранее известный POSIX probe. Go.work debug/Tests/navigation из
очереди3 проверены §206–208; дальше — смешанный проект;
остальные панели/Mac и весь WF-01/02 не объявляются завершёнными.

## Предыдущий технический срез и результаты проверок

Завершён текущий срез упрощения панелей/DAP/команд: один владелец переходов
в ide.state (§187), общая подготовка F5/Space dP (§188), удалён устаревший
debugpy filter (§189), сохранён порядок normal-команд (§190). Actual Ubuntu
source/target выполнены: launch routes1, debugpy1 и command order6 PASS;
исходные отрицательные проверки сохранены (§192).

Общие E2E выявили конкретный баг: отложенное открытие Files после общего
restore забирало фокус. IDE-116 исправлен в прежнем Neo-tree lifecycle;
по5 новых target checks Windows/Ubuntu PASS, source на каждой ОС3 RED/
2 controls (§193). Backend, SDK и67 pins/6 patched dependencies прежние.

Общий Windows на dab7bf6:74 файла,71 PASS/3 FAIL;363 checks PASS/3 FAIL/
5 SKIP (§191). Общий Ubuntu на7aa0ba9 с исправленным observer IDE-115:
74 файла,71 PASS/1 FAIL/2 SKIP;351 checks PASS/1 FAIL/6 SKIP (§192).
Это исходные FAIL, их не заменяет selected PASS исправления IDE-116.
Выбранный регресс также выявил независимые IDE-117/118; детали и границы
проверок — verification fix-panel-restore-focus. Mac/physical gate открыт.

IDE-114 выполнен (§194): обычный E2E сообщает nonzero native code/signal
после cleanup; primary error и intentional generic fixtures сохранены.
На каждой ОС source3 RED/2 controls → target5 PASS, selected Windows37 PASS/
2 SKIP, Ubuntu39 PASS. Это не закрывает причины прежних085/117/118.

Незавершённые технические проверки прежнего среза (не текущая очередь):

1. IDE-117: записать полный результат ps probe и воспроизвести отказ scope
   observer Ubuntu; сейчас code/signal/stdout отсутствуют, причина неизвестна.
2. Обзор tools/OS boundaries выполнен на3d0e6b7: разные политики сохраняются,
   общий resolver framework не вводим. Следующий кандидат IDE-119 — native
   managed debugpy fallback. Windows часть выполнена в §196: private layout
   helper, source4/target4 и15 прежних native checks PASS. Frozen7673dd3
   сохранён; Ubuntu gate теперь выполнен (§221): source2 RED/2 controls PASS,
   target4 + regression15 PASS. IDE-119 ждёт native Mac; engine unavailable
   был прежним ограничением, теперь не является причиной остановки Ubuntu.
3. Mac/чистая установка → Bash debug/сложные проекты/Git → общее оформление.

IDE-085 и новый RPC stall IDE-118 остаются диагностикой при новых evidence;
бесконечные повторы общего набора и повышение timeout не являются фиксом.
Desktop/WSL агент не запускает и не перезапускает. Необязательные plugins
сохраняются до отдельного выбора владельца; новые UI фичи сейчас не добавляются.

Основные возможности мини-IDE уже реализованы. Сейчас идёт стабилизация,
а не создание редактора с нуля. Windows/Ubuntu PASS ниже относится к указанным
сценариям; Mac и физические клавиши WezTerm остаются отдельной проверкой.

| Порядок | Что получаем | Состояние |
|---|---|---|
| Проверено Windows/Ubuntu | Надёжное Files: создание/раскрытие/обновление и native filter | IDE-104/105: по44 editor +15 CLI PASS, история §180–181; Mac/GUI отдельно |
| Проверено Windows/Ubuntu | Общая консоль состояния и логов IDE | IDE-106/107: Space w i/:ForgeLogs, source/status/history/filters/report, native restart и late focus; по46 различных editor checks, §182; Mac/GUI отдельно |
| Рабочий opt-in пилот | Аккуратные рамки как в Termide | IDE-076: :ForgeFramePilot, настоящие Code/Locals, шаги/цвет/resize/Space w/session; [команды, цена и ограничения](PANEL_FRAME_PILOT.md), §183. Default/physical gate открыт |
| Обзор: выбор UI получен | Сохранить выбранные функции при упрощении | IDE-080/§216: breadcrumbs и Satellite остаются,67 pins/6 patched dependencies прежние; passive lookup уже выполнен (§185) |
| Первый небольшой refactor | Общий пассивный поиск окон | §185: два повторных цикла заменены существующим finder, net−16 строк; FT/source/window-order/tab/custom callbacks сохраняются, main/create/guard отдельны |
| Остаток функциональности | Bash debug, сложные проекты/окружения, оставшиеся Git ошибки | Готовые backend; SQL references отложен до подходящего provider, собственный LSP не разрабатываем |
| Отдельный платформенный gate | Mac startup/zsh/Go, Cmd+C, реальные клавиши, чистый setup Windows/macOS/Ubuntu | Нужны actual запуски на целевых машинах; Mint отложен |

Редкие native assert, Docker caller и отдельные старые timeout остаются
зарегистрированной диагностикой. Новые данные собираем при воспроизведении;
без новых evidence не подменяем ими бесконечно ближайший пользовательский шаг.
Результат каждого шага: поведение, постоянный E2E, история и commit.

## IDE-106. Общая консоль состояния и логов IDE — обязательная

Пожелание владельца 2026-11-11: централизованно открыть логи нашей IDE и
увидеть, что случилось, чего не хватает, что не найдено или сломалось.

- Одна доступная с клавиатуры точка входа в общей модели Space w и палитре
  команд; help/focus/hide/zoom работают так же, как у остальных панелей.
- Общая хронология с временем, уровнем, подсистемой и понятной причиной:
  startup/setup/config/plugins, LSP/format/completion, DAP, tests, Git/tasks/
  terminal. Инвентаризировать существующие источники и готовый UI до реализации;
  использовать native логи и события, сохраняя подробности исходного источника.
- Показывать missing tool/backend/config, сбой запуска и доступный путь к
  подробному логу. Для известных проблем — конкретная команда подготовки или
  действие пользователя. Недоступный источник и отсутствие ошибок различимы.
- Фильтр по уровню/подсистеме, поиск, переход к подробностям, копирование
  диагностического отчёта; сообщения сохраняются после закрытия уведомления
  и панели. Обозначать границы сессии и доступность логов после перезапуска.
- Пассивное открытие: просмотр диагностики не устанавливает инструменты и
  не запускает отладку/тесты. История ограничена по размеру; общие записи не
  копируют пароли, токены или содержимое пользовательских переменных окружения.

Готово, когда из редактора без мыши можно вызвать настоящий missing-tool
и реальный сбой подсистемы, затем в одной консоли найти причину, подробный
источник и способ исправления. Восстановление после подготовки, поиск/фильтр,
закрыть/открыть, пустое состояние и границы хранения получают постоянные E2E.
Windows/Ubuntu проверяем нативно/в контейнере, Mac и physical GUI отдельно.
Реализовано в add-ide-log-console, [команды и границы](IDE_LOGS.md), §182.
Windows/Ubuntu: основной selected regression44, затем tail2 и повтор source8
после последней правки reader —46 различных checks на ОС. Мак/physical GUI
остаётся отдельным gate; global full suite этим набором не подтверждён.

Рабочий frame pilot IDE-076 выполнен в §183, актуальный список сокращений —
§184, первая дедупликация пассивного window lookup — §185. Следующие удаления
UI зависят от выбора владельца; физическая оценка WezTerm и Mac — отдельные
задачи, готовые headless проверки их не заменяют.

## Сделанное и границы проверок — 2026-11-11

| Порядок | Работа | Результат и граница |
|---|---|---|
| Готово | IDE-043: читаемые ошибки Git | Коммит 5e4dfe8; OSC/title удалены, пользовательские Git E2E Windows/Ubuntu прошли |
| Готово | Test-only cleanup IDE-047 | Коммит fa33150, E2E и §107; причина первичного RPC остаётся отдельной диагностикой |
| Готово | IDE-041: E339 на очень длинном слове | Общая защита, по 3 UI + 10 smoke PASS Windows/Ubuntu; §108 |
| Готово | IDE-009: основные рабочие панели | Tests/Test Output/Search/Tasks в Space w, query сохранён, по 6 новых + 19 прежних UI PASS Windows/Ubuntu; §109 |
| Готово Windows/Ubuntu | Go LSP/format и IDE-050 | По 6 language UI PASS, fallback исправлен (§110); Ubuntu image/прогон выполнены, Mac открыт |
| Готово на Windows | JS/Node и IDE-051 | 8 новых UI PASS: LSP/Prettier/Tasks/js-debug/Jest и missing tools (§111). Ubuntu 8 UI PASS после build, Mac открыт |
| Готово на Windows | Python, IDE-052/053 | 8 real UI PASS: venv/LSP/Ruff/debugpy/pytest; общий selector и классификация ожидаемого adapter close (§112–113). 29 прежних UI PASS; Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | Rust/Cargo, IDE-054/055 | 8 real UI PASS; пути/argv/JSON test adapter и output исправлены (§114–115), 37 прежних UI + 9 backports + 364 checks PASS; [команды](RUST_WORKFLOW.md). Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | Bash edit/run/tests, IDE-056/058 | 8 real UI PASS: sourced LSP, shfmt, Tasks и Bats; Unicode rename исправлен (§116–117). [Команды](BASH_WORKFLOW.md). Ubuntu language workflow также проверен; Mac открыт |
| Готово на Windows | SQL editor/query, IDE-060/061/063–068 | 20 SQL UI + 2 SDK CLI PASS, native SQLS comments fix/readiness и cache Results при смене workspace (§119–128); 6 common panel UI и 365 unit/trace PASS. Прежние 72 UI/9 backports сохранены как отдельный прогон. Ubuntu 20 SQL UI/2 SDK также PASS; Mac/ARM64/внешние DB не проверены |
| Готово на Windows | IDE-062: SQLLogicTest в Tests | 12 native SDK checks и 12 editor UI PASS (§129–132): nearest/file/all, expected/fix/rerun, stop/output/panels; общий All и native paths исправлены. [Команды](SQL_TESTS.md). Ubuntu 12 SDK/12 UI PASS; Mac открыт |
| Готово на Windows | IDE-075: lifecycle и Windows integration gate | Собственный process scope, 5 новых native E2E и 4 source RED; 111 checks PASS/2 POSIX SKIP, 365 unit/trace, 64 strict valid (§136). Ubuntu/Mac и причины IDE-073/074 открыты |
| Готово Windows/Ubuntu | IDE-077/078/079: process lifecycle и observers | Ubuntu 119 PASS/1 Windows-only SKIP, 365 unit/trace; Windows 27 текущих checks PASS (§137–139). Product Lua/67 pins прежние; Mac/GUI открыты |
| Обзор готов, выбор удалений открыт | IDE-080: фичи, слои, цена и coverage | [Общий обзор/рекомендации](FEATURE_REVIEW.md), [все 67 plugins](PLUGIN_INVENTORY.md), DAP/root/tool ownership и bounded native baseline. Большой переписи нет; UX-удаления ещё не выбраны |
| Готово Windows/Ubuntu | IDE-082: пассивная Go metadata / late Delve | По 27 native E2E, real gopls restart и late override F5, по 2 diagnostic profiles; §148, Mac gate открыт |
| Готово Windows/Ubuntu | IDE-083: Peek с клавиатуры | Готовые Glance defaults, по 7 новых + 22 прежних native checks и по 1 повтору исходной диагностики; §149, Mac gate открыт |
| Готово Windows/Ubuntu | IDE-084: фокус при позднем дереве | Neo-tree cleanup сохраняет выбранное окно; по 3 новых + 23 прежних E2E и по 3 cold samples, §150; Mac gate открыт |
| Готово Windows/Ubuntu | IDE-081: native fzf / fallback | По 5 новых checks (4 editor + health) и 25 прежних; настоящий C scoring без CMake, health, F5 picker; §151, Mac gate открыт |
| Capture готов, причина открыта | IDE-085 | Повторный source RED, 3 native trace E2E и helper source/quit/error capture; Windows 19 PASS/2 SKIP, Ubuntu 20 PASS/1 SKIP (§152). При следующих регрессах собирать новый timeline; product fix не заявлен |
| Готово Windows/Ubuntu | IDE-086: общая политика Output | Один resolver, сохранение REPL/PTY/history; по 19 native checks и 13 clean exits/scopes; §153. Mac открыт |
| Диагностика при новых evidence | IDE-087: остановка Docker backend | Второй event 17:45:10 совпал с native qa! Windows, root/scope завершились штатно. [Native PPID гипотеза и границы](WINDOWS_PROCESS_DIAGNOSTICS.md), §154/157; caller неизвестен, Desktop/WSL агент не управляет |
| Обзор готов Windows/Ubuntu | Поиск окна кода | [Сравнение и native evidence](CODE_WINDOW_REVIEW.md): по 5 profiles, роли find/create/relocate различаются; полный merge не нужен (§155) |
| Готово Windows/Ubuntu; Mac открыт | IDE-088: focus-only выбор окна кода | По state predicate и прежнему tool filter;3 source RED и22 Windows checks (§156). Ubuntu22 checks/16 native profiles PASS (§170), root0/APIerrors[]/own scopes empty |
| Native proof готов | IDE-087/089: process ancestry | Read-only live age inversion + exact pinned C fragment: valid PASS/stale RED; guard prototype 4 native PASS, own Jobs clean (§158). Тогда SDK не менялся; следующий шаг выполнен в §159, Docker caller открыт |
| Готово Windows | IDE-089: Windows SDK creation-time guard | Два закреплённых patch, Schema 2, staging/rollback; actual source guard 4 PASS + 3 expected upstream RED, Windows 49 PASS/24 captured editor profiles. SDK выбран; после продвижения quick 353, SDK CLI 11, lifecycle 2 PASS; strict 75 (§159). Linux/macOS backend прежний |
| Готово Windows/Ubuntu; Mac открыт | IDE-090: delayed Debug reopen | Source startup-hide RED→Windows PASS (§164). Ubuntu running→hide→actual stopped/Locals42→same PTY PASS и22 соседних checks (§170). Единственность caller исторического одиночного failure не утверждается |
| Готово Windows/Ubuntu; Mac открыт | IDE-091: PTY в общем Debug toggle | Две строки в прежних routes,2 Windows source RED→PASS (§160); Ubuntu оба native CodeLLDB cases PASS (§170). Toggle сохраняет channel/буфер/паузу, F5 дописывает в тот же PTY |
| Готово Windows CLI | IDE-092: staged SDK source | Проверка путей/patch diff относительно HEAD; CLI staged RED → оба staged/unstaged PASS до source mutation, SDK CLI12/quick353/strict76 (§161). Binary прежний, SDK не пересобирался |
| Capture готов, механизм воспроизведён | IDE-090: delayed startup reopen | §162: trace/failed attempts, native watchdog caller1419 после hide. Runtime исправлен и permanent regression добавлен в §164 |
| Готово Windows/Ubuntu test harness | IDE-093: viewport padding в history assertion | Terminal-only semantic compare,5 loss/padding vectors (§165); Ubuntu native resize PASS после readiness fix IDE-098 (§170), Windows также PASS. Raw data не переписаны, Mac не запускался |
| Готово Windows test harness | IDE-094: dangling Windows junction | Source malformed RED →3 native link PASS, ещё10 lifecycle/descendants PASS и1 POSIX-only SKIP. Четыре owned остатка удалены; negative debug cleanup теперь проходит (§163), quick353/strict78. Ubuntu/Mac не запускались |
| Готово Windows/Ubuntu; Mac открыт | Project/session native baseline, IDE-080 | Настоящий TUI: quit/relaunch/Space qs и A→B→A,4 backend PID,3 files/2 tabpages/cursors/unsaved edit/panels. Windows §166, Ubuntu native §170; [границы](PROJECT_SESSION_REVIEW.md) |
| Готово Windows/Ubuntu; Mac открыт | IDE-095: фокус после project restore | Source RED→5 Windows native cases (§167), те же5 Ubuntu PASS (§170). Второй callback удалён, listed-file fallback сохранён перед reveal; production net -8 строк |
| Готово Windows/Ubuntu test harness | IDE-096: фильтр Python SELF suites | Общий early matcher, native source3RED/4PASS→7 Windows PASS (§168), Ubuntu7 PASS (§170). Выбранные ошибки/UTF8/no lookup/no spawn сохранены, Mac не запускался |
| Диагностика открыта | IDE-097: native TUI wstream assert | Raw FAIL сохранён. Подготовлен [явный stack capture](NATIVE_ASSERT_DIAGNOSTICS.md),4 Windows control E2E;4 bounded original trials без assert (§169). Actual caller ещё не снят; product/SDK прежние, нужны minimal repro и native regression |
| Готово Windows/Ubuntu test harness | IDE-098: native readiness resize fixture | Source Ubuntu FAIL→одинаковый native CodeLLDB PASS Windows/Ubuntu, actual viewport/rows и raw mismatch обязательны (§170). Shared helper/product/SDK прежние, без OS branch/sleep |
| Готово Windows/Ubuntu; Mac/GUI открыт | IDE-023: native terminal escape | Одна expr-привязка, source5 RED/1 control →6 native PASS и22 соседних E2E на каждой ОС (§171). Terminal-input/normal, completed/live/managed и paused DAP; PID/channel/history сохранены |
| Готово Windows/Ubuntu; Mac/GUI открыт | Terminal/Trouble, IDE-099/100 | Space w T/x, common controls, current-view hide и native Trouble actions;9 новых +30 прежних E2E/source8 RED на ОС (§172). Show больше не скрывает native toggle; штатная help остаётся popup |
| Прототип готов; общий стиль открыт | IDE-076: цельная цветная рамка | Реальные Locals/Delve, RGB active/dim/resize/restore, компактный образец и [сравнение](PANEL_FRAME_REVIEW.md); default style прежний. Постоянные рамки split и Mac/GUI отдельно (§173) |
| Готово Windows/Ubuntu; Mac/GUI открыт | IDE-101: docking zoom при помощи | Документированный window-local Edgy opt-out, source RED → native IDE-PANEL-18 PASS; исходный slot/shared buffer сохранены, исчезнувший source возвращает код (§173) |
| Готово Windows/Ubuntu; Mac/GUI открыт | IDE-102: POSIX shell при optional pwsh | Source Ubuntu RED→2 policy PASS; Windows actual pwsh/fallback2 controls PASS. По29 соседних native E2E на ОС,3-line win32 guard в прежнем opts; SDK/pins/global shell прежние (§175) |
| Проверено Windows/Ubuntu; Mac/GUI открыт | Files copy/delete, IDE-103 | По3 source RED/6 controls →9 новых E2E PASS на ОС. До/после Yes защищены modified/hidden/late buffers; latest29 PASS на ОС, известный legacy отказ отдельно IDE-104 (§176–177) |
| Проверено Windows/Ubuntu; Mac/GUI открыт | IDE-104/105: coherent Files snapshot и native filter | 9 native E2E после source RED; pending intent/full-partial overlap/watchers/filter/clear. По44 editor +15 CLI PASS на ОС,101 root audit;2 native файла (+41 строка net) через existing backport, SDK binaries/pins прежние (§180–181) |
| Отложено до готового backend | Остаток SQL workflow, IDE-062 | SQLS references provider отсутствует. Собственный binder/index/LSP fork отменён (§143); не подменять references grep и не объявлять полную SQL поддержку |
| Затем | Остальная [матрица языков](LANGUAGE_MATRIX.md) | SQL references IDE-062, Bash DAP IDE-057; Mac/native и оставшиеся сценарии матрицы |
| После конкретного feature review | Упрощение архитектуры | Общее ядро, явные системные границы и setup; сокращение дублирования с сохранением E2E |

IDE-090/093/094 закрыты на Windows в §164/165/163. Доступные Ubuntu gates
IDE-088/090/091/093/095/096 выполнены в §170:31 native editor checks/25 profiles
и7 CLI, quick358/trace11. Найден и исправлен race readiness самого resize E2E
(IDE-098), raw FAIL сохранён. Уже работающий image использован без build/pull;
optional tests/containers/limits.yaml закрепляет проверенные2CPU/3GiB/256pids.
Mac/GUI и оставшаяся языковая матрица открыты, собственного SQL binder/LSP нет.
Read-only engine check после31d154f снова не нашёл dockerDesktopLinuxEngine;
Desktop/WSL не запускались. Native project/session baseline завершён на Windows
в §166: реальные разные backend, files/cursors/tabs/cwd и панели сохранены;
production root/session glue тогда не менялся. IDE-095 выполнен следующим
шагом (§167): один LoadPost вместо второго cleanup/open, необходимый fallback
проверен настоящей Help-only сессией. IDE-096 завершён следующим шагом (§168):
Python SELF теперь использует общий --id filter. Для IDE-097 готов явный capture
(§169); caller пока неизвестен, green repeat не считается исправлением.
Terminal/Trouble завершили общую normal модель Windows/Ubuntu в §172;
IDE-023 устранён в §171. UI prototype рамок IDE-076 и найденный docking
zoom IDE-101 выполнены в §173. После Files ближайший обязательный пункт —
общая консоль логов IDE-106 выполнена Windows/Ubuntu (§182), рабочий пилот
рамок — §183. Перед упрощениями —
конкретный выбор сокращений по FEATURE_REVIEW. Остаток языковой матрицы
сохраняется отдельной очередью. Прототип не включает рамки всех панелей по умолчанию.
Mac/GUI gates остаются отдельными.
§169 добавляет проверенный explicit capture через bundled CodeLLDB/PDB:
4 control E2E,4 original trials без воспроизведения. Системный LLVM LLDB
требует отсутствующий python310.dll (вероятное окно ошибки владельца), повторно
не запускается. IDE-097 остаётся открыт; выбранный SDK не пересобирался.
Read-only проверка 21:51 MSK: Desktop/backend процессов и engine pipe нет,
логи заканчиваются старым событием17:45, нового startup не видно. Container
не запускался; отсутствие engine не выдаётся за новый crash от этих тестов.
Read-only check22:43MSK также не нашёл pipe (.tests/ide095-engine-check.json).
Ubuntu IDE-095 не запускался; Desktop/WSL агент не запускал и не перезапускал.
Read-only check23:18MSK также не нашёл pipe (.tests/ide096-engine-check.json).
Ubuntu IDE-096 не выполнялся; SDK/client Docker не перенастраивались.
IDE-091 исправлен отдельно (§160); источник исторического одиночного failure
без trace не объявляется единственным. IDE-088/090/091 Ubuntu gates были открыты:
последняя read-only проверка Linux engine не нашла pipe. Desktop/WSL агент
не запускает/перезапускает; доступность Docker не подменяется Windows PASS.

IDE-082 / fix-passive-go-discovery: runtime исправлен, [Go команды](GO_TOOLS.md).
Windows/Ubuntu по 27 PASS с реальным gopls restart, 42 native profiles/source/
exit/scopes проверены, плюс по 2 diagnostic profiles. Временный недоступный
engine после включения Desktop владельцем доступен, расширенный suite прошёл.
Mac gate остаётся открытым, change не архивируется до native проверки.

IDE-083 / fix-peek-keyboard-mappings: ошибочный mappings override удалён.
`gpd/gpr/gpt/gpi`, закрытие, references, splits и фокус проверены через настоящий
gopls на Windows/Ubuntu: по 29 checks, по 15 native profiles + 1 diagnostic,
exit/scope/source проверены. Управление — [QUICKSTART](../nvim_forge/QUICKSTART.md#peek-как-ctrlclick-в-ide).
Исходный E21 сохранён в §147/149; повтор диагностики теперь GREEN.
Native Mac/GUI не запускались. IDE-084 также исправлен отдельным change:
preserve-focus-during-tree-cleanup, по 26 E2E Windows/Ubuntu + по 3 cold traces.
Поздний Neo-tree открывался после Outline, а Edgy on_hide переводил фокус
в код; guard теперь сохраняет действительное выбранное окно через public API.
IDE-081 также готов: optional native sorter выбирается реальной загрузкой,
без проверки compiler PATH. [Поиск и подготовка](SEARCH.md); по 30 checks,
20 editor profiles + один native health process Windows/Ubuntu, 78 config
sources/exit/scopes проверены. Ubuntu SDK слои взяты из cache, native добавлен
поздним слоем; runtime ничего не собирает. Единичный старый qa! → SIGTERM
сохранён как IDE-085, зелёный повтор не объявлен его исправлением.
Bounded IDE-085 дал повторный исходный RED и проверенный capture (§152),
первопричина остаётся открытой. Наблюдение продолжается в следующих E2E,
пределы cleanup не увеличены. Output policy реализован на Windows (IDE-086,
§153), повтор Ubuntu после включения engine также прошёл. Далее поиск окна кода по
PANEL_OWNERSHIP_REVIEW; большие lifecycle переписи не начаты.

**Mac параллельно:** IDE-001 (zsh/Go до запуска nvim) и IDE-002 (Cmd+C)
ждут измерений/GUI на Mac. Сборщик startup готов; после trace исправляется
конкретный инициатор. Windows и Ubuntu не заменяют такую проверку.

SQL Tests Windows шаг сохранён в `eeae06c`; IDE-075 и его Windows regression
gate завершены (§136). [Process lifecycle](../openspec/changes/fix-editor-descendant-lifetime/tasks.md)
имеет 5/7 задач: Ubuntu часть проверена, Mac/native platform verification остаётся открытой.
Работа возобновлена; текущее уточнение владельца — IDE-080 review до рефакторинга.
IDE-073/074 остаются отдельно. Доступные Ubuntu проверки используют уже
запущенный engine без управления Desktop/WSL.

IDE-080, следующий срез: upstream source/backports проверены по exact SHA,
частный вариант без четырёх secondary UI plugins прошёл по 28 core UI E2E
Windows/Ubuntu. Idle/text-buffer snapshots не являются общим startup benchmark;
рабочие фичи пока не удалены, выбор UI ещё обсуждается. Native fzf readiness
выделен в IDE-081: loaded-флаг и рабочий picker не доказывают native sorter.

DAP/panels разобраны в [карте ответственности](PANEL_OWNERSHIP_REVIEW.md):
по 9 неизменённых native E2E Windows/Ubuntu с trace; repeated show не равен
recreate. Кандидаты — единая политика Output и совпадающие части поиска окна
кода. PTY/session cleanup остаётся отдельной ответственностью. Runtime не
переписывался; выбор вторичных UI и оставшаяся часть общего review открыты.

Git/workspace/tools/save разобраны в [WORKSPACE_TOOL_REVIEW](WORKSPACE_TOOL_REVIEW.md).
Выявлен IDE-082: до debug запускаются синхронные Go env для Delve, а статуслайн
запрашивает go version; auto toolchain work подтверждён offline Windows/Ubuntu.
После review это приоритетный небольшой fix с RED и Go language/debug/tests.
Глобально запрещать GOTOOLCHAIN=auto или переписывать готовый LSP не планируется;
исходная задержка zsh до nvim на Mac этим не объяснена.

Фактическая часть большого review сведена в FEATURE_REVIEW (§147): coverage
всего ядра/явные gaps, 3 project/focus/idle samples на Windows и Ubuntu.
Исходный Peek q был RED 6/6 (IDE-083); fix §149 вернул готовые Glance defaults
и прошёл постоянный regression. Breadcrumbs/ruler сохранены по решению
владельца 2026-11-13 (§216); готовый Peek также остаётся в текущей сборке. IDE-081/082/083/084 завершены на Windows/Ubuntu; далее
IDE-086 Output policy проверен на Windows/Ubuntu;
IDE-085 остаётся наблюдаемым открытым расследованием.
Mac/GUI gates открыты.

SQL references — [отдельный change](../openspec/changes/add-sql-semantic-references/tasks.md):
§142 сохраняет исходный RED и исследование собственного resolver. Этот подход
отменён (§143): не строить своё language ядро ради полноты матрицы. SDK forge.1
и прежний workflow сохранены. Возвращаться к интеграции только после выбора
готового поддерживаемого backend; IDE-062/IDE-SQL-9 остаются открытыми.

**Ограничение текущего шага:** полный Ubuntu IDE-047 — 43 PASS/1 FAIL/3 SKIP,
653 checks. Cleanup/процессные проверки прошли; новый FAIL ожидания Git-read
зарегистрирован IDE-048. Он не становится PASS и не объявляется исправлением
IDE-047. Повторные full без нового изменения/доказательства не запускаются.
Сначала завершается текущий проверенный шаг, самостоятельные проблемы получают
свои ID/воспроизведение и явный приоритет; объём шага не расширяется молча.

Для каждого исправления остаются обязательными воспроизведение, постоянный
регресс, применимые ОС, история и честный результат PASS/FAIL/SKIP.

## Цель и принятые решения

Терминальная мини-IDE для Go, Rust, Python, JS/Node.js, Bash и SQL.
Активные целевые среды: **Windows, macOS и Ubuntu**. Mint временно отложен.
VS Code — референс возможностей; Claude Code — референс понятного
клавиатурного взаимодействия. Все основные действия доступны без мыши;
мышь остаётся дополнительным способом управления.

- Развиваем существующий `nvim_forge`, без пересборки с нуля.
- `nvim_astro` и `nvim-ide` остаются экспериментами; переносить туда работу
  или удалять их в рамках этого плана не требуется.
- Повседневный запуск shell и редактора отделяем от установки и обновления.
- Для каждого инструмента определяем один основной источник и явные исключения.
- Общая логика IDE едина; системные различия — на границах shell/process,
  путей, clipboard и установки. [Архитектурный план](PORTABLE_ARCHITECTURE.md).
- Каждая фича и каждый исправленный баг получают e2e. Владелец запускает
  VM нужных ОС; репозиторий обеспечивает простые команды и отчёт. [Подход и
  матрица покрытия](../tests/e2e/README.md). Unit не заменяют e2e.
- Основной объект e2e — **редактор nvim_forge с реальными плагинами и
  проектами**, включая файлы, окна, LSP, completion, DAP, тесты и Git.
  WezTerm — отдельная граница ввода/GUI/clipboard, а не замена e2e редактора.
- Сначала устраняем задержки и потерю вывода, затем выравниваем UX,
  расширяем языки и только после этого сокращаем архитектурную сложность.

## Как ведём работу

Это основной маршрут работ, а не описание уже реализованного поведения.
Старый `docs/PANELS_PLAN.md` — контекст прежних решений по панелям.

- Новая жалоба получает стабильный ID `IDE-xxx` в [PROBLEMS.md](../PROBLEMS.md).
  Там хранятся исходный симптом, воспроизведение и ожидаемое поведение.
- Здесь ведём приоритет, этап и критерий завершения. Новые проблемы можно
  добавлять по ходу работы; срочные регрессии поднимаем выше расширений.
- Для изменения поведения используем отдельный OpenSpec change по правилам
  `CLAUDE.md`; существующие changes сначала проверяем на пересечение.
  Сам этот план не означает, что все перечисленные изменения реализованы.
- Завершение: воспроизведение → причина → исправление → подходящая проверка
  → docs/FIXLOG → ссылка из инбокса. Не закрываем проблему по одному наличию кода.
- У каждого исправления история: **что было → причина → что сделали →
  проверка/e2e → вывод**. Шаблон — [ENTRY_TEMPLATE.md](history/ENTRY_TEMPLATE.md),
  единая хронология — [HISTORY.md](HISTORY.md). Исторические источники из
  прежнего workspace хранятся в `docs/history/legacy`, планы и гипотезы
  сохраняют свой статус и не становятся доказанными исправлениями.
- Автоматические проверки выполняем в репозитории. Результаты, зависящие от
  macOS/GUI, записываем после реальной проверки на Mac, отдельно от Windows.

## Очередь пользовательских проблем

| ID | Приоритет | Симптом / пожелание | Этап | Состояние |
|---|---|---|---|---|
| IDE-001 | P0 | WezTerm: медленные вкладки/clear, повторная загрузка Go 1.26.0 | 1 | Подготовлен пассивный сборщик; нужен отчёт/trace с Mac |
| IDE-002 | P1 | Cmd+C на Mac продолжает не работать | 2 | Повторное воспроизведение поверх прежнего исправления |
| IDE-003 | P1 | При повторном запуске DAP пропало окно вывода | 2 | Go remote/integrated и ранний вывод исправлены; E2E Win/Ubuntu, исходный конфиг/Mac/прочие адаптеры открыты |
| IDE-004 | P1 | После остановки на panic нужен текст ошибки в Output | 2 | Go panic на паузе исправлен; E2E Win/Ubuntu, Mac/прочие адаптеры открыты |
| IDE-005 | P2 | Как перевести фокус в Locals и DAP Output | 3 | Space w d/c/0, индикатор и помощь; real DAP E2E Win/Ubuntu, Mac/GUI открыт (§74) |
| IDE-006 | P2 | Запуск теста под курсором оставляет «No active session» поверх кода | 2 | Go nearest/file/debug и eval исправлены, E2E Win/Ubuntu; исходный Mac/Python/Rust открыты |
| IDE-007 | P2 | Ручной ввод должен сбрасывать неактивный предлагаемый хвост сигнатуры | 2 | Исправлены параметры LuaSnip; 11 E2E Win/Ubuntu, Mac ещё не проверен (§71) |
| IDE-008 | P2 | Outline в левой панели, как в VS Code | 3 | Общий маршрут, единый модуль и 6 E2E Windows/Ubuntu (§76–77); Mac/GUI открыты |
| IDE-009 | P2 | Единое понятное управление фокусом и действиями панелей | 3 | Debug/Outline/Files/Git/Tests/Test Output/Search/Tasks/Terminal/Trouble подключены, E2E Windows/Ubuntu (§74–109,172); Mac/GUI открыт, [шпаргалка](PANEL_KEYS.md) |
| IDE-010 | Сквозной | Универсальная сборка Windows/macOS/Ubuntu; Mint позже | Все | Границы модулей записаны; runtime ещё не переработан |
| IDE-011 | Сквозной | E2E каждой фичи/бага, простые команды для VM | Все | CLI и базовый editor e2e готовы на Win/Ubuntu; Mac и полная матрица открыты |
| IDE-012 | P2 | Отсутствующий codelldb предупреждает уже при открытии Go | 2 | Проверка перенесена на запуск; 3 E2E Windows/Ubuntu, Mac открыт (§72) |
| IDE-013 | P2 | Windows Starship: Git timeout при первом prompt в cs2d | 1 | Лимит 500 мс, повторные WARN подавляются; тёплый замер 212–223 мс, причина первого превышения открыта |
| IDE-014 | P2 | Satellite: Invalid height при закрытии debug-панелей | 3 | Актуальные DAP FT исключены, real UI E2E Win/Ubuntu (§75) |
| IDE-015 | P2 | Neo-tree: follow на закрытом буфере и позднее открытие | 3 | События жизненного цикла согласованы, real editor E2E (§77) |
| IDE-016 | P2 | Файловые операции и общий маршрут дерева | 3 | 7 real Neo-tree E2E, selector/источники и буферы (§78) |
| IDE-017 | P2 | Move повторно добавляет каталог к полному пути | 3 | Штатный absolute input, регресс на диске (§79) |
| IDE-018 | P2 | Отложенный reveal использует путь до rename | 3 | Одно открытие/reveal, ожидание готового renderer (§80) |
| IDE-019 | P2 | Enter/rename из zoom используют прежнюю строку | 3 | Выбор переносится после WinEnter, real E2E (§81) |
| IDE-020 | P2 | Esc иногда оставляет фокус в дереве | 3 | Удалён конфликт <esc>/<Esc>, runtime-regression и 5 циклов (§82) |
| IDE-021 | P2 | Удобные файловые вкладки/выбор/закрытие/reopen | 3 | Общая модель и 8 real editor E2E (§83) |
| IDE-022 | P1 | Закрытие dirty файла меняет окна и запускает autosave до решения | 3 | Confirm до мутаций, защита autosave/Save/Discard/Cancel (§84) |
| IDE-023 | P2 | Ctrl-\ из native terminal открывает ToggleTerm | 3 | Windows/Ubuntu source5 RED→6 native PASS, normal mapping учитывает terminal buffer (§171); Mac/GUI открыт |
| IDE-099 | P2 | Show скрывает терминал, открытый Ctrl-t | 3 | Visibility guard registry open, native :IdeShow source RED→PASS Windows/Ubuntu (§172); Mac/GUI открыт |
| IDE-100 | P2 | Edgy пристыковывает штатную справку Trouble | 3 | Native view metadata filter; отдельный source RED→popup PASS Windows/Ubuntu (§172); Mac/GUI открыт |
| IDE-050 | P2 | Common trim блокирует LSP форматирование без внешних tools | 4 | Общая политика исправлена; RED/6 language UI PASS Windows (§110), Ubuntu/Mac ещё не проверены |

P0 мешает базовой работе; P1 ломает основной сценарий; P2 — поведение и UX,
которые последовательно доводим после критических проблем.

## Этап 0. Зафиксировать основу

- [x] Выбрать `nvim_forge` основной сборкой.
- [x] Разделить старую копию `F:/claude_code/vim/nvim` и актуальный проект
  `F:/repo/forge-nvim`; новые работы вести во втором.
- [x] Записать маршрут, пользовательские проблемы и критерии завершения.
- [ ] Сверить версию/commit и путь реально загруженного конфига на Mac.

## Этап 0.5. Базовый e2e настоящего nvim_forge

Общие команды, Ubuntu-контейнер и минимальный набор самого редактора работают.
10 случаев editor.test.lua пройдены на Windows native и Ubuntu Docker;
Mac остаётся непроверенным. Дальше растим покрытие с задачами этапов 1–6.

- [x] Запускать отдельный настоящий Neovim с `nvim_forge/init.lua`, pinned
  плагинами и изолированными data/state/cache/HOME. Подготовка зависимостей
  — отдельный воспроизводимый шаг; тестовый запуск не скачивает их скрыто.
- [x] Подключить управление и настоящий UI через RPC; пользовательские
  команды и mappings проверять вводом, проходить UIEnter/VeryLazy.
- [x] Базовый набор: запуск сборки без ошибок; открыть/изменить/сохранить файл;
  открыть дерево и выбрать файл; поиск имени/содержимого и переход к результату;
  сменить/закрыть буфер; перевести фокус между кодом и панелью и вернуть его.
- [x] Проверять содержимое файла, активный буфер, видимость/принадлежность окон,
  состояние редактора и ошибки процесса. При падении сохранять logs и состояние;
  ожидать готовности по условию с deadline.
- [x] Прогнать этот один набор Windows native / Ubuntu Docker.
- [ ] Прогнать на Mac теми же командами на машине владельца.
- [ ] Подключить PTY/ConPTY для доставки терминальных клавиш; GUI WezTerm — отдельно.

Готово, когда стартует именно наша сборка и базовые пользовательские действия
проходят без mock-подмены плагинов. Подготовка runner и CLI-тесты этот этап не
закрывают. Блокировку подготовки/запуска фиксируем как дефект с воспроизведением.

## Этап 1. Быстрый и предсказуемый запуск

Во всех этапах: сначала воспроизводимый e2e сценарий; после исправления —
регрессионный тест и результат в применимых целевых средах. Непроверенное
на VM не закрываем наличием mock/unit-проверки.

- [ ] IDE-001: отделить запуск WezTerm, shell, prompt/hooks, `clear` и Neovim.
  Инструкция: [MACOS_STARTUP_DIAGNOSTICS.md](MACOS_STARTUP_DIAGNOSTICS.md).
- [x] Подготовить сборщик сведений одной командой без запуска Go/shell;
  проверки на временных HOME и интеграция в unit-прогон.
- [ ] Найти конкретную команду, файл и hook, вызывающий Go на Mac.
  Проверить `GOTOOLCHAIN`, `GOSUMDB`, пользовательский GOENV, `go.mod/go.work`,
  повторный `source`, shell-плагины и prompt. Пока это кандидаты, не диагноз.
- [ ] Убрать установку/сетевые проверки из shell startup и prompt.
- [x] Перенести автоматическую установку инструментов Neovim в явный setup/update.
  Убраны таймер mason-tool-installer, автоустановка Treesitter и неявный
  registry refresh mason-lspconfig. IDE-BOOT-1: Windows/Ubuntu PASS; Mac — ниже.
- [ ] Подтвердить пассивный старт редактора на Mac: тот же editor e2e.
- [ ] Проверки версии для UI сделать пассивными: не скачивают SDK и не
  блокируют ввод. Различать установленный Go и требование текущего проекта.
- [ ] Составить таблицу инструмент → источник → версия/политика обновления →
  проверка; убрать конкурирующие установки, сохранив нужные fallback явно.
- [ ] Снять время до/после: новая вкладка, первый prompt, Enter, clear, старт nvim.

Готово, когда при обычном открытии вкладок, Enter, clear и старте редактора
нет неожиданных установок/скачиваний; команды-инициаторы найдены, изменение
проверено на Mac и задержка измерена. Целевой бюджет выберем после замеров.
Сборка/тест/дебаг проекта, которому нужен другой SDK, показывают понятное
требование вместо скрытого скачивания из UI. Не отключаем `GOSUMDB` и не
меняем глобально настройки корпоративной сети ради маскировки симптома.

## Этап 2. Надёжность повседневной работы

- [ ] IDE-002: воспроизвести Cmd+C отдельно в shell, при выделении WezTerm,
  в copy mode и при Visual-выделении Neovim; английская и русская раскладки.
  Проверить реально загруженный конфиг и прежний change
  `fix-copy-clobbers-clipboard`. Выделение терминала и выделение редактора
  учитывать как разные источники текста.
- [x] IDE-003/004, Go/Delve: реальный E2E первого/повторного запуска,
  stdout/stderr, remote + integratedTerminal, ранний output, скрытие панелей,
  panic на паузе и после выхода. Вывод сохраняется до нового initialize.
  Windows/Ubuntu PASS, FIXLOG §64–66.
- [ ] IDE-003/004: сверить исходный конфиг владельца, прогнать Mac и отдельно
  Python/debugpy и Rust/codelldb с их каналами stdout/stderr/PTY.
- [x] IDE-006, Go: ближайший успешный/падающий тест, весь файл, debug nearest
  на настоящем Delve, eval 42, отсутствие пустого eval без paused-сессии,
  Esc/q из float и Esc из кода. Windows/Ubuntu E2E, FIXLOG §68–70.
- [ ] IDE-006: исходная последовательность на Mac и Python/Rust. Debug Go
  показывает итог в REPL, neotest оставляет skipped — это отдельное ограничение.
- [x] IDE-007: параметры LuaSnip после настоящего completion; manual вне поля
  отменяет только нетронутые параметры, ввод/Tab/Shift-Tab/Esc/undo сохранены.
  11 E2E Windows/Ubuntu, включая Unicode, multiline и разные буферы (§71).
- [ ] IDE-007: Mac и реальные ответы completion языковых серверов — отдельно
  от уже проверенной общей cmp/LuaSnip цепочки и механизма параметров.
- [x] IDE-012: искать codelldb при запуске его конфигурации; Go/F9 без чужого
  предупреждения, F5 без binary даёт понятный WARN, повтор и код доступны.
  3 E2E Windows/Ubuntu (§72); Mac и positive Rust/C/C++ DAP открыты.
- [ ] Проверить Go/Rust/Python: breakpoint → шаг → variables → output → stop
  → повторный запуск. Для каждого адаптера свой источник вывода и проверки.

Готово, когда каждую исходную жалобу можно воспроизвести до исправления и
показать корректный результат после него; проверенные платформы записаны.

## Этап 3. Единая клавиатурная модель панелей

- [x] IDE-076, исследование/прототип: владелец выбрал цельную рамку и цвет;
  pinned Termide source/Neovim ограничения изучены. Test-only Locals,
  active/dim/help/resize/restore и компактный образец в реальном DAP;
  [сравнение и цена в ячейках](PANEL_FRAME_REVIEW.md), §173.
- [ ] IDE-076, постоянное оформление: выбрать способ рамок обычных split,
  проверить все панели/площадь/Space w и native Mac/physical GUI.
  Прототип — существующий zoom overlay, не готовая замена layout.
- [x] IDE-076, следующий архитектурный разбор: закреплённые Neovim/Edgy/Nui
  проверены, [три варианта и требования к пилоту](PANEL_FRAME_DESIGN.md), §174.
  На этом этапе новая раскладка не внедрялась; overlay на каждый split отклонён.
- [x] IDE-076, рабочий opt-in Code/Locals pilot: живые значения/шаг/вторая
  остановка, общие keys, resize/minimum, hide/reopen/native exit/tab/session;
  `:ForgeFramePilot`, [инструкция и цена](PANEL_FRAME_PILOT.md), §183.
- [ ] IDE-076, физическая оценка пилота Windows/Mac и решение о распространении.

Первый пилот — **Run & Debug**: он сразу проверяет переходы между кодом,
Locals, стеком и Output. После проверки переносим модель на Outline,
файлы, тесты, Git, поиск и задачи.

Все основные рабочие панели используют Space w; [краткая шпаргалка](PANEL_KEYS.md).
Normal mode, прежние aliases сохранены:

| Действие | Ожидаемое поведение |
|---|---|
| `Space w h/j/k/l` | Фокус в соседнюю видимую область; нет соседа — безопасный no-op |
| `Space w d/c/0` | Locals / Output / код |
| `Space w a` | Открыть/сфокусировать Outline слева |
| `Space w e` | Открыть/сфокусировать Files слева |
| `Space w g` | Открыть/сфокусировать Neogit справа |
| `Space w T` | Открыть/сфокусировать managed Terminal |
| `Space w x` | Открыть/сфокусировать Problems/Trouble |
| `j/k` или стрелки в списке | Перемещение по элементам |
| `Enter` | Основное действие выбранного элемента |
| Действия дерева | Пока штатные действия backend; новые h/l без prefix не вводились |
| `Esc` | Отменить локальный ввод/выбор или закрыть временное окно |
| `q` в обычной tool-панели | Спрятать панель, вернуть фокус в код; не завершать DAP/job |
| `Space w z` | Тот же буфер Debug/Outline/Neo-tree/Git в увеличенном overlay / исходное окно |
| `?` | Краткая подсказка по действиям текущей панели |

Принцип: отдельно перемещение фокуса, выбор элемента и изменение раскладки.
Смена фокуса никогда не запускает/продолжает отладку, не убивает процесс и
не очищает вывод. В REPL, терминале и строках ввода печатные клавиши остаются
вводом текста; команды панели действуют после выхода в normal либо через
безопасную общую комбинацию. `Esc` не обязан закрывать постоянную панель.

- [x] IDE-005/009, пилот Debug: выбран Space w, проверены конфликты normal
  mappings, ru/en RPC input, Locals/Output/code, q/Esc/help/zoom (§74).
- [x] Debug: индикатор [focus] и контекстная помощь; прежние aliases сохранены.
- [ ] Mac/GUI и физическая доставка ru/en; PTY Rust/Python. Печатный ввод
  в insert/terminal сохраняется, prefix используется после перехода в normal.
- [x] Outline: общий фокус/help/hide/zoom и переход Enter; 6 real Aerial E2E (§76–77).
- [x] Дерево: общий маршрут, selector/источники, создание/rename/move/cut-paste,
  отмена/конфликт и сохранённые буферы; 7 E2E (§78–81).
- [x] Git status: общий маршрут Space w g, q/Esc/help/zoom (§85).
- [x] Tests/Test Output/Tasks/Search: Space w t/r/b/f, focus/hide/help/zoom,
  query/results/jobs сохраняются; 6 новых E2E Windows/Ubuntu (§109).
  Общая шпаргалка показывает один основной маршрут, aliases m*/p*/P*/D* сохранены.
- [x] IDE-023 Windows/Ubuntu: native Ctrl-\ Ctrl-n и повтор не создают/скрывают
  терминал; completed/live/managed/DAP и normal aliases проверены (§171).
- [ ] IDE-023 Mac/GUI: native запуск и физические клавиши WezTerm.
- [x] Terminal/Trouble Windows/Ubuntu: Space w T/x, common focus/help/hide/zoom,
  literal input/jobs, несколько views и native Trouble выбор из zoom (§172).
- [ ] Terminal/Trouble: native Mac/GUI и физические клавиши WezTerm.
- [x] IDE-102 Windows/Ubuntu: shell policy — POSIX с/без optional pwsh, Windows actual pwsh/
  fallback и сохранение job/history через q/reopen. Native E2E в
  tests/e2e/terminal-shell.test.lua; результаты в §175. Mac/GUI ещё открыты.
- [x] IDE-008 Windows/Ubuntu: открыть слева, найти/раскрыть символ, перейти
  в код, скрыть/вернуть фокус; дерево и Outline заменяют друг друга в left-слоте.
- [ ] IDE-008 Mac/GUI: тот же сценарий на машине владельца.
- [x] Files copy/delete Windows/Ubuntu, IDE-103: native copy file/dir, c/conflict/cancel,
  normal d/zoom/recursive/root refusal, modified/hidden/late guard и save retry;
  [клавиши](FILES_WORKFLOW.md), результаты §176. IDE-104/105 проверены Windows/Ubuntu в §181; Mac/GUI открыт.
- [ ] Дерево: Mac/GUI, modified rename/move, Trash/visual multi-select,
  case-only rename/cross-volume и LSP file operations — расширение матрицы.
- [x] Windows/Ubuntu, буферы/вкладки: общий цикл/picker/BufferLine, safe-close,
  alpha/reopen с курсором; 8 E2E (§83–84). Tabpages/WezTerm не меняются.
- [ ] Буферы: Mac/GUI и физические модифицированные сочетания; Save As dialog
  для unnamed, persistent reopen/session и Git/Diffview матрица отдельно.
- [x] Одна [краткая шпаргалка](PANEL_KEYS.md); основные действия без чтения Lua.

Готово, когда один и тот же сценарий управления проходит без мыши во всех
основных панелях, включая паузу DAP и работающий терминал.

## Этап 4. Языки

Первичная [матрица кода и покрытия](LANGUAGE_MATRIX.md) снята 2026-11-02;
текущие Windows результаты Go/Node/Python/Rust/Bash обновлены в ней отдельно.
Подсветка и общие buffer completion/trim/tasks не считаются готовностью IDE
языка. SQL, Bash DAP и непроверенные целевые ОС сохраняют открытые задачи.

- [x] Первичный аудит конфигурации и покрытия шести языков, без новых PASS.
- [x] Go LSP/format Windows: definition/references/rename/completion/diagnostics,
  внешний/LSP formatter, save/health и cleanup без tools; 6 UI E2E (§110).
- [x] Go language Ubuntu: явный build и те же 6 E2E, вместе с остальной матрицей (§137–139).
- [x] Bash Windows edit/run/tests: 8 real UI, исходный RED и Unicode rename
  регресс (§116–117), без новых plugins и startup installs.
- [x] Bash DAP Windows+WSL2/Ubuntu: IDE-SH-5/IDE-057, default/launch.json/Output/Stop и missing tools (§215).
- [ ] Bash Mac/physical/interactive stdin/cold distro и opt-in console warning IDE-127; nearest debug Bats не поддержан.
- [ ] Матрица Go/Rust/Python/JS-Node/Bash/SQL: LSP, completion, definition,
  references, rename, diagnostics, format, run, debug и tests где применимо.
- [ ] Проверить оставшиеся сценарии языковой матрицы на реальных проектах:
  Go/Rust/Python/JS-Node/Bash/SQL уже имеют Windows/Ubuntu workflow выше;
  SQL references, оставшиеся Bash gates IDE-057/127 и native Mac остаются отдельными пробелами.
- [ ] Проверить venv, Cargo workspace, Go workspace, package scripts,
  локальные зависимости и SQL dialect/подключение при необходимости.
- [ ] Явный `launch.json` имеет приоритет; без него стартует разумный сценарий
  по проекту/языку. При нескольких целях — выбор, при отсутствии инструмента
  — понятное сообщение с командой подготовки.

Готово, когда для каждого языка есть небольшой проверенный рабочий сценарий
и честно указано, какие действия поддерживаются или неприменимы.

## Этап 5. Полный Git-сценарий

- [x] Diff файла/изменений, stage/unstage hunks, история файла и репозитория.
- [ ] Выбор/создание ветки, commit, push; понятные результаты и ошибки.
  Happy path и два отказа push покрыты; credentials и остальные ошибки открыты.
- [x] IDE-GIT-10: rejected push → No force → подробности `$` → обычный retry;
  отсутствующий origin → код → исправление URL → тот же commit. Windows/Ubuntu
  по 2 новых и 6 прежних Git E2E PASS (§102). Хвост title в Windows INFO — IDE-043.
- [x] Worktree, обычный путь: список, создание, переход, удаление с защитой незакоммиченного.
- [x] Общие Space w g/q/z/? и status q/Esc/g?, сохранение полного Git-tab.
- [x] IDE-024: upstream исправление hunk patch Windows, без собственного Git backend.
- [x] IDE-025: стабильный cwd выбранного worktree при фокусе старых файлов.
- [x] IDE-026: закрытие Diffview во время загрузки, повтор, другой view и
  возврат файла/раскладки; real Git gate и естественное раннее закрытие (§89).
- [x] IDE-GIT-11/IDE-044: merge/rebase resolve/continue и abort, Alt+e в
  writable result diff3 из дерева и версии; 4 real editor E2E Windows/Ubuntu (§103).
- [x] Interactive sequence editor: reorder/fixup/submit, edited todo cancel и
  настоящий conflict/native abort, Windows/Ubuntu по18 PASS с CLI guards (§212).
- [ ] Credentials и остальные ошибки Git; native authentication flow и
  Windows old rebase-start timeout IDE-124 отдельно.
- [x] IDE-GIT-12/IDE-043: полный OSC title/hyperlink удаляется до CSI,
  видимый UTF-8/обычные пути сохранены; 3 UI + matrix 10, подготовка 9 (§104).
- [x] IDE-028: быстрые visit между worktree с разными HEAD во время обновления
  status; согласованный Unicode-граф и 3 real editor e2e Windows/Ubuntu (§91).
- [x] IDE-034: удаление активного linked worktree после смены cwd; временный
  проверяемый backport Neogit с явной подготовкой, 2 editor + 5 подготовки E2E
  Windows/Ubuntu (§96). Mac остаётся отдельной проверкой.
- [x] IDE-035: удаление между initial Git reads, сохранение текста и дальнейший
  stage/unstage в нужном repo; 2 UI + 7 подготовки E2E Windows/Ubuntu (§99).
- [ ] IDE-038: единичный Windows Permission denied при повторном удалении
  после dirty cancel/commit/visit; установить удерживающий cwd/handle.
- [x] IDE-GIT-9: явный process cwd common git-dir, включая уже текущий linked;
  CLI + 3 UI с разными HEAD, явная подготовка двух файлов. Windows/Ubuntu
  4 live + 2 completed + 8 подготовки PASS. Первоначальный владелец handle
  IDE-038 не доказан (§100).

Готово, когда обычная рабочая задача проходит от создания worktree до push
без мыши и без необходимости искать необъявленные команды в конфиге.

## Этап 6. Упрощение и переносимость

- [ ] IDE-080 — обязательный review до рефакторинга: карта всех фич/плагинов,
  собственного glue/SDK/backports, полезность, пересечения, source/E2E evidence,
  platform gaps и цена. Сначала конкретный список оставить/убрать/заменить,
  затем небольшие изменения. Первичный срез — [FEATURE_REVIEW.md](FEATURE_REVIEW.md).
- [ ] При расширении language workflow использовать готовые LSP/backend;
  не делать собственный binder/index/server или существенный private fork.
  Ограничения готовых tools явно сохранять в матрице.

- [ ] IDE-010: выполнять переносимость на протяжении всех этапов;
  выделять системные границы по `PORTABLE_ARCHITECTURE.md` с e2e на активных ОС.
- [ ] По исправленным сценариям разделить ответственность `ide`, Edgy,
  DAP-оркестрации и `panel_guard`; убрать доказанное дублирование состояния.
- [ ] Удалять плагины/обёртки только с сохранением проверенных сценариев,
  без большой переписи ради уменьшения числа файлов.
- [ ] Проверить чистую установку, повторный setup и полные рабочие сценарии
  на Windows/macOS/Ubuntu; Mint временно отложен, SSH и обычный терминал без WezTerm —
  дополнительные сценарии. Зафиксировать версии пакетов и возможности GUI.
- [ ] Базовые команды остаются доступны без специальных WezTerm-сочетаний;
  определить clipboard/шрифты/клавиши в удалённой сессии и fallback.
- [ ] Обновить единую точку входа в документацию; старые планы пометить
  историческими, когда их актуальные решения сверены.

## Сквозной этап. E2E и VM (IDE-011)

- [x] Добавить команды quick/e2e/full для Windows и POSIX-гостей,
  suite `e2e` в общий runner и настоящий CLI e2e диагностики.
- [x] Собрать и выполнить Ubuntu Docker на Windows: непривилегированный
  процесс, readonly чекаут, runtime без сети, отчёты в `.tests/ubuntu/`.
- [x] Записать правила фича/баг → сценарий → регресс и честную матрицу долга.
- [ ] Изучить `cs2d` после получения пути; сверить его подход с нашим каркасом.
- [ ] Добавить metadata и проверку полноты каталога: отсутствие e2e у
  затронутой фичи/бага не позволяет объявить change завершённым.
- [x] Подготовить backend настоящего Neovim с RPC UI и базовыми сценариями.
- [x] IDE-030: Windows temp на диске checkout, очистка частных runtime,
  повторное использование Go cache и 4 постоянных lifecycle E2E (§90).
- [ ] Добавить PTY/ConPTY и GUI WezTerm; общие сценарии при разных адаптерах.
- [ ] Основное расширение покрытия вести по редактору: LSP/completion/format,
  DAP/output/panic, neotest, Git/worktree и задачи. Каждый соответствующий этап
  закрывается вместе со своими e2e; не откладывать их до конца разработки.
- [ ] Заполнить e2e исходных проблем и базовых возможностей по матрице.
- [ ] Воспроизводимая подготовка/снимки VM, наборы версий и сбор артефактов.
  Владелец запускает VM и команды в госте; гипервизор пока не закреплён.
- [ ] Пройти активную матрицу Windows/Ubuntu/macOS; Mint временно отложен.
  SKIP/MANUAL/не реализовано — отдельный долг,
  не подтверждение работоспособности.

## Что уже можно использовать

По текущему коду `nvim_forge`, **normal mode**, leader = Space:

| Клавиши | Действие |
|---|---|
| `Space D v` | Открыть при необходимости sidebar и сфокусировать Locals/Scopes |
| `Space D c` | Фокус в уже открытый DAP REPL/Console/Terminal; иначе нижний слот |
| `Space D 0` | Вернуться в код |
| `Space p o` | Раскладка Outline слева (может сменить прочие панели) |
| `Space l o` | Переключить Aerial слева |
| `Space w a` | Открыть/сфокусировать Outline через общий менеджер |
| `Space w e` | Открыть/сфокусировать Files через общий менеджер |
| `Ctrl+w`, затем `h/j/k/l` | Перейти в соседнее окно Neovim |
| `F6` / `F7` | Следующее окно / фокус в редактор |

Из terminal mode сначала `Ctrl+\`, затем `Ctrl+n`; после этого работают
normal-привязки. Повтор безопасен (IDE-023); одиночный Ctrl-\ внутри terminal
buffer остаётся native prefix, для toggle здесь Ctrl-t/Space tt.
IDE-005/008 проверены на Windows/Ubuntu; Mac может загружать
другую версию и ждёт проверки. Общая локальная модель остальных панелей открыта.

## Текущая точка продолжения

Актуальная очередь — в начале документа. Абзацы ниже — исторический контекст,
а не новая команда снова начинать IDE-080 или уже выполненные проверки.

2026-11-10: после §142 владелец уточнил подход; собственный SQL prototype
отменён (§143). Тогда следующим пунктом был IDE-080 feature/cost review;
первичный обзор уже выполнен. Следующие абзацы сохраняют контекст прежних этапов;
их исторические результаты не заменяют текущую platform matrix.

IDE-037: владелец выбрал чистый Docker вместо восстановления прежнего диска.
Новый engine проверен container/volume write/read, данные на F:, AutoStart
выключен. Lifecycle Desktop/WSL без отдельного поручения не менять. Старый
диск сохранён; незавершённая копия не используется (удаление отклонено средой).
Инструкция — `docs/DOCKER_WINDOWS_SETUP.md`. По подтверждению владельца engine
запущен 2026-11-02. Результаты IDE-035 и исходные красные Windows прогоны
сохранены в §99. ConPTY RU Ctrl+/ (IDE-039) остаётся открытым: последний
отдельный прогон 65 PASS/1 FAIL, эталон не менялся. Полный Windows PASS
с ConPTY не заявлен; Mac/GUI не проверены.

IDE-039 (§101): постоянная `tests/diagnostics/conpty-layout.py` сохраняет
actual/expected/diff, metadata каждой сессии и исходный вердикт. Наблюдаемый
RU FAIL поймал RU → EN между сессиями и ровно четыре прежних отличия Ctrl+/;
контрольный EN прошёл 66 проверок (один sample без foreground). Эталон не менялся. Изоляция
раскладки input thread и устойчивое RU покрытие остаются открытыми; старые
прогоны без metadata не приписываются этой причине задним числом. Следующий
функциональный Git шаг IDE-GIT-11 завершён в §103; IDE-039 остаётся диагностикой.

IDE-GIT-10 (§102): rejected/missing remote и повтор проверены в настоящем
Neogit на Windows/Ubuntu. Runtime менять не потребовалось; два новых E2E
постоянно входят в registry, прежние шесть тоже прошли на обеих ОС.
Согласование историй перед retry делается Git CLI в fixture: это не покрытие
UI merge в том change. IDE-GIT-11 (§103) отдельно покрывает merge/rebase
resolve/continue/abort и исправляет Alt+e в diff3; по 4 PASS Windows/Ubuntu.
Credentials/sequence editor остаются открытыми; Mac/GUI не проверены.
IDE-043 закрыт в §104: util companion, явный Lazy build, baseline RED,
native/hook UI и parser matrix; worktree primary и lock сохранены.
IDE-045/046 (§105–106) исправляют организацию E2E: отдельные SDK сценарии с
прежними deadline, UI Head перед поиском после checkout. Исходные FAIL сохранены.
Windows unit/e2e/trace: 40 PASS/0 FAIL/0 SKIP, 486 checks; после последней
правки ожидания все 6 Git workflow повторно PASS. Ubuntu full: сначала
42 PASS/1 FAIL/3 SKIP (IDE-046), затем 41 PASS/2 FAIL/3 SKIP, 650 checks.
В последнем все новые OSC/SDK/workflow проверки прошли; два прежних Gitsigns
сценария дали RPC/teardown сбой IDE-047. Это не чистый Ubuntu full PASS.
Cleanup собственных child и сохранение первой ошибки выполнены в §107,
IDE-041 — в §108. Без новых изменений полный набор не зацикливаем.

IDE-047 (§107): cleanup/сохранение первой ошибки выполнены, Windows 11 PASS/
2 POSIX SKIP и Ubuntu 13 PASS. Следующий full — 43 PASS/1 FAIL/3 SKIP,
653 checks; единственный FAIL — отдельное ожидание read IDE-048, child
завершился штатно, первичная ошибка не потеряна. Причина прежних двух RPC
не установлена; новые полные повторы без изменений не планируются. Metadata/
история IDE-047 сохранены коммитом fa33150.

IDE-041 (§108): реальный UI RED E339, общий word budget 4096 UTF-8 bytes
и одинаковая защита в обычном/large-file режимах. По 3 новых + 10 smoke PASS
Windows/Ubuntu; Windows unit/trace 15 файлов PASS, 364 checks. Следующий
пользовательский этап Space w завершён для tests/поиска/задач в §109.

IDE-009/049 (§109): Tests/Test Output/Search/Tasks получили общий маршрут,
контекстные действия и сохранение состояния; исправлены удаление поискового
buffer и чтение старого cursor при Enter из zoom. По 6 новых и 19 прежних UI
PASS Windows/Ubuntu, Windows unit/trace 364 checks. Следующий этап — фактическая
матрица шести языков и недостающие рабочие сценарии; без полной переработки
архитектуры до проверки функций. Terminal/Trouble Windows/Ubuntu проверены (§172);
Mac/GUI и IDE-047/048 остаются открытыми.

IDE-050 (§110): common trim ошибочно считался языковым formatter и блокировал
LSP fallback. Порядок задаёт общий filetype resolver, callers его наследуют;
cleanup без tools сохранён. Windows 6 новых UI, Go tests 5, smoke 10 и 364
unit/trace PASS. Ubuntu engine 2026-11-03 недоступен, Docker lifecycle не менялся;
проверка и сборка image остаются открытыми. Далее — JS/Node и остальная матрица.

IDE-038 (§100): process cwd явно common git-dir. Итоговый Windows
unit/e2e/trace — 38 PASS/0 FAIL/0 SKIP (471 проверка); Ubuntu full —
41 PASS/0 FAIL/3 SKIP (42 файла/44 прогона, 640 проверок). Live 4, completed 2
и подготовка 8 PASS на обеих ОС. Первый вариант с наследуемым cwd и его
широкие результаты сохранены как промежуточные: current linked дал RED
до коммита и потребовал изменения решения. Владелец handle первого отказа
551474721600 не установлен; этот остаток IDE-038 не закрыт задним числом.
Первый Ubuntu full при параллельном Windows имел один 60s timeout key-ownership
(IDE-042); raw FAIL сохранён, одиночный повтор 46 PASS и новый полный serial
не устанавливают причину timeout. Тяжёлые наборы на этом хосте выполнять
поочерёдно. IDE-039 (ConPTY Ctrl+/) остаётся диагностикой; обычные Git
ошибки push, merge/rebase и читаемый output покрыты IDE-GIT-10/11/12.
Исходный владелец handle IDE-038 и IDE-031/036/040/047/048 остаются
открытыми; Mac/GUI не запускались. IDE-041 завершён в §108.

IDE-036: эпизод сильных тормозов ввода/окон закончился только после рестарта
ПК, по сообщению владельца. GPU hangs Code и AMD Code 43 зафиксированы,
но причинная связь не доказана; перезапуск GPU child не помог. Пункт открыт,
данные — `docs/WINDOWS_UI_LAG_DIAGNOSTICS.md`. Владелец поручил продолжить план
после перезагрузки. Ubuntu full IDE-034 прошёл; Windows full сохранён прерванным.
Исторические результаты завершения IDE-034 — §96; после них IDE-035
завершён в §99, а установленный класс object read — §100.

Базовое ядро этапа 0.5 проверено на Windows/Ubuntu, запуск на Mac открыт.
Go/Delve часть IDE-003/004 исправлена и проверена реальными E2E (§64–66);
Mac/Python/Rust и исходный конфиг владельца остаются открытыми.
Go-часть IDE-006 проверена на Windows/Ubuntu (§68–70): обычный nearest/file,
debug/eval и закрытие DAP float. Исходный Mac и Python/Rust открыты.
IDE-007 реализована и проверена 11 E2E на Windows/Ubuntu (§71); Mac открыт.
IDE-012 исправлена: codelldb ищется при запуске, 3 E2E Windows/Ubuntu (§72).
Пилот Run & Debug (IDE-005/009) реализован: Space w, 4 real DAP/editor E2E
Windows/Ubuntu (§74); по пути исправлен Satellite/нулевая высота (§75).
IDE-008: единый Outline слева, общий маршрут и 6 real Aerial E2E Windows/Ubuntu
(§76–77). Дерево: общий маршрут и 7 файловых/panel E2E (§78–81).
Буферы/вкладки: 8 real editor E2E и общая модель (§83–84).
Git/worktree: общий маршрут, hunks, diff/история, branch/commit/push и сквозной
worktree → файл → commit/push покрыты 6 real editor E2E (§85–87).
IDE-026: безопасное закрытие загружающегося Diffview и 7 E2E (§89).
IDE-030: старые тестовые профили и Go cache перенесены с C: на F:;
очистка runtime и единый Windows cache исправлены, 4 lifecycle E2E (§90).
IDE-028: согласованная история/граф при быстром visit, 3 real Git/editor
e2e Windows/Ubuntu (§91). IDE-GIT-10 покрывает два отказа push (§102),
IDE-GIT-11 — merge/rebase-конфликты (§103). Credentials/sequence editor
и известные ошибки остаются в очереди этапа 5, далее упрощение/переносимость.
IDE-027: причина установлена — native ConPTY lifecycle в Neovim Windows,
подтверждены symbol/чистый repro и A/B одного source/компилятора (§92).
Владелец выбрал временный Windows SDK с явной подготовкой, lock/patch/hash
и общим resolver launcher/test entrypoint; Linux/macOS — официальный SDK.
Core probe (50 циклов) и исходные 8 buffer E2E прошли на patched SDK;
прямой системный nvim всё ещё воспроизводит ошибку. Удаление патча после
подтверждённого upstream fix — отдельный шаг, не бессрочная ветка ядра.
IDE-031: единичный 10s timeout PowerShell CLI unknown-mode в полном IDE-028;
10 повторов/30 CLI процессов прошли с прежним deadline; добавлены PID,
время, stdout/stderr и fixture artifacts, E2E ошибки/timeout (§93).
Причина исходного timeout неизвестна, пункт открыт. IDE-032: общий lifecycle
удалённых файлов исправлен через native FileChangedShell, без E211 и потери
текста; pending autosave удерживается, явный write/Save As возвращает его.
Пять новых real editor E2E прошли на Windows/Ubuntu; старый config-source
в том же сценарии даёт E211 (§95). При обнаружении исчезнувшего каталога
освобождаются GitSigns watchers скрытых файлов. Другие native конфликты сохранены.
IDE-034: ожидание смены cwd до Git remove исправляет удаление активного
worktree; явный backport закреплённого Neogit, 2 editor + 5 подготовки E2E
Windows/Ubuntu (§96). Существующей установке нужен `:Lazy build neogit`
и перезапуск; обычный startup исходники не меняет.
IDE-035/038 покрывают initial attach и живой object read (§99–100),
IDE-GIT-10 — отказы push (§102), IDE-GIT-11 — конфликты (§103);
IDE-031 и исходный владелец случайного handle IDE-038 остаются в диагностике.
IDE-033: старый ConPTY набор менял source lock через user plugins;
выделен private профиль и выбранный SDK, добавлена проверка изоляции (§94).
Владелец поручил агенту коммитить проверенные шаги и продолжать этот план
самостоятельно; новое «давай дальше» между шагами не требуется.
Mac/GUI и остальные панели не объявлены проверенными.
IDE-013 Starship остаётся в диагностике; настройки prompt не менялись.
Данные Mac не блокируют эту работу; исходную IDE-001 не объявляем
исправленной изменениями Neovim.

На Windows изучены исходники; доступа к Mac в этой сессии нет. Владелец
подтвердил: задержка и сообщение возникают до nvim, используется zsh.
Сообщение Go доказывает неудачную автозагрузку toolchain, но не показывает
инициатора. Для исходной жалобы сначала исследуем zsh, не DAP/Mason.
Сборщик `nvim_forge/scripts/diagnose-shell.py` подготовлен в change
`diagnose-macos-shell-startup`. Следующее действие: запустить его на Mac
из проблемного каталога, подтвердить инициатор через trace, записать версии
и замеры в IDE-001; затем оформить точечное исправление. Кандидат Starship
проверен по его исходникам, но на данном Mac пока не подтверждён.
