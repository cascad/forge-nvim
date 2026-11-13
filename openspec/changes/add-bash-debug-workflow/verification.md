# Проверка 2026-11-13

## Конечные результаты

Windows17 distinct PASS = native workflow1 + missing adapter/Node2 +
прежние Bash8/DAP panels6. Ubuntu тот же17. Это выбранные отдельные прогоны
изменённых частей, не полный regression/единый прогон всех17. Runtime changes
после controls14 касались только Bash output defaults, которые controls не
вызывают; active branch отдельно проверен конечными native/negative cases.

Windows final native9411332712100, missing9669743566800/9674206015400.
Ubuntu final native6163498681282, missing6318044467070/6321200519815.
По12 native editor profiles в selected audit: exit0/signal0/APIerrors[],
hard_kill=false/scope ok/active_after0. Проверены F9/F5, entry→breakpoint,
PWD/stack, evaluate42, stdout/default PTY, edit→43/repeat, launch.json
args/env/cwd, explicit debugConsole и keyboard Stop. Все4 записанных пары
Linux PID/parent после stop отсутствуют (ps code1/empty), включая Windows WSL.

Audit .tests/bash-debug-final-audit.json, .tests/audit-bash-debug.py.
Current active module/dap.lua copies/67 pins/6 backports16 files сверены,
Win SDK SHA74AFF15B3B6BC288753B721365B088AB44C9B2BFFF152F8D27F5885B4B1C6AD9
прежний. Adapter VSIX0.3.9 SHA7fc154642bf3fcfa27a903fd44235bc902d93e737939c7b411ece6fe10f5f458,
269 files: explicit offline prepare и repeat/hash после настоящих запусков PASS.

## Сохранённые промежуточные результаты

- First Windows8021920639600: native4s adapter warning, без DAP trace нельзя
  установить точную фазу/длительность; cleanup exit1/signal15 сохранён. Missing
  adapter8076309492600 PASS. Public WSL budget30 принят, cold distro gate открыт.
- Observe8256677084400: defaults42/43/Output прошли, launch.json picker FAIL:
  Enter до готового selected entry, native Nothing currently selected. Исправлено
  ожидание публичного выбранного item, без задержек/private writes.
- Windows8496660536200 и8945926587300 defaults/explicit/stop PASS; второй с
  explicit pinned Node SDK. Первый Ubuntu5478885506729 и companion:0/2 из-за
  Node вне PATH. Runtime правильно выдал missing Node; fixture теперь передаёт
  existing Node SDK executable, permanent negative проверяет этот случай.
- Ubuntu5716518719042/5728986919283:2 PASS, но audit обнаружил native
  /dev/stdin ENXIO в debugConsole. Bundle dbg-main.sh/source.sh повторно
  открывает stdin Node child pipe. Default переведён на готовый integrated
  PTY; final native case проверяет отсутствие этой ошибки. Opt-in console
  warning сохранён IDE-127, stdout/stderr не фильтруются.

## Границы

Нет собственного debug backend/WSL bridge/protocol mapper, изменений plugin
pins/backports/SDK, установки Node/WSL или смены default distro. Уже Running2
Ubuntu использован через официальный launcher. Docker imagef63a05ca с network
none использован без lifecycle/build/download; private Neogit overlay и
pinned Bash adapter подготовлены на host F: mount, image payload не менялся.

Locals upstream содержит главным образом PWD/last status, остальные значения
через Watch/Evaluate. Полное перечисление переменных не эмулируется. Mac/Bash3.2,
physical/interactive stdin/UNC/custom mounts/cold Windows boot отдельно.
Mac требует Bash4+, системный3.2 недостаточен. Frozen drafts не менялись.

Отдельный CLI probe .tests/bash-sdk-owner-probe.txt подтвердил механизм:
Node child stdin=socket, повторный open /dev/stdin возвращает ENXIO.
Prepare/check/chmod как user forge на обычном /tmp FS прошли. Dockerfile
получил поздний user-owned SDK layer и FORGE_E2E_BASH_DAP_DEPS; полный новый
image build не запускался/не объявлен проверенным. Env selector host default
не меняет; в уже готовом image использовался прежний private mount.
