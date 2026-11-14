# IDE-138 — установка одной командой

Требование владельца2026-11-14: Default автоматически ставит всё необходимое;
Custom позволяет выбрать компоненты галочками с клавиатуры. Windows, Linux и
macOS. Пользователь не ищет binaries, не клонирует репозиторий и не выполняет
отдельные :Lazy/:Mason/prepare команды. Ollama/модели исключены.

## Текущая готовность

Состав, source entry и выбор Default/Custom реализованы. Полная доставка
совместимых SDK и настоящее развёртывание всех инструментов ещё не готовы.
`install.ps1`/`install.sh` — development entry, пока не публичная инструкция
для чистой машины. Они получают полный source и вызывают прежний platform
installer в local-source mode, обходя неправильный monorepo clone в config.
Полная готовность IDE-138 определяется этапами ниже, а не одним exit0 bootstrap.
§233: transport по6 PASS на Windows/Ubuntu; native Mac пока не запускался.
§234: общий strict command setup — по7 native stand PASS Windows/Ubuntu;
macOS backend7 contract PASS в Ubuntu. Это не полная установка всех пакетов.
§235: Default без меню, Custom с клавиатурными галочками, общий профиль и его
применение к OS SDK steps/Mason/parsers/Terminal. Windows19 PASS, Ubuntu18 PASS/
1 platform skip; native Mac ещё не запускался.

Путь по умолчанию и пользовательский путь создаются автоматически, включая
отсутствующие родительские каталоги (уточнение владельца2026-11-14).
Отдельные регрессы проверяют оба варианта до существования каталога.

## Состав Default и галочки Custom

Default включает все строки таблицы. Core обязателен; остальные строки Custom
может снять. Общие зависимости выбранных компонентов устанавливаются сами.
Выбор определяется возможностями, а не списком пакетов разных ОС.

| Компонент | Что должно оказаться готовым |
|---|---|
| Core, обязательно | Поддерживаемый Neovim; nvim_forge/launcher; Git, rg/fd;67 plugins по lock,6 backports/16 files; Treesitter parsers/CLI и нужные build tools; Lua LS/stylua для конфигурации; общая проверка и логи установки |
| Go | Go SDK; gopls; gofumpt/golines; Delve; gotestsum и используемый golangci-lint |
| Rust | rustup/совместимый Rust SDK, Cargo, rust-src/rustfmt; rust-analyzer; CodeLLDB; cargo-nextest; системный linker/build toolchain |
| Python | Python/venv/pip; Pyright/Ruff; debugpy; pytest; пакеты проектов продолжают принадлежать project venv |
| JS/Node | Node/npm, TypeScript/TypeScript LS, Prettier, официальный JS debug adapter; готовность Jest adapter. Project Jest/config/dependencies устанавливаются в самом проекте, не выдумываются установщиком IDE |
| Bash | Native Bash, bash-language-server, shfmt/shellcheck, Bats; официальный bash-debug adapter и явная подготовка его существующего SDK patch. Windows: выбранный WSL2 backend и нужная Linux среда |
| SQL | Готовые sqls/sqruff/SQLite, существующие проверенные SQL SDK patches/runner для SQLLogicTest. Не разрабатываем новый LSP, references engine или DB server |
| Terminal | WezTerm, выбранный Nerd Font, существующая интеграция конфига; IDE также работает в обычном совместимом терминале |

Node runtime нужен также некоторым Python/Bash инструментам; снятие JS-галочки
не запрещает установить Node как их зависимость. Общие C/C++ tools и linker
выбираются по ОС; LLVM сам по себе не заменяет весь Windows Rust MSVC toolchain.
Проектные пакеты/учётные данные/DB connections и приложения пользователя
установщик не подменяет своими примерами. Это граница установки IDE, не ручная
доустановка её обязательных компонентов.
SQL/sqls использует Go build runtime: SQL без Go-набора добавляет go-runtime,
но не Go parsers/Delve/gotestsum. Зависимости видны в canonical selected list.

## Выбор профиля (§235)

Default выбран по умолчанию и не требует меню. Custom: стрелки или j/k,
Space переключает, Enter подтверждает, Esc/q отменяет до запуска backend.
Core снять нельзя. Root entry принимает `-Profile Custom` на Windows и
`--profile custom` на POSIX. `-Components 'python,sql'` / `--components python,sql`
задают выбор без UI; пустой explicit список означает Core. Неизвестный ID —
ошибка до package steps. Это API development entry, не готовый публичный
one-liner для полной установки на чистую машину.

