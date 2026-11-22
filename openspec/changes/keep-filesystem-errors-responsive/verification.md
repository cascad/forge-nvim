# IDE-148 / IDE-FILE-7: результаты

Source cf6095e, 2026-11-22. Screenshot и описание владельца: completed empty-dir
delete, E21, сохранившийся prompt и очень медленный Ctrl-C. Session jsonl
сохранён в .tests/files-input/incident-session.jsonl. Stack interruption:
ide.controls redrawstatus внутри cmp.confirm/filter sync. Точную первопричину
E21 по этому stack не объявляем установленной; тот же E21 не воспроизведён.

## Подтверждённые boundaries

- Source prompt Enter действительно вызывает cmp filter sync.
- Native длинная ошибка открывает modal message prompt.
- Neo-tree использует synchronous system/delete; real held IO не поддерживается.
- Current source empty/cancel control проходит. Initial OS denial fixture был
  некорректен: FILE_READ_ATTRIBUTES handle не запретил удаление. Это fixture FAIL,
  не доказательство source bug. Fixture исправлен на GENERIC_READ, сам проверяет
  настоящий RemoveDirectoryW отказ32 до ready; без него не считается пригодным.

Source log: windows-source.log —1 control PASS,3 meaningful RED,1 fixture FAIL.
Первые target6 profiles не прошли init: messagesopt временно оказался без
обязательных hit-enter/wait. Исправлен порядок: сначала append wait:0, затем
remove hit-enter. Windows-target.log сохранён; этот FAIL не выдан за PASS.

## Итоговый набор

| Проверки | Windows | Ubuntu |
|---|---|---|
| Новые empty/cancel, prompt Enter, native error/history, OS deny/retry, held IO/edit/save, pending modified buffer | 6 PASS | 6 PASS |
| Прежние copy/delete/dirty guards | 9 PASS | 9 PASS |
| Files create/rename/move/cut/panels | 7 PASS | 7 PASS |
| Focus/order/insert/terminal | 6 PASS | 6 PASS |
| Настоящий Go LSP completion/diagnostics | 1 PASS | 1 PASS |
| Backport CLI LF/CRLF/repeat/revert/unknown companion | 3 PASS | 3 PASS |
| Full explicit plugin setup и Files/Tests/Locals | 1 PASS | 1 PASS |

По33 unique targeted cases/ОС, aggregate с failed/affected repeats; не full suite.
Native Mac/physical GUI приёмка отдельно. Ubuntu OS denial — обычный uid и
parent permissions0555, не mock IO/adapter. Target остаётся до явного retry.

Новый case стартует с native more=true до init. Иначе общий harness more=false
мог скрыть paging gap. Product явно nomore; ошибка80 строк не требует ввода.
Другие harness callers сохраняют прежний default. После этой корректировки
повторены только6 affected новых cases на каждой ОС; прежние27 controls не
повторялись, их more=false поведение не изменилось.

Логи: .tests/files-input/windows-native-final.log, ubuntu-native-final.log,
windows/ubuntu-packet.json и шесть *-copy-delete/file-explorer/focus/
go-completion/backports/startup.log. В private editor artifacts — config/test,
OS denial proof, native history/mode/notifications, shutdown code/signal/scope.
Удерживается callback настоящего libuv результата, данные не подменяются.

## Изменение

Штатные messagesopt wait:0/history и nomore вместо message modal; явные
confirm/input сохраняются. Prompt Enter обходит sync completion, остальные
cmp mappings прежние. Panel refresh не вызывает forced synchronous redraw.
Pinned Neo-tree получает один companion: Plenary async/libuv delete, lstat
без обхода ссылок, ошибки с native cause/path и сохранение pending modified
buffer. Events/callbacks/dirty/root guards остаются. Ссылки не обходятся.
Original файла проверен по точному raw upstream commit84c75e7, SHA d750d9bf…;
after SHA de24522c… — backport-receipt.json. Pins66 и6 групп прежние, файлов17.

Recursive delete не атомарен; partial failure не считается success и не
повторяется автоматически. Остальной synchronous copy/create/guard IO этим
не объявляется устранённым. Фоновые managers/workers/SDK не добавляются.

## Доставка и границы

Strict PASS; trace9 PASS;7 Lua syntax checks и Python fixture AST PASS.
Guard:66 pins,6 групп/17 файлов, только один новый declared companion,
остальные payloads/SDK/installer UI/main specs/WezTerm прежние;4 frozen .tools
SHA и append-only journals сверены. На каждой ОС24 unique native editor
profiles вышли code0/signal0, без hard kill и с пустыми process scopes.
CLI cases входят в33, но не считаются editor profiles.

После code commit: соответствующие installed config файлы и один Neo-tree
companion обновляются с backup/receipt; никаких hot reload/остановки owner UI.
Готовится новый local Windows candidate с прежними native inputs. Actual commit,
SHA, installed source control и runtime proof дополняются после выполнения.

Новый report о Help — отдельный IDE-149. Подтверждено, что Edgy намеренно
размещает Help снизу, а sessionoptions сохраняет help. Window-boundary probe
на SDK показывает E1513 для Ex и nvim_win_set_buf при winfixbuf; возможна
нативная основа owner policy, но не объявляем эту политику уже реализованной.
