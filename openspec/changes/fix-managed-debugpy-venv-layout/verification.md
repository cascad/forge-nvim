# Проверка IDE-119 / IDE-PY-2

2026-11-12. Frozen source7673dd3, Windows SDK74AFF15B...C6AD9,
67 pins/6 patched dependencies прежние. Source/target используют один
финальный native E2E; product change только plugins/dap.lua,6 add/6 delete.

| Проверка | Результат |
|---|---|
| Windows source |4 PASS, actual launcher/Python fallback/global adapter/global Python override |
| Windows target |4 PASS, те же четыре сценария и final test bytes |
| Windows selected |15 PASS: Python8, actual debugpy failure1, Go Output4, Rust routes1, Node F5/project1 |
| Native audit |20 profiles: source4/target4/regression12; roots0/0, APIerrors[], empty scopes, runtime removed |
| Unit/trace |371 PASS/1 SKIP,18 файлов PASS |
| OpenSpec |Staged snapshot103 items strict PASS; whole working tree104 включает POSIX draft |
| Не проверено | Ubuntu native source/target/regression, Mac/physical delivery |

## Реализация и сценарии

venv_executable обобщает прежний private debugpy_adapter_in_env: только
native layout Scripts/name.exe или bin/name. Его используют прежние project
adapter lookup и оба managed fallback. Выбор roots/explicit/project/PATH/
Mason и project_python прежние; новый generic tools API не появился.

Fixture создаёт настоящую project venv только с dependency приложения и
managed venv с debugpy1.8.22 из verified offline wheel. Перед F5 project
Python действительно не может import debugpy, PATH не находит adapter,
Mason install count0, actual adapter spawn отсутствует. Подготовка в частном
runtime до старта child, без сети. LSP в этой fixture выключен public API;
отдельный Python language regression проверяет настоящие Pyright/Ruff.

F5/current-file, реальный breakpoint/eval42, stdout project prefix=True и
continue подтверждают разные роли adapter/debuggee. Module fallback
использует selected Python -m debugpy.adapter. В explicit controls global
и env paths различаются, настоящий spawn использует global path.

Source-final profiles3771183520000/3789996164500/3808685980700/3832158768100;
target-final3856438072300/3875212492300/3893819951300/3917242482400.
В каждом actual test/fixture bytes,65 config Lua/init/lock files, saved driver,
offline setup command results и native outcome проверены отдельно. Source/
target normalized code отличается только lua/plugins/dap.lua. Same-environment
FS отсутствие runtime проверено после stop. Raw evidence .tests/managed-python-*.

Final test SHA25638e699107579cdd49705d947ab19399d8f648aa87c1e889881df602ce3e0047f;
app8a60cc05224b1cf6ca3eb1e3f71a777550f5d02b110737c4f67968199fb7f778.
Отдельный export git index без POSIX draft прошёл unit/trace371 PASS/1 SKIP
и OpenSpec103 strict. После проверки в index добавлены только результаты docs;
runtime/test/spec bytes совпадают с проверенным staged snapshot.
DAP DEBUG log path сохраняется до F5, cleanup копирует log без нового RPC
после неуспешного запуска. Для venv сравнивается путь вызова, не realpath
исполняемого файла: identity Python environment отличается от binary identity.

## Неудачные варианты теста и границы

Первый Windows pilot2245446763000 остановился на exact ordinal picker:
реальная строка содержит [debugpy]/current file. Второй2316423880100 уже
запустил managed adapter и получил stdout/project prefix, но /answer попал
в calculate_answer. Обе ошибки observer исправлены по существующему Python
UI helper; root0/empty scopes, исходные logs/test bytes сохранены. Это не
source RED IDE-119. После исправления один pilot прошёл, затем4 source/
4 target. Дополнены независимое сохранение DAP log и lexical invocation
identity; final source4/target4 повторены с одинаковыми финальными bytes.
Прежние prototype logs/audits не перезаписывались без отдельной копии.

Windows native доказывает сохранение поведения и настоящую managed branch,
но не воспроизводит Unix bug. Engine pipe dockerDesktopLinuxEngine отсутствует;
native Unix source RED/target ещё не получены. До patch заморожен7673dd3,
так что source replay остаётся доступен после Windows commit. Это честное
изменение порядка работы при недоступной ОС, не снятие native gate.

CRITICAL: tasks1.2, Unix часть1.3/1.4 и2.1 не выполнены. Только1.1 и1.5
завершены,2/6 tasks. IDE-119 остаётся открытым до native Unix проверки.
Archive readiness не заявляется. Whole Windows/Ubuntu §191–193 не повторялись
и не повышены до PASS; причины085/117/118 прежние. POSIX probe draft не
включается в этот commit, observer не менялся. Desktop/WSL не управлялись.
