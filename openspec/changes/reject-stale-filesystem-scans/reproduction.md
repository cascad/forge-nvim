# IDE-104: подтверждённый порядок completion

2026-11-11, source b94fc54, pin Neo-tree84c75e7a7e443586f60508d12fc50f90d9aee14e.
Это отчёт о механизме, не verification исправления. Runtime/SDK/pins без diff.

Предварительный статус §180:7 current E2E PASS Windows/Ubuntu, после сохранённых
source RED и отклонённого prototype ниже.41 native строка net/2 файла через
existing applier,42 editor+15 CLI checks на ОС. [Verification](verification.md)
отделяет проверенную область от Mac/physical GUI. Описания source/отклонения
ниже — исторические наблюдения, не текущее отсутствие runtime fix.
Финальный §181 добавляет IDE-105: query/explicit restore исключены из normal
coherence retry,2 filter/clear source RED на ОС → PASS. Всего9 feature cases,
44 editor+15 CLI checks Windows/Ubuntu; actual evidence — в verification.

## Последовательность

1. Настоящий private Forge: root виден, каталог создано space закрыт,
   parent loaded=false, child отсутствует.
2. Запись owned watcher-marker.txt вызывает штатный FS_EVENT. Hook только
   в child libuv удерживает последний настоящий root fs_readdir callback
   с entries=nil после фактического чтения всех root entries. Producer stack
   — native fs_scan.lua; каталог входит в прочитанные entries.
3. Native a вводит полный Unicode child path. Штатный новый full-root scan
   показывает файл: parent expanded=true/loaded=true/children=[child],
   actual child node и строка видимы. Диск содержит новый файл.
4. Возвращаются original libuv функции и выпускается исходный callback
   без изменения entries/errors. После его shallow completion pipeline
   готовое дерево имеет parent expanded=true/loaded=false/children=[],
   child node/строка исчезли. Диск по-прежнему содержит файл.

Native render_context применяет старый root context без проверки актуальности;
renderer сохраняет уже раскрытый parent, но заменяет его старым unloaded node.
Это механизм, дающий тот же симптом, что два исторических Ubuntu6/1 (§177).
Тогда scan timelines не было: утверждать единственную причину обоих отказов нельзя.

## Evidence

Latest exact driver/helper: Windows29999153942600, Ubuntu25679837753070;
file-create-order.json содержит before/newer/after/held/released/renders и
disk_child=true/stale=true. Native exit/signal0/APIerrors[], own scopes empty.
Queue barrier4 turns следует именно final shallow callback→on_exit→job_complete
→render→AFTER_RENDER; это не произвольная задержка. Native a/переходы настоящие,
fake scan/renderer/events нет. Hook восстанавливается при release/cleanup.

Ещё три controlled observations с захваченными тогдашними source copies тоже
дали stale=true; ранний Ubuntu trial удерживал первый batch, затем уточнён
последний callback для известной completion chain. Четыре bounded untraced
single-case запуска Ubuntu дали1PASS каждый. Latest Files7/7 Windows/Ubuntu
не закрывает IDE-104. Audit11 native profiles,63 runtime/pin/patch sources
совпадают с b94fc54; exact driver/final test sources, SDK SHA прежний.
Trace11(+manual-link SKIP) на ОС, strict92. Mac/physical GUI/full suite не запускались.

Постоянные воспроизводящие исходники: tests/diagnostics/file-create-order.lua
и file-scan-delay.lua. Exit0 diagnostic означает корректно снятое наблюдение,
а stale=true — воспроизведение бага. Positive regression fix ещё не реализован;
tasks1.2/2.1–2.3 открыты. Raw11 profiles/first failures/audit в ignored .tests.

## Источники и следующий шаг

Обновление §179: постоянный file-scan-order.test.lua зарегистрирован,5 native
cases; исходный source Windows/Ubuntu —3PASS/2RED (stale root и stale partial
после смены root). Обычный A/a/open/write и independent folders — controls;
вариант с initial :edit/pending reveal сохранён отдельным пятым case.
Проверки source native scanner bytes копируются из actual runtime.

Current upstream v3.x1a14083046d96e88e361d1da00761c40d45012f3 (main
760d9701953ad2b0277fe9776ba99bb011ecac2b имеет тот же scanner SHA
b0bf0f368fe95d7485f1830a8a653a74db606facee83916f357e658717e682c1)
не исправил оба controlled failures. В отдельном Windows archive probe
получено2PASS/3FAIL, включая один ordinary child visibility timeout.

Прототип19-line generation-only guard: controlled root/partial стали PASS,
но ordinary/independent/pending controls FAIL, всего2PASS/3FAIL. Он полностью
снят штатным --revert; runtime/catalog/предыдущие backports возвращены к source.
Неактивный patch fixture сохраняет проверенный вариант для review, не является
готовым исправлением. Правки на диске новых плагинов и изменения lock отсутствуют.
Постоянный E2E сейчас намеренно показывает известные RED; xfail/skip нет.

Pinned [fs_scan.lua](https://github.com/nvim-neo-tree/neo-tree.nvim/blob/84c75e7a7e443586f60508d12fc50f90d9aee14e/lua/neo-tree/sources/filesystem/lib/fs_scan.lua)
и [renderer.lua](https://github.com/nvim-neo-tree/neo-tree.nvim/blob/84c75e7a7e443586f60508d12fc50f90d9aee14e/lua/neo-tree/ui/renderer.lua)
сопоставлены с реально подготовленным source. Поиск официального upstream и
сравнение main пока не дали доказанного correction; отсутствие такого результата
не означает отсутствия всех возможных fixes. Общие slow/refresh issues не
объявляются этим багом по похожему названию.

Дальше — permanent source RED, затем минимальный guard через готовый upstream
или existing locked backport. Нужны controls independent partial folders/
new root/следующее обновление: global latest-call-wins для всех folders не
подходит. Production async/follow/watchers и обычный locator не ослабляются.
