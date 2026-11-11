# IDE-097: захват native assertion на Windows

Состояние на 2026-11-11: исходный `!stream->closed` остаётся открытым.
Первый отказ сохранён в `.tests/editor-e2e/45802477968200/tui-final.json`;
там виден `wstream.c`, но нет стека и точного процесса, напечатавшего assert.
Зелёный повтор не доказывает исправление. Общая Lua сборка, выбранный SDK и
67 plugin pins в этом диагностическом шаге не менялись.

## Окно с ошибкой Python

Во время проверки был запущен системный `C:/Program Files/LLVM/bin/lldb.exe`.
Статический PE import показывает зависимость его `liblldb.dll` от
`python310.dll`; эта DLL не найдена в проверенных каталогах поиска загрузчика.
Это вероятный источник замеченного владельцем окна. Текст окна не сохранился,
поэтому отождествлять их со стопроцентной уверенностью нельзя.

Настоящие CLI E2E Python прошли 7/7 (§168). Системный LLDB повторно не
запускается. Диагностика использует уже подготовленный CodeLLDB из
`.tests/rust-deps/codelldb/extension/lldb`: свой Python 3.12.7 и LLDB
22.1.4-codelldb. Проверены embedded Python, DLL hashes и `wstream_write` по
PDB выбранного SDK. Системные Python/PATH/настройки не менялись.

## Команды

Из корня checkout, на Windows с подготовленным Windows SDK/PDB и CodeLLDB
(последний входит в существующую явную подготовку `tests/e2e/prepare_rust.py`):

```powershell
$env:TEMP="$PWD/.tests/tmp"
$env:TMP=$env:TEMP
$env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE="$env:TEMP/native-assert-controller.log"
New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
& ./.tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/native-assert.test.lua
& ./.tools/neovim/windows-x64/bin/nvim.exe -l tests/diagnostics/native-assert.lua
```

Первая команда — четыре Windows E2E инструмента: detach + RPC liveness,
deadline + detach/liveness, refusal другого Job (включая получателя handle),
настоящий искусственный `_wassert` в собственном дочернем Neovim. Последний
должен дать actual CRT frame, expression/file/line и diagnostic termination;
host затем отвечает RPC и штатно выходит. Это **control**, не RED IDE-097.
Набор зарегистрирован в `e2e`; без подготовленного CodeLLDB или на другой ОС
получается явный SKIP. Продукт автоматически этот observer не загружает.

Вторая команда — один ограниченный исходный workflow: edit, split, Explorer,
tabedit, Quickfix. Наблюдаются свежие frontend/backend PID из jobpid/RPC;
ввод остаётся настоящим terminal input, записывается принятое число байтов.
PID для произвольного attach снаружи не принимается. Команда печатает каталог
артефактов. Успешное завершение без capture означает только отсутствие
воспроизведения за этот запуск. Debugger меняет timing.
Весь controller ограничен 90 секундами и отдельным owned Job, включая
синхронный socket RPC; `launcher artifacts` содержит его exit/cleanup.

## Артефакты и границы

- `native-assert-trial.json`: phases, actual PID, input/accepted bytes,
  `original_reproduced`, ошибки и результаты каждого observer.
- `capture-{frontend,backend}/ready.json`: версия, SDK hash, held identity,
  membership и разрешённый `_wassert` breakpoint.
- `capture.json`: actual threads/frames, x64 CRT arguments, phase; stream
  fields читаются из PDB, когда доступны, без выполнения expressions в target.
- `done.json`: отказ, deadline, detach либо assertion-captured. При assert
  сначала сохраняется стек, затем завершается только собственный target;
  это диагностическое завершение явно помечено.
- `debugger-exit.json`, `native-host-exit.json`, `shutdown.json`: native exit,
  stdout/stderr и итог очистки собственного Job.

Runtime owner marker/token, image/hash и creation time проверяются до attach;
query handles удерживаются, чтобы исключить смену identity. Controller
дублирует debugger-потомку handle **точного** fixture Job с QUERY rights;
worker закрывает дубликат. Нельзя использовать NULL/current Job: libuv создаёт
вложенный Job, не содержащий ConPTY sibling. Модель соответствует
[QueryInformationJobObject](https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-queryinformationjobobject),
[process ID list для вложенных Jobs](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_process_id_list)
и [DuplicateHandle](https://learn.microsoft.com/en-us/windows/win32/api/handleapi/nf-handleapi-duplicatehandle).

Все временные данные Windows остаются на диске checkout (здесь F:), launcher
использует private HOME/TEMP и `--no-lldbinit`. Error mode меняется только в
private launcher на время запуска и восстанавливается; искусственный assert
child отдельно направляет CRT error в stderr. Desktop/WSL и пользовательские
процессы не управляются. Linux/macOS используют прежний официальный SDK;
эта Windows диагностика не заявляет их native coverage.

Четыре bounded original trials прошли без capture, оба observer в каждом
штатно detached; последний запуск также проверил внешний 90s launcher.
Причина IDE-097 и связь с прежними зависаниями компьютера не установлены.
Следующий шаг при воспроизведении — actual caller → минимальный native repro
→ отдельный SDK fix с source RED/регрессом, без отключения assert.
