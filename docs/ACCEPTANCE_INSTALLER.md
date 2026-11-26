# Локальный установщик для приёмки Windows/macOS

Omarchy отложена владельцем. Этот этап даёт локальный native комплект до
публикации public release URLs. Он содержит текущую IDE, private Neovim,
готовые parsers/rg, optional private Terminal и прежний UI Default/Custom.
Обычный nvim/config и Go/Rust/Python/Node SDK не заменяются. Default оставляет
языки отложенными; подготовкой управляет `Space l S` после установки.

## Запуск готового комплекта

Windows приёмка2026-11-22, пункты1–4: startup/отзывчивость предварительно
приняты владельцем. После IDE-150 повторить create/copy/move с кириллицей и
проверить Files без Git-меток; исходную временную невидимость lab ещё проверить.
Новые normal keys: F1 — поиск хоткеев, Alt+B — открытые файлы,
gR внутри Files / :ForgeExplorerRoot — корень проекта, Space E — reveal
активного файла с сохранением соседей. Ctrl+J/K палитры больше не растят отступ.
[Результаты и ограничения](../openspec/changes/fix-acceptance-explorer-and-pickers/verification.md).

Windows, из каталога выданного комплекта:

```powershell
.\install.cmd
```

Кандидат Windows из ревизии `f2d4769`, подготовленный 2026-11-26:

```powershell
.\.tests\installed-upgrade-20261126\installer-current\install.cmd --install-dir "F:\apps\fride"
```

