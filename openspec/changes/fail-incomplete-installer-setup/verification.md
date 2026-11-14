# Verification

2026-11-14, IDE-138/139, IDE-BOOT-9; source b1287c2.

| Среда | Source | Target |
|---|---|---|
| Native Windows PowerShell5.1/SDK74aff15b | 7 RED | 7 PASS |
| Native Ubuntu Linux backend | 7 RED | 7 PASS |
| macOS backend в Ubuntu, contract | 7 RED | 7 PASS |

Native Mac этим не проверен. Source fixtures запускают прежние installer
bytes из git archive, реальные Neovim processes возвращают0, хотя contract
нарушен. Native probe nvim +lua error(...) +qa также вернул0. Source/target
используют один окончательный stand (test SHA совпадает). Minimal fixture
commands моделируют success/exception/missing command, public backports
исполняется настоящий на16 private SDK files. Packages/network не запускаются.

Positive cases проверяют отсутствующий Default каталог, отсутствующий глубокий
Custom path/parents, installed config вместо ambient, точный restore/parsers/
tools порядок,3 PID,6 backports16 SHA. Windows окружение восстановлено,
process PATH entry сохранён. Exceptions parsers/tools/plugins, missing tools
command и неизвестный backport дают exit1, следующие stages/installed отсутствуют.

Финальные raw logs: .tests/setup-windows-{source,target}-checked.txt;
guest .tests/ubuntu/setup-{linux,macos}-{source,target}.txt. Все child argv/
exit/stdout/stderr/trace сохранены в install-setup/<id>. setup-audit.json
сверяет config/helper/test bytes, native results,6/16, frozen hashes и prefixes.
Existing installer shell scenarios: Linux26 + Mac127 PASS в Ubuntu.
Их fake nvim shim обновлён на общий plugins stage; сама native command semantics
проверена новым stand. Внутренние temporary case outputs старого shell runner
жили в container /tmp; его полные stdout/check results сохранены в .tests.

Первый Windows stand без дополнительного PATH postcondition уже дал source7
RED/target7 PASS. После добавления проверки post-environment fixture WriteAllLines
получил одно concatenated array вместо2 строк (PowerShell operator precedence):
target5 PASS/2 FAIL. Исправлены скобки только fixture; новая версия один раз
source7 RED/target7 PASS. Все предыдущие logs сохранены, distinct cases не
суммируются между версиями. Linux matrix использует уже исправленный stand.
Audit сначала ожидал files map у single-file nvim-dap; public API возвращает
для него scalar sha256. Учтена эта форма, execution E2E не повторялся.

## Границы

Макросы команды могут сообщить внутренний package failure без exception:
полная registry/binary readiness остаётся в IDE-138, не закрыта cquit wrapper.
Не проверялись новый machine setup, все67 downloads, native Mac/Bash3.2,
Default/Custom menu и supported binaries distribution. Payload/lock/SDK/frozen
infra drafts прежние; только3 installers, общий explicit Lua/POSIX glue и
их регресс. Daily startup не менялся. Windows temp F, Win/Linux serial,
готовый Docker28.5.1/image без build/pull/Desktop/WSL lifecycle.
