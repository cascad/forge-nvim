# Design

## Context

См. proposal и §290. Root IDE baseline отсутствует; active IDE-BOOT-10/15/18
прочитаны целиком, их strict postconditions сохраняются для prepared subset.
Существуют общий SDK selector/resolvers, Core-first preflight через Lua,
native Rust frontend с SDK actions/bootstrap/nextest, setup-stage.lua, Mason,
Overseer и штатный SDK reopen с сохранением проекта/проверкой busy.

## Goals / Non-Goals

Goals: минимальная ready IDE без SDK; явная async подготовка выбранного языка;
постоянный обратимый hub; единые native providers/preflight/catalog/readiness.
Non-Goals: новый package manager/LSP, private API, собственные language SDK
packages/версионная матрица, скрытая смена среды активных задач, имитация Mac/GUI.

## Decisions

### Подготовленный набор

Desired components Default/Custom сохраняются. Базовая установка готовит Core
IDE tools, все выбранные готовые parsers/plugins и Terminal. Отдельный явный
preparation mask ограничивает tools/SDK initialization, не подменяет parser
или desired capability selection. Language tools deferred независимо от наличия
SDK; прежние уже установленные tools/SDK сохраняются и продолжают работать.
В review/result/owner metadata различаются Core ready и deferred languages.
Direct explicit setup и --check-sdks прежние. Явный --prepare-languages сохраняет
eager путь для developer/automation; обычный Default не спрашивает/не ставит SDK.

### Один native frontend для подготовки

SDK installation/bootstrap/confirm остаются в native frontend, не дублируются
в runtime Lua. Установленный kit получает копию текущего проверенного frontend
в bin и canonical sdk-preflight.lua/runtime-core.lua/Windows SDK policy в config
scripts. Это IDE maintenance payload, не SDK. Копирование выполняется общей
atomic staging границей, без изменения старого .tools frontend.

Новый --prepare-language <component> --installed-kit <kit> использует ready
owner/config/runtime и shared Lua resolvers с explicit installed-config layout.
Он не запускает install-private и не заменяет bin/runtime/config работающего kit;
после ready обновляет только текстовый fallback metadata bin/sdk-paths.txt.
После SDK decisions/nextest готовит только Core+выбранный language closure tools
существующим setup-stage.lua в отдельном Neovim, с native SDK paths до Mason.
Result/report пишутся только после readiness; отмена/ошибка сохраняет предыдущую
среду. Explicit eager repository setup использует те же providers.

### SDK providers

Ubuntu Go/Rust recipes вместо APT используют один shipped headless Lua worker,
который native frontend запускает через verified Core после подтверждения.
Go выбирает официальный stable archive/architecture/SHA из go.dev metadata,
готовит новый versioned SDK в обычном HOME/sdk, не перезаписывает существующий
SDK; результат возвращает bin/path. Rust — официальный rustup, обычные
CARGO_HOME/RUSTUP_HOME, --no-modify-path, rustfmt/rust-src. Ready installations
reused; custom/project paths не заменяются. Native provider report добавляет
проверенный fallback SDK path. WinGet/Homebrew и их bootstrap остаются штатными.
На POSIX новая Rust-среда использует rustup; готовый Windows rustup также
переиспользуется, новый Windows manager — через WinGet. Временный результат
provider применяется только в дочерней подготовке, не перекрывает сохранённый
explicit SDK выбор; project probes учитывают cwd и отключают auto-install.
APT commands, где применяются, получают DEBIAN_FRONTEND=noninteractive внутри
sudo boundary; системные настройки/caller env не переписываются.

### Runtime и постоянный hub

SDK executable paths сохраняют имя запускаемой команды при canonical parent
directory. Нельзя раскрывать leaf symlink `rustc`/`cargo` в `rustup` и затем
проверять/запускать другое имя: upstream proxies используют имя команды.
Directory SDK selection остаётся canonical; произвольный `rustup` вместо
`rustc` не становится допустимым executable. Actual installed async acceptance
проверяет готовность после version probes на обычном rustup environment.

Общий модуль языковых сред отображает Go/Rust/Python/Node/Bash/SQL; Bash/Python
показывают Node dependency, SQL не требует универсального SDK. Ручной SDK/path
делегируется ForgeSdk (sdk.json/tools.json), tools — Mason. Space l S открывает
hub, прямой ForgeSdk остаётся. Explicit hub проверяет versions асинхронно;
FileType делает только local path/receipt check, без registry refresh/network.

Первая подсказка — ненавязчивое уведомление с переходом в hub, без перехвата
ввода. Dedup root+language на сеанс. Policy хранится отдельно от SDK choices:
user languages.json и .fride/languages.json с project precedence; Later — только
сеанс, persistent disable/reset — явные действия. Источник/область видны в hub.

Подготовка запускается публичной async terminal/task API с argv/env/cwd без
shell-интерполяции путей. Native frontend UI доступен в штатной нижней панели;
одна активная задача внутри сеанса предотвращает параллельные prepare; повтор
открывает её вывод, другой язык можно подготовить после завершения. Native
Mason/rustup сохраняют свои locks. Успешный результат позволяет сохранить выбор
через существующий resolver и явно применить/reopen; busy debug/tests/terminal
не прерываются. Все отказы/progress доступны в ForgeLogs/task output.

## Risks / Trade-offs

Initial Default теперь не означает готовые20 Mason packages → явные deferred
статусы, новые positive cold cases и сохранение strict negative eager controls.
Installed helper layout → одинаковые canonical scripts, bounded output/valid
ready marker/runtime, source+installed SDK tests, без duplicate settings reader.
Common SDKs → atomic new Go directory/preserve guards, native rustup semantics,
никаких SDK файлов в kit; wrong explicit path остаётся ошибкой.
User edits during async prepare → no forced restart, source/current-root checks,
явное применение; cancellation оставляет доступен editor.
Network/cold SDK медленнее обычных tests → отдельный explicit stand, один повтор
после цельной реализации; общий regression один раз на финальном checkpoint.

## Migration Plan

Upgrade через обычный installer добавляет maintenance payload/metadata и
сохраняет существующие SDK/Mason versions. Старый source checkout без готового
frontend не запускает Cargo автоматически: hub показывает доступные manual
choices и причину отсутствующего maintenance entrypoint. Исторические RED/PASS
§285–290 не переписываются; новые результаты и FIXLOG добавляются отдельно.