На отдельном профиле прошли установка старого Core `17c0b00`, обновление
до `f2d4769` и повтор из того же пакета. Проверены резервная копия конфига,
запуск через установленный `bin/fride.cmd` и 2524 SHA256 пакета после
повтора. Журналы установщика находятся в `logs` рядом с `payload`.
Приёмка macOS и GUI WezTerm ещё впереди.
[История и доказательства §321](../nvim_forge/FIXLOG.md#321-повторная-установка-fride-из-одного-комплекта)

Можно указать новый путь с ещё не существующими родителями:

```powershell
.\install.cmd --install-dir "F:\apps\fride"
```

Кандидат 2026-11-22: `windows-log-tail-fix`, code `17c0b00`.
Включает IDE-152 (открытие Logs в хвосте без сброса чтения истории) и прежние
IDE-149/Python/Files/раскладки fixes. В `F:/apps/fride` Logs уже обновлён с
backup; **достаточно перезапустить fride**. Старая рабочая сессия агентом не
перезагружалась.2 native installed-source controls PASS;2521 manifest hashes
и Default plan проверены, runtime2357 файлов идентичен windows-ownership-fix.
[Доказательства и ограничения](../openspec/changes/follow-ide-log-tail/verification.md).

2026-11-21: этот кандидат содержит исправление Python F5 (§302), code commit
`182b160`. В существующем `F:/apps/fride` три соответствующих Lua файла уже
обновлены с backup; достаточно перезапустить fride. Новый кандидат предназначен
для следующей полноценной установки/приёмки. [Результаты и границы](../openspec/changes/fix-python-auto-launch-runtime/verification.md).

2026-11-22: актуальный комплект `windows-files-fix`, code commit `fa46778`,
добавляет async delete и сообщения без modal ожидания (§303), включая прежний
Python fix. В `F:/apps/fride` четыре config файла и один Neo-tree companion
уже обновлены с backup. Требуется перезапуск редактора, переустановка не нужна.
Help/session ownership — отдельный следующий IDE-149, текущий комплект его
ещё не исправляет. [Фактическая проверка](../openspec/changes/keep-filesystem-errors-responsive/verification.md).

Позднее2026-11-22: текущий candidate **windows-navigation-fix**, code88b2006,
добавляет IDE-150 и включает предыдущие исправления. Два соответствующих Lua
файла уже обновлены в F:/apps/fride с backup; достаточно перезапустить fride.
Installed-source5 E2E и manifest/Default/runtime probes PASS; native Mac и
повторная GUI приёмка lab остаются открытыми.

Актуальный candidate после IDE-151: **windows-layout-fix**, codea7cf782.
Добавлены общие aliases для explicit Shift-кириллицы; два Lua файла уже обновлены
в F:/apps/fride с backup, installed-source root/reveal1 PASS. Runtime прежний,
2520 SHA entries и Default plan проверены. Текущее скрытие сохранено по решению
владельца. [Какие keys приняты руками](OWNER_TESTED_HOTKEYS.md).

На Mac — в native комплекте своей архитектуры:

```bash
bash ./install.sh --install-dir "$HOME/Applications/fride"
```

Default — обычный запуск. Для галочек — `--profile custom`. Предпросмотр
без установки — `--preview`; машинный read-only plan — `--print-plan`.
Проверка payload выполняется перед frontend. Source/runtime принадлежат
комплекту; эти внутренние параметры нельзя подменить через entrypoint.

После установки Windows: `F:\apps\fride\bin\fride.cmd <проект>`.
Mac: `"$HOME/Applications/fride/bin/fride" /путь/к/проекту`.
Для private WezTerm — соседний `fride-terminal.cmd` / `fride-terminal`.
Обычный PATH не переписывается; `--command-dir` остаётся явным выбором.

Повтор/upgrade запускается тем же install entrypoint с прежним install directory.
Существующий комплект и настройки защищает прежний installer backend; wrapper
не вводит отдельного механизма установки. Нужен доступ к upstream Git/plugins/
Mason sources: это локальная доставка IDE runtime, а не полностью offline install.
В Custom со снятым Terminal его files/probes/PATH и launcher не устанавливаются,
даже если исходный приёмочный комплект содержит готовый Terminal.

## Подготовка native комплекта из checkout

Это **publisher/developer stand**, а не команда пользователя на чистой машине.
Нужны Python3, Git, готовый Rust SDK для frontend, CMake/C compiler и tree-sitter CLI
для parsers. Они переиспользуются; stand не устанавливает SDK/компиляторы.
Готовые native inputs можно передать явно и не пересобирать.

На Mac и Linux:

```bash
python3 -B scripts/prepare-acceptance-installer.py --download
```

На Windows с уже подготовленным private SDK:

```powershell
python -B scripts/prepare-acceptance-installer.py --download
```

Результат — `.tests/acceptance-installer/publisher/<platform>/installer`;
последняя строка вывода содержит install entrypoint. Native platform определяется
автоматически: полный Core+Terminal stand поддерживает macos-arm64/x64,
linux-x64, windows-x64 по текущей Terminal policy. Каждый пакет
собирается на соответствующей ОС. Существующий output не перезаписывается;
для следующего candidate укажи новый `--output`.

Команда явно получает upstream Neovim на POSIX, готовит frontend, pinned plugin
sources, native parsers, search и Terminal существующими publisher scripts,
затем собирает installer directory. Она не меняет public artifact catalogs.
На Windows используется существующий patched SDK из `.tools/neovim/windows-x64`;
его отдельная подготовка — `scripts/prepare-windows-sdk.ps1 -Download`.

Готовые inputs, например на этой Windows:

```powershell
python -B scripts/prepare-acceptance-installer.py --nvim .tools/neovim/windows-x64 --editor-deps .tests/neodev-review/editor-deps --site .tests/parser-runtime/windows-x64/site --search .tests/search-runtime/windows-x64 --terminal .tests/terminal-runtime/windows-x64 --frontend .tests/acceptance-installer/frontend/windows-x64/fride-setup.exe --output .tests/acceptance-installer/windows-x64
```

Если уже есть Core/Terminal archives и current frontend с соседним manifest.json,
достаточно сборки без downloads/компиляции:

```bash
python3 -B scripts/package-acceptance-installer.py --core /path/core.tar.gz --terminal /path/terminal.tar.gz --frontend /path/frontend/fride-setup --output /path/new-installer
```

Если publisher намеренно не передал `--terminal`, используй Custom без Terminal,
например `--profile custom --components core`. Обычный Default stand готовит
и Core, и Terminal; снятая галочка исключает Terminal из установленного kit.

`build.json` фиксирует source commit, признак изменённого source worktree,
input SHA и tracked source list.
`payload.sha256` описывает полный payload. Private .tests/.tools/notes не входят
в source. Default public bootstrap пока не опубликован; нельзя выдавать эти
developer commands за публичный one-line install для чистой машины.

## Отдельная подготовка официального POSIX Neovim

```bash
python3 -B scripts/prepare-native-neovim.py --download --output .tests/native-neovim
```

Или `--archive /path/nvim-macos-arm64.tar.gz` без сети. Повтор проверяет готовый
output без downloads, не заменяет несовпадающие файлы. SHA закреплены по
[официальным assets v0.12.2](https://github.com/neovim/neovim/releases/expanded_assets/v0.12.2).
Это private publisher input, системный nvim и его config сохраняются.

## Что проверяется и что остаётся владельцу

Перед ручной проверкой редактора запусти `./scripts/test.ps1 acceptance`
на Windows или `bash scripts/test.sh acceptance` на macOS.
[Состав и подготовка тестов](TESTING_WORKFLOW.md#автоматическая-приёмка-редактора).

Новые tests/install-acceptance-package.test.py проверяют реальные native
PowerShell/Bash entrypoints и fride-setup plan с fixture runtime: параметры,
Unicode paths, Default/deferred policy, missing/tamper/extra/stale/conflict и
отсутствие private sources. Это не подмена full installed IDE acceptance.
tests/install-native-neovim.test.py имеет отдельный actual upstream archive case;
fixture cases не объявляют Mac native PASS.

После выдачи actual candidate владелец проходит [основные workflows](IDE_ROADMAP.md#основные-пользовательские-сценарии--уточнение-владельца-2026-11-12)
на Windows/Mac, включая GUI/clipboard/SDK paths, Debug/Tests/Git/restore.
Mac zsh startup/Go и Cmd+C остаются отдельными обязательными проверками.

Решение владельца реализовано: Core содержит готовую fzf-native library своей
ОС с pinned source/SHA и лицензией. Publisher проверяет загрузку/C ABI; plugin
setup только копирует library. На машине установки CMake/C compiler не нужны;
при отсутствии подходящего Core payload остаётся штатный Lua fallback.
Новые Windows/Ubuntu E2E проверяют отдельный setup process, затем настоящий
редактор, native C scoring/file/content navigation и fallback без compiler.
Это не объявляет native Mac/full GUI/clean-machine acceptance пройденными.
