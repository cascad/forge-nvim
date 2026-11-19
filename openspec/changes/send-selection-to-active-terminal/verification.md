# Verification — IDE-146 / IDE-PANEL-30

2026-11-19, исходная версия d073799; Windows и Ubuntu 24.04, Neovim 0.12.2.

## Реализация

Обычный системный shell внутри IDE, с прежним окружением и инструментами.
Visual Space t e и Visual/Select Ctrl+Enter отправляют выделение в текущую
обычную консоль. Скрытая раскрывается; при отсутствии создаётся native Terminal.
Автоматического выбора интерпретатора по языку файла нет. Python ниже — только
измеритель реального PTY stdin в тестах, не новая консоль продукта.

Neovim getregion → native Terminal open/send. Одна локальная ссылка на native
Terminal фиксирует последний фокус; нового manager/registry/SDK/plugin нет.
Native get_last_focused — snapshot представления, не полная история фокуса;
TermClose убирает instance из списка, хотя output buffer может оставаться.
Native send(array) сохраняет platform line endings; exec(string с LF) терял
Windows границы строк. Завершённый job раскрывается с предупреждением.

## Поведенческая проверка

Зарегистрирован tests/e2e/terminal-selection.test.lua, требование IDE-PANEL-30.
Старый config извлечён из d073799 в отдельный .tests/terminal-selection/legacy-config.
Source RED: batch1795109973656610800, все7 FAIL; первое выполнение оставляет
Neovim в hit-enter/confirm вместо integrated Terminal. Указанный для попытки
фильтр не сработал: test-batch.py намеренно очищает FORGE_*_CASE; это7, не1 запуск.

Один affected packet каждой ОС: terminal-selection + terminal-shell.
Windows1795110202693204400: selection3 PASS/4 FAIL, shell2 PASS/2 POSIX SKIP.
Ubuntu1795110171990687749: selection5 PASS/2 FAIL, shell2 PASS/2 Windows SKIP.
Исправлены выбор native instance, Windows переносы и обращение теста к
завершённому instance, уже удалённому backend из registry.

После этих изменений повторён только новый файл:
Windows1795110751921632800 и Ubuntu1795110763571262975 — selection6 PASS/1 FAIL.
Последний failure — тестовый setup: open() уже видимой консоли не фокусирует её.
Добавлен явный native focus(), production code не менялся. Дополнен assertion
на whitespace/пустую строку. Прямой native запуск только двух затронутых кейсов
обошёл очистку фильтров batch runner:

| Сценарий | Windows | Ubuntu |
|---|---|---|
| Первое выполнение: обычный shell, видимый output, повтор | PASS | PASS |
| Скрытая/видимая сессия, тот же PID/job/buffer/cwd/программа | PASS | PASS |
| Char/line/block/reversed/exclusive/Select, Unicode, пробелы, aliases | PASS, affected repeat | PASS, affected repeat |
| Последняя сфокусированная из нескольких консолей | PASS, failed repeat | PASS, failed repeat |
| Private hidden task не получает текст | PASS | PASS |
| Float reveal и штатный фокус | PASS | PASS |
| Завершённая сессия: старый output, warning, без нового job | PASS | PASS |

Итого по7 PASS на ОС, собраны из основного affected запуска и точечных повторов.
Это не новый цельный зелёный batch; исходные failures сохранены.
terminal-shell повторно не запускался после его PASS: platform shell policy не менялась.
Файлы/registers/modified flag, тот же cwd/PID/job и отсутствие auto-install
проверяются настоящим editor RPC/keyboard/PTY, без mocks Terminal API.

## Артефакты и границы

Host F: .tests/terminal-selection/windows-{source-red,final,affected}.txt,
windows-case-{last,char}.txt; .tests/ubuntu/terminal-selection-ubuntu-{last,char}.txt.
Batch JSON/00.log: .tests/batches/<Windows id> и .tests/ubuntu/batches/<Ubuntu id>.
Editor snapshots/reader JSON сохранены в соответствующих editor-e2e directories.
Все эти локальные артефакты игнорируются git.

Ubuntu: собственный container7871857f6f05, owner=selection-e2e, image
forge-nvim-tests:ubuntu24.04-nvim0.12.2; network none, CPU2, RAM3GiB.
Source read-only, записи на host F через .tests mount. Плагины67 pins и native
backports подготовлены в собственной /tmp копии image cache, без загрузок.
Docker Desktop/WSL, image, чужие containers и пользовательские SDK не менялись.

Физическая доставка клавиш в WezTerm, macOS и Omarchy здесь не проверялись.
RPC aliases PASS не заменяют эти проверки. Unrelated Go/Rust/DAP/full E2E
не запускались. Metadata/syntax/frozen/prefix и cleanup описаны в commands205.

Финальный metadata gate: Lua syntax/strict/trace9 PASS; change catalog
1 REGISTERED/0 MISSING/0 PENDING.3 frozen .tools hashes,67 pins, прежние
locks/SDK/backport metadata и append-only journal prefixes PASS.
Own container остановлен и AutoRemove завершён; records сохранены на F,
cleanup.json подтверждает отсутствие. Immediate check до окончания AutoRemove
не прошёл, повторное чтение docker ps/inspect подтвердило удаление.
