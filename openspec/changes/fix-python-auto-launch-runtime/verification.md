# Проверка IDE-147 / IDE-PY-3

Source: 17e81ff. Работа начата 2026-11-20, по явному стопу немедленно
прервана после code/test changes; проверки исправления продолжены 2026-11-21.

## Реальный инцидент

Persistent fride Logs первоначального сеанса показывают выбор PATH → MSYS2
python3, затем launcher connection timeout. В следующем проекте lab выбран
его venv; владелец подтвердил успешный запуск простых Python/Go/Rust файлов.
Прямой native probe MSYS2 завершился exit1/missing encodings, обычный CPython
завершился0. Повреждённая установка MSYS2 не ремонтировалась, host PATH/SDK
не менялись. Отобранные исходные записи и probe stdout/stderr сохранены в
`.tests/python-auto-runtime/incident-sdk-probes.json` и двух session jsonl.

## Сценарии и результаты

| Сценарий | Windows | Ubuntu |
|---|---|---|
| Plain Python без project venv/SDK overrides, конкурирующие имена PATH, реальный F5/breakpoint/stdout/continue | PASS | PASS |
| Explicit непригодный SDK: native failure в Logs, нет adapter/session/modal, выбор не подменён, edit/save и recovery с тем же F5 | PASS | PASS |
| Смена cwd во время native probe → штатный DAP ABORT, adapter не стартует | PASS | PASS |
| Прежний Python default/project launch.json с project venv и реальным output | PASS | PASS |
| Managed debugpy launcher, Python fallback, global adapter/Python overrides | 4 PASS | 4 PASS |

Итого по8 unique native cases на ОС, aggregate с failed/affected repeats.
Не полный regression и не macOS/физическая GUI-приёмка. Первый Auto Windows
source RED сохранён: resolver выбрал непригодный python3 вместо python.
Ubuntu POSIX-порядок сохранён: python3 предпочитается python.

Новый тест использует настоящий CPython SDK (private venv **вне** проекта,
поставленный в PATH) и настоящий debugpy. Node binary под другим именем —
только контролируемый executable, не умеющий выполнить Python command;
это не mock Python/DAP и не попытка изображать настоящую MSYS2 ошибку.
Stale case удерживает callback настоящего native probe без замены результата.

Первый target прошёл Auto, но обнаружил native Press ENTER на паре
vim.notify(ERROR) + DAP Run aborted. Исправлен product: короткий ERROR теперь
показывает существующий Fidget, полная причина остаётся в IDE Logs.
Stale observer сперва сравнивал Windows пути побайтно и пропускал native
python.EXE; исправлено только сравнение по native case/разделителям.
Следующий invalid Windows observer искал исходный path в Logs без нормализации
разделителей; UI уже был доступен. Исправлен observer, добавлены Fidget history,
no-silent-replacement и save/recovery assertions. Native timeouts прежние.

Логи: `.tests/python-auto-runtime/`:

- `windows-source.log`, `windows-target.log`, `windows-invalid-retry.log`,
  `windows-invalid-final.log`, `windows-stale-retry.log`;
- `ubuntu-target.log`, `ubuntu-invalid-final.log`;
- `windows-project-control.log` / `ubuntu-project-control.log`;
- `windows-managed-controls.log` / `ubuntu-managed-controls.log`.

Каждый лог ссылается на private editor artifacts: config/test source,
native DAP log, state/screen и shutdown code/signal/scope. Первый неудачный
Windows target завершён harness по RPC timeout; это сохранённый FAIL, не PASS.

## Границы и доставка

Syntax5 Lua files PASS; strict OpenSpec PASS; project trace9 PASS. Финальный
guard сверил66 pins,6 backports,4 frozen .tools files, прочие SDK/installer UI/
main specs/WezTerm и append-only prefixes FIXLOG/commands против17e81ff.
Все16 final native editor profiles вышли code0/signal0 без hard kill, scopes
пусты. Результат `.tests/python-auto-runtime/final-gates.json`.

Изменены три product Lua файла: Python Auto order, Current File coroutine и
привязка её к generated config. Custom launch.json, pytest, Go/Rust/Node,
Mason/SDK/plugin pins/backports не менялись. Existing runtime_sdk.probe и
nvim-dap ABORT используются напрямую; фоновых probe/install на startup нет.

Три installed config файла в `F:/apps/fride` предварительно совпали с
исходным17e81ff после нормализации CRLF. Доставка выполняется после code commit:
backup, hashes/receipt и обновление только этих файлов, без остановки/hot reload
пользовательской сессии. Новый install candidate будет упакован штатным producer
с прежними проверенными Core/Terminal/frontend inputs и новым source commit.
Фактический результат доставки добавляется ниже после выполнения.

Native macOS, повторная GUI-приёмка владельцем и public release остаются
отдельными gates. Обычная подсказка подготовки optional language tools не
считается ошибкой SDK и этим изменением не подавляется.

## Фактическая доставка — 2026-11-21

Code commit: `182b16023212adabe6890fb16d4e68b8e9f97819`. Installed originals
повторно сверены перед атомарной заменой; обновлены только три Lua файла.
Backup: `F:/apps/fride/backups/python-auto-20261121-182b160`, внутри receipt.json
с before/after SHA. Те же сведения — `.tests/python-auto-runtime/installed-delivery.json`.
Открытые пользовательские sessions не останавливались и не перезагружались.

Native Auto F5 дополнительно прошёл с `FORGE_E2E_CONFIG_SOURCE=F:/apps/fride/config/forge`
в отдельном private профиле, без записи в профиль владельца. Final code0/signal0,
scope пуст; с основным пакетом17 чистых native profiles. Это проверка копии
установленной конфигурации, не физический ввод в уже открытый GUI пользователя.

Новый комплект: `.tests/acceptance-installer/windows-python-fix/install.cmd`.
Штатный packager повторно использовал прежние проверенные Core/Terminal/frontend
без загрузки или пересборки; source — чистый code commit182b160,2520 files.
`--print-plan` проверил manifest/payload и Default: языки отложены, versions preserve.
Native candidate runtime: три probes,33 parsers,117 queries и fzf C ABI PASS.
Manifest SHA256: `90bd201fe17886f3bb3bdedcdcc422621405a29551cbc73ea660f24d26641bad`.
Полные plan/runtime/source hashes и ограничения — `.tests/python-auto-runtime/final-candidate.json`.
Последующий коммит меняет документацию/отметки доставки; код кандидата182b160.

Свой контейнер `da7a1aeb5d7bae27799e95c31ed6a4b8639a12aa7a7f2ff05a9ee1bc8d591124`
удалён после проверки ID/owner/task и отсутствия оставшихся test processes;
Docker Desktop/WSL оставлены в исходном состоянии. Cleanup receipt записан.
Для пользовательской проверки требуется обычный перезапуск fride, затем F5
на простом `.py` без project venv. Без повторной установки комплекта.