Компоненты: core, go, rust, python, node, bash, sql, terminal. Node runtime
и Go runtime добавляются зависимостями из общей scripts/components.tsv.
PS/Bash используют эту таблицу без предварительной установки Python/Neovim;
Lua читает те же tools/parsers при explicit setup. Mask временный; PowerShell
восстанавливает caller env, обычный catalog без mask сохраняет прежний состав.
Прежние direct WithLanguages/skip flags остаются advanced режимом.

SDK handlers учитывают mask; Python/Bash/JS добавляют Node, SQL — Go и SQLite.
Windows selected profile требует работающего WinGet и прекращает установку
при CLI error. Автоматический bootstrap самого package manager, supported
versions, Windows Nerd Font/config, WSL/Bats/JS/SQL SDK preparation и полноценная
проверка установленного binary всё ещё в дальнейших этапах. Выбор галочки не
выдаётся за уже подтверждённую полную доставку её runtime.

## Найденные пробелы прежних установщиков

| Область | Текущее состояние → необходимая работа |
|---|---|
| Windows/Linux remote config | clone монорепо прямо в config даёт неверный уровень. Entry получает source отдельно и передаёт local-source, но прежние прямые remote пути ещё не исправлены |
| Windows dependencies | §235: component mask, Node/SQLite/WezTerm handlers и проверка Winget install exit; missing WinGet для профиля даёт nonzero. Сам bootstrap WinGet/supported versions ещё открыт. Legacy прямой запуск без mask сохраняет прежний fallback |
| Windows SDK | У нас проверенный временный Neovim SDK74aff15b с двумя native patches; winget Neovim не является доказанным эквивалентом. Нужен автоматически получаемый готовый artifact и manifest, без ручной сборки пользователем |
| Linux dependencies | §235: SDK groups/Node/SQLite/Bats разделены по mask. Distro Neovim/version и tree-sitter-cli availability не проверены; полноценная Rust preparation и supported SDK delivery открыты |
| macOS prerequisites | Требуются уже готовые Homebrew/CLT/Git; автоматический bootstrap этих prerequisites и продолжение после системного шага ещё не реализованы |
| Plugins | §234: общий Lazy restore и all backports apply/check реализованы. Полная доставка67 plugins в чистую систему ещё ждёт native install acceptance |
| Language/debug/tests | Mason catalog не покрывает весь runtime inventory; Windows CodeLLDB предполагается внешним, TSLS/js-debug/Bats/nextest/SQL SDK требуют явной доставки |
| Preparation success | §234: Lua/Vim exceptions и missing commands дают nonzero и останавливают следующие stages. Нужна ещё проверка фактического результата каждого пакета при внутренних errors без exception |
| Custom/repeat/recovery | §235: меню/профиль/dependency closure готовы. Полная проверка selected components, resume/отчёт фактической готовности ещё открыты |

Наличие инструмента недостаточно: нужна совместимая версия и реальный запуск.
SDK/source policies остаются существующими языковыми границами. Не переносим
download/install в startup shell или IDE и не запрещаем Go toolchain глобально.

## Последовательность реализации

1. Состав и remote source delivery: текущий change add-remote-installer-bootstrap.
2. Выбор Default/Custom реализован §235: один набор компонентов/dependencies,
   native UI без мыши, Default без меню; mask управляет существующими handlers.
3. Поддерживаемые Neovim/prerequisites и языковые runtime/SDK. Готовые artifacts
   и их manifests; не выдавать системный пакет другой версии за supported SDK.
4. Общий явный setup: lock restore → все backports/check → selected parsers/
   tools → actual readiness; ошибка обязательного компонента даёт nonzero exit.
5. Repeat/backup/recovery и настоящий isolated install стенд на каждую ОС.
6. Native Default/Custom acceptance; только затем публикуемые one-liners.

Общий command setup уже реализован в рамках пункта4: installed profile,
restore → existing backports apply/check → parsers → tools, отдельный native
процесс на stage. Windows XDG_CONFIG_HOME/NVIM_APPNAME восстанавливаются после
setup; POSIX изменения ограничены subshell. Native пакетная readiness/Custom
readiness и поддерживаемые SDK по-прежнему открыты; меню реализовано §235.

