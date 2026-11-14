# IDE-138 — установка одной командой

Требование владельца2026-11-14: Default автоматически ставит всё необходимое;
Custom позволяет выбрать компоненты галочками с клавиатуры. Windows, Linux и
macOS. Пользователь не ищет binaries, не клонирует репозиторий и не выполняет
отдельные :Lazy/:Mason/prepare команды. Ollama/модели исключены.

## Текущая готовность

Состав и remote source entry реализуются первым срезом. Полный Default,
Custom menu и настоящее развёртывание всех инструментов ещё не готовы.
`install.ps1`/`install.sh` — development entry, пока не публичная инструкция
для чистой машины. Они получают полный source и вызывают прежний platform
installer в local-source mode, обходя неправильный monorepo clone в config.
Полная готовность IDE-138 определяется этапами ниже, а не одним exit0 bootstrap.

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

## Найденные пробелы прежних установщиков

| Область | Текущее состояние → необходимая работа |
|---|---|
| Windows/Linux remote config | clone монорепо прямо в config даёт неверный уровень. Entry получает source отдельно и передаёт local-source, но прежние прямые remote пути ещё не исправлены |
| Windows dependencies | winget отсутствует → warning/manual; языки opt-in, Node нет; после обновления PATH теряется process-only окружение. Не проверяются все native command exit codes |
| Windows SDK | У нас проверенный временный Neovim SDK74aff15b с двумя native patches; winget Neovim не является доказанным эквивалентом. Нужен автоматически получаемый готовый artifact и manifest, без ручной сборки пользователем |
| Linux dependencies | distro Neovim/version и tree-sitter-cli availability не проверены; Go/Rust opt-in, Node/полная Rust preparation отсутствуют |
| macOS prerequisites | Требуются уже готовые Homebrew/CLT/Git; автоматический bootstrap этих prerequisites и продолжение после системного шага ещё не реализованы |
| Plugins | Windows/Linux используют Lazy sync вместо restore; all backports и их check не сведены в обязательный setup step |
| Language/debug/tests | Mason catalog не покрывает весь runtime inventory; Windows CodeLLDB предполагается внешним, TSLS/js-debug/Bats/nextest/SQL SDK требуют явной доставки |
| Preparation success | Treesitter/Mason errors могут стать warning или подавляться pcall; exit0 не доказывает готовую IDE |
| Custom/repeat/recovery | Нет общего меню/профиля, полной проверки selected components, resume и отчёта фактической готовности |

Наличие инструмента недостаточно: нужна совместимая версия и реальный запуск.
SDK/source policies остаются существующими языковыми границами. Не переносим
download/install в startup shell или IDE и не запрещаем Go toolchain глобально.

## Последовательность реализации

1. Состав и remote source delivery: текущий change add-remote-installer-bootstrap.
2. Единый Default/Custom: один набор компонентов и dependencies, native UI без
   мыши, Default без интерактивного меню; общие решения и OS-specific install.
3. Поддерживаемые Neovim/prerequisites и языковые runtime/SDK. Готовые artifacts
   и их manifests; не выдавать системный пакет другой версии за supported SDK.
4. Общий явный setup: lock restore → все backports/check → selected parsers/
   tools → actual readiness; ошибка обязательного компонента даёт nonzero exit.
5. Repeat/backup/recovery и настоящий isolated install стенд на каждую ОС.
6. Native Default/Custom acceptance; только затем публикуемые one-liners.

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