## Stand выбора компонентов

Windows: `python -B tests/install-profile.test.py` (temp на F). Linux/macOS:
`python3 -B tests/install-profile.test.py`. Нужны Python и готовый Neovim; SDK и
системные packages стенд не скачивает/не устанавливает. Настоящие localhost
HTTP/ZIP/tar, UI-attached Neovim PTY с PowerShell/Bash меню, native Lua catalogs,
изолированные package-provider contracts. Артефакты .tests/install-bootstrap/<id>.

Windows19 PASS; отдельно arrows/j/k/Space/Enter/q2 PASS. Ubuntu18 PASS/1 skip
(Windows Winget CLI). macOS package recipe3 contract PASS в Ubuntu; это не
native Mac acceptance. Setup controls по7 PASS Windows/Ubuntu, shell controls153
PASS. Полные downloads/registry readiness после selection проверяются отдельно.

Имена новых пакетов сверены с первичными источниками: [Winget Node LTS](https://github.com/microsoft/winget-pkgs/blob/master/manifests/o/OpenJS/NodeJS/LTS/24.17.0/OpenJS.NodeJS.LTS.installer.yaml),
[SQLite](https://github.com/microsoft/winget-pkgs/blob/master/manifests/s/SQLite/SQLite/3.51.1/SQLite.SQLite.installer.yaml),
[WezTerm](https://github.com/microsoft/winget-pkgs/blob/master/manifests/w/wez/wezterm/20230712-072601-f4abf8fd/wez.wezterm.installer.yaml).
Tool IDs/dependencies — [Mason TSLS](https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/typescript-language-server/package.yaml),
[JS debug](https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/js-debug-adapter/package.yaml),
[Bash debug](https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/bash-debug-adapter/package.yaml),
[sqls/Go](https://raw.githubusercontent.com/mason-org/mason-registry/main/packages/sqls/package.yaml).
Сверка имён не является pin/readiness конкретных latest binaries.

## Stand подготовки профиля

`python -B tests/install-setup.test.py` на Windows (TEMP/TMP/TMPDIR на F);
`python3 -B tests/install-setup.test.py` на Linux/macOS. Используется готовый
Neovim (.tools SDK на Windows, PATH на POSIX; --nvim задаёт явно), без downloads.
Стенд исполняет настоящий installer/Neovim, маленький config с fixture
Lazy/TS/Mason commands и public applier на16 private plugin files. Готовый
plugin cache берётся из FORGE_E2E_DEPS или .tests/editor-deps; он не меняется.
Это orchestration regression, не запуск настоящих package managers.

Семь случаев: missing Custom parents, missing Default directory, parser/tool/
missing-command/plugin failures, неизвестный backport. `--backend macos` в
Ubuntu проверяет shell contract; только запуск на Mac проверяет native macOS.
Raw cases/trace/native argv/exit — .tests/install-setup/<id>. Source snapshots
выбираются FORGE_INSTALL_SETUP_SOURCE только для regression stand.

## Stand текущего source entry

Это E2E доставки/dispatch, а не установка всех SDK: настоящий localhost HTTP,
скачивание entry и ZIP/tar.gz, системный PowerShell/Bash, fixture backend.
Package managers/личные конфиги не запускаются и не меняются. Артефакты —
`.tests/install-bootstrap/<id>`, Windows temp запускающего процесса задавать на F.

```powershell
$env:TEMP='F:/repo/forge-nvim/.tests/tmp'; $env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
python -B tests/install-bootstrap.test.py
```

На Linux/macOS из репозитория: `python3 -B tests/install-bootstrap.test.py`.
Ubuntu в уже запущенном Docker:

```sh
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never --entrypoint python3 ubuntu -B tests/install-bootstrap.test.py
```

Проверяются доставка/повтор, HTTP404, incomplete/broken archive, backend exit,
incomplete cache. Native Mac и настоящая полная установка — отдельные gates.
Bootstrap принимает Ref/ArchiveUrl/SourceRoot/InstallPath (POSIX: --ref,
--archive-url, --source-root, --install-dir); skip dependencies оставлен для
stand/advanced local workflow. Полученный source постоянный: конфиг macOS и
WezTerm могут на него ссылаться. Одинаковые bytes архива используют один SHA256
directory; старые версии здесь автоматически не удаляются.
