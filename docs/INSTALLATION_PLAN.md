# IDE-138 — установка одной командой

Требование владельца2026-11-14: Default автоматически ставит всё необходимое;
Custom позволяет выбрать компоненты галочками с клавиатуры. Windows, Linux и
macOS. Пользователь не ищет binaries, не клонирует репозиторий и не выполняет
отдельные :Lazy/:Mason/prepare команды. Ollama/модели исключены.

## Уточнение границы и установки SDK — 2026-11-15

Решение владельца заменяет прежний план полной изоляции языковых SDK (§243):

- Изолируем только комплект IDE: Neovim, плагины/библиотеки, LSP/DAP и другие
  IDE-инструменты, настройки, данные и логи fride.
- Владелец выбрал штатный `NVIM_APPNAME=fride`: бинарь и конфигурация остаются
  в InstallPath, плагины/состояние/кэш — в стандартных каталогах отдельного
  приложения. XDG окружение SDK не меняется.
- Go, Rust/Cargo/Rustup, Node/npm и Python — обычные SDK пользователя/проекта.
  Переиспользуем установленное, выбранные версии, venv, homes, настройки,
  registries/auth и кэши. Не упаковываем их в отдельный профиль fride и не
  переназначаем глобально SDK homes/prefixes/config.
- Отсутствующее или несовместимое сначала показываем пользователю и предлагаем
  подходящее действие. Языковой SDK не устанавливается и не обновляется без
  его выбора, в том числе в Default. Автоматическая установка компонентов IDE
  не означает автоматическое управление языковыми SDK.
- [ ] Изучить **VS Code и IntelliJ IDEA**: обнаружение существующих SDK,
  проектный выбор версии/интерпретатора, предложение установки недостающего,
  явное действие пользователя и показ результата. Зафиксировать конкретный
  UX для fride перед реализацией; референсы пока не исследованы.
- [x] Удалить ошибочную общую SDK env/state policy из setup/launch, включая
  скрытое влияние приватных XDG путей на defaults SDK. Сохранить старые
  sdk-state файлы при обновлении, больше не выбирать их автоматически.
- [x] Исправить native E2E под эту границу: Windows7 cases проверены,
  Ubuntu6 PASS/1 Windows-only skip; launcher controls Windows7/Ubuntu6 PASS.
  Mac — отдельный нативный запуск владельцем, пока не проверен.
- [ ] Пересмотреть prerequisite/catalog delivery: языковым SDK не требуются
  приватные runtime artifacts fride; недостающий SDK предлагается через
  штатный механизм платформы после выбора пользователя.

**Готово на Windows/Ubuntu (§244):** исправление
[reuse-native-language-sdks](../openspec/changes/reuse-native-language-sdks/proposal.md).
Пустая заготовка package-node-runtime отменена. После этого исправления
следующий срез — UX native prerequisites по VS Code и IntelliJ IDEA.

## Текущая готовность

Состав, source entry, выбор Default/Custom и независимая установка комплекта
реализованы. Полная доставка совместимых SDK и настоящее развёртывание всех
инструментов ещё не готовы.
`install.ps1`/`install.sh` — development entry, пока не публичная инструкция
для чистой машины. Они получают полный source и вызывают private installer;
прежние global platform installers больше не вызываются из source entry.
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

## Независимый комплект — уточнение владельца2026-11-14

Комплект не обновляет и не заменяет пользовательские Neovim, SDK или WezTerm.
Корневой installer не запускает WinGet/apt/Homebrew, не пишет в registry PATH,
shell profile, ~/.config/nvim и обычный конфиг терминала. Ранее описанные ниже
package recipes относятся к legacy scripts, а не к текущему source entry.
Прямые старые nvim_forge/scripts/install-{windows,linux,macos} остаются legacy
system API; они могут менять host packages и не являются безопасной установкой
нового комплекта. Для IDE-138 использовать только root entry.

InstallPath/--install-dir теперь обозначает **корень комплекта**:

```text
Windows: %LOCALAPPDATA%/forge-nvim/installation
Linux/macOS: ${XDG_DATA_HOME:-~/.local/share}/forge-nvim/installation
  config/forge/     конфигурация
  runtime/          собственный Neovim и подготовленные инструменты
  tmp/log/          временные файлы и логи установки/редактора
  bin/fride        POSIX launcher; Windows: fride.cmd / fride.ps1
  bin/forge-nvim   полное имя; прежний bin/forge сохранён
  backups/          прежние config/runtime/bin после успешного обновления
```

Плагины/Mason/сессии/кэш находятся в стандартных Neovim-каталогах приложения
`fride` (`fride-data` для data на Windows). Точные пути: `:echo stdpath('data')`
и `:echo stdpath('state')`. Обычное приложение `nvim` не используется. Прежние
kit data/state/cache/sdk-state сохраняются без автоматического переноса;
явный setup готовит новое приложение. Несколько установок fride у одного
пользователя используют общий штатный namespace данных.

Source cache по умолчанию лежит рядом в forge-nvim/sources. Каталог с чужими
файлами, symlink/junction target или linked parent отклоняется. Подготовка идёт
в staging; прежний launcher/config/runtime сохраняются до успешного setup.
Данные Forge не удаляются. Обновления plugin data самого Forge пока не имеют
полного rollback; это не данные обычного nvim. Ошибочный staging сохраняется
для диагностики. Удаление комплекта не требует удаления чужих программ.

Launcher применяет IDE PATH/NVIM_APPNAME/temp только к своему процессу. XDG и
языковые SDK env/config/cache сохраняются. По умолчанию
команда вне комплекта не регистрируется, обычный nvim не изменяется. Явный
CommandDir создаёт fride launcher в выбранном каталоге, не меняя PATH/profile.
Если этот каталог уже доступен в PATH, fride вызывается по имени; в остальных
случаях доступен полный путь. Интеграция Terminal должна следовать той же
границе: собственный binary и явный --config-file, без замены .wezterm.lua.

### Runtime artifact и текущий gate

Подготовленный bundle: forge-runtime.json с schema1/platform/components/nvim,
относительными paths, probes и SHA256 каждого файла. Windows дополнительно
проверяет receipt готового patched SDK против scripts/sdk/windows.json;
обычный системный nvim не подхватывается. POSIX требует native v0.12.2.
Ссылки publisher материализует внутри bundle. files/probes — контракт доставки,
не замена native языковым E2E и реальной готовности каждого компонента.

Development API: -RuntimePath DIR / --runtime-path DIR или
-RuntimeArchiveUrl URL -RuntimeSHA256 SHA / --runtime-archive-url URL
--runtime-sha256 SHA. Поддерживаются ZIP Windows и tar.gz POSIX. Download
проверяет SHA256 до extraction; полный manifest/component mask проверяются
до изменения target. -SkipDependencies/--skip-dependencies сохранены как
совместимые неактивные параметры: private entry никогда не ставит host packages.

Пакет готового SDK собирается scripts/package-runtime.py --source DIR
--recipe RECIPE.json --output ARCHIVE.zip (или .tar.gz); рядом сохраняется
JSON receipt архива. Это developer/publisher API, не ручная подготовка обычным
пользователем. Recipe должен описывать реально подготовленные инструменты.
Без explicit runtime entry использует modular catalog (§241). Проверенные
полные Default bundles ещё не подготовлены/не опубликованы: missing artifact
даёт конкретный отказ. Публичный one-liner пока не обещается.

### Проверка границы

`python -B tests/install-isolation.test.py` на Windows или `python3 -B
tests/install-isolation.test.py` на Linux/macOS. Нужен уже готовый native SDK;
стенд не ставит host packages. Настоящие package/download/hash/native Neovim,
файлы чужого редактора и запуск; init/setup callbacks — fixture. Это isolation
E2E, не полная установка67 plugins и всех языковых инструментов.
Артефакты .tests/install-isolation/<id>, raw .tests/isolation-*.txt.
Windows PowerShell startup-cache, создаваемый до выполнения скрипта, выделен
наблюдателем отдельно; пользовательские конфиги/SDK сравниваются по SHA256.
Итог §236: Windows11 PASS и targeted2 PASS после добавления guard внутренних
links; Ubuntu11 PASS/1 Windows-only skip. Source/profile controls Windows19
PASS, Ubuntu18 PASS/1 skip. На Docker стенд использует native /tmp и экспортирует
доказательства в .tests; первый bind-mount прогон остановлен после timeout.
macOS и настоящий полный Default install пока не проверены.
Дополнительные native regressions bootstrap log и relative custom target:
по2 PASS Windows/Ubuntu. Даже первый bootstrap не использует log/stdpath обычного
nvim; относительный custom path становится абсолютным до запуска setup.

## Команда запуска и оформление — IDE-141

Уточнение владельца2026-11-14: продумать короткое имя запуска; визуальное
оформление установщика взять из localvox-light для единообразия. Это план,
не уже выполненное переименование/регистрация команд или замена текущего UI.

### Имя и доступность команды

Выбор владельца2026-11-14: короткая команда **`fride`** — Forge IDE.
В установленном комплекте: `bin/fride .`, `bin/fride main.go` (Windows:
bin/fride.cmd или bin/fride.ps1). Полное имя bin/forge-nvim и старое bin/forge
используют тот же launch-managed source, конфиг и данные. Managed приложение
использует NVIM_APPNAME=fride; checkout сохраняет профиль nvim_forge.
В checkout: `.\fride.cmd .` / `./fride .`, через прежние launch helpers и
профиль nvim_forge. Прежние nvim_forge.cmd/nvim_forge.sh сохранены.

`forge` не стоит безусловно занимать в PATH: одноимённая команда есть у
[Foundry](https://www.getfoundry.sh/forge). На текущем Windows-хосте Get-Command
не нашёл forge/forge-nvim/fnvim/fvim, но это не проверка всех целевых машин.
Установщик должен проверять конфликт именно на машине установки и показывать
найденный путь. Чужие executables, aliases/functions и shell profiles не заменять.

Под «алиасом» подразумеваем постоянный launcher с одинаковым поведением на всех
ОС, а не временный shell alias: передача файлов/аргументов, cwd, stdin/TTY и
exit code сохраняются. Ни nvim, ни vi/vim не переназначаются. Никакой подготовки
SDK или source-работы при открытии новой shell-вкладки.

Явная регистрация: -CommandDir DIR в install.ps1/private PS backend,
--command-dir DIR в install.sh (private POSIX backend принимает шестой аргумент).
Режим по умолчанию portable, с пустым CommandDir. Каталог и недостающие родители
создаются автоматически; если он уже в PATH, fride доступен из любой папки.
Ни registry PATH, ни shell profiles/aliases/functions не меняются. При отсутствии
каталога в PATH installer показывает полный путь, не обещает bare-name lookup.

Регистрация создаёт fride (POSIX) или fride.cmd/.fride-command.ps1 (Windows) и собственный
.fride-command.json. Receipt привязан к kit и SHA256 wrapper bytes. Повтор не
перезаписывает файлы, недостающий собственный wrapper восстанавливается; файл,
поправленный пользователем, или другой kit дают конфликт. Чужой одноимённый
файл в выбранном каталоге/PATH отклоняется с указанием пути до изменения kit.
Проверка повторяется после setup, а files создаются exclusively. Неудачный
setup ничего не регистрирует; конфликт после setup возвращает прежние launchers.
Aliases/functions родительской shell дочерний процесс полностью обнаружить не
может: они сохраняют приоритет, проверять `Get-Command fride -All` / `command -v
fride` нужно в своей shell. Ни чужая команда, ни пользовательские файлы не
перезаписываются ради освобождения имени.
Служебный PS1 намеренно не называется fride.ps1: bare-name lookup должен выбрать
CMD launcher и работать без смены пользовательской ExecutionPolicy на Windows.

Пример development API с уже подготовленным runtime (не public one-liner):

```powershell
.\install.ps1 -Components core -RuntimePath F:\prepared-runtime -CommandDir "$HOME\.local\bin"
```

```bash
bash install.sh --components core --runtime-path /path/to/prepared-runtime --command-dir "$HOME/.local/bin"
```

Полная доставка Default SDK всё ещё открыта. Эти флаги не требуют ручной
подготовки от обычного пользователя будущего one-liner: это текущий developer
stand API. Шаг выбора команды в native LocalVox UI (§240) использует тот же backend.
Проверка §239: Windows23 PASS плюс7 affected policy/registration PASS после
исправления Restricted; Ubuntu22 PASS/2 Windows-only skip. Shared menu controls
по2 PASS. Это native command/PTY/isolation checks с fixture init/setup, не
подтверждение full Default SDK. Native Mac acceptance остаётся открытым.

### Референс LocalVox

Прочитан актуальный D:/rust_repo/localvox-light, commit4514678 от2026-11-14;
F:/claude_code/localvox-light остался старой копией42db779 и не использовался
как текущий образец. Репозиторий-референс только читался.

Источники: crates/localvox-setup-ui/src/lib.rs и wizard.rs,
docs/installer-preview.md, docs/release-installation.md. Просмотрены готовые
снимки target/review/installer-preview/components-wide.png и
custom-paths-review.png. Там один presentation frontend на cliclack0.5.6,
с темой InstallerTheme и готовым безопасным preview.

Требования к переносу в Forge (presentation реализован §240; actual package
readiness остаётся следующим этапом IDE-138):

- Бирюзовый акцент, компактный заголовок, вертикальный маршрут шагов и тонкие
  рамки заметок; приглушённые подтверждённые ответы/подсказки. Фон наследовать
  от терминала; внешняя декоративная рамка изображения не является частью TUI.
- Custom: компоненты с галочками и коротким объяснением; обязательный Core
  вынесен отдельно. Стрелки/j/k, Space, Enter; внизу видимые актуальные клавиши.
- Пути и команда запуска представлены понятными полями; рекомендуемые пути
  принимаются без ручного ввода. Выбор сохраняется при возврате на прошлый шаг.
- Esc: назад/продолжить текущий шаг/отмена, как в LocalVox, без потери уже
  подтверждённых ответов. Перед действиями Custom — итог состава, путей и
  регистрации команды; не добавлять отдельные подтверждения на каждый пакет.
- Подготовка: этапы/статусы/прогресс и путь к подробному логу. Ошибка указывает
  компонент и действие; итог готовности отражает actual readiness.
- Безопасный preview с тем же frontend, который ничего не скачивает/не пишет
  в пользовательскую систему; узкий терминал и plain/no-color вывод учитываются.

Реализован §240: один небольшой общий native frontend на cliclack,
поставляемый готовым artifact. Rust/Cargo у пользователя не требуется, runtime
не привязан к checkout LocalVox. Presentation-код/закреплённые зависимости
перенесены в installer-ui; private install backend/изоляция сохранены. Native
Mac, публикация artifacts и actual package readiness остаются открытыми.
Одинаковое оформление не означает перенос OS package-manager логики LocalVox.
Ollama/модели по-прежнему исключены из комплекта Forge.

Default сохраняет автоматическую установку рекомендованного набора без
длинного опроса; explicit component flags и запуск без TTY остаются доступны.
Меняется визуальный слой; новый обязательный диалог Default этим решением
не вводится. Будущий E2E: Default/Custom/back/cancel, сохранение выбора,
конфликт команды, unchanged foreign files, no-TTY/no-color и native три ОС.

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

## Предпросмотр и native UI — §240

Один `fride-setup` использует закреплённые cliclack/console и тему/навигацию
LocalVox (MIT notice — installer-ui/LOCALVOX-LICENSE.txt). Core обязателен,
остальные компоненты выбираются галочками из прежней components.tsv.
Default/явный Components работают автоматически; Custom показывает компоненты,
папку комплекта, необязательную команду в своём bin и итог. Стрелки — выбор,
Пробел — галочка, Enter — дальше, Esc — назад/продолжить/отмена. Подтверждённые
ответы сохраняются. Несозданные каталоги создаёт существующий private backend.

Предпросмотр из checkout не запускает backend и не создаёт выбранные каталоги:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preview-installer.ps1
# Сразу галочки; для fallback без цвета добавить -NoColor:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preview-installer.ps1 -Profile Custom
```

```sh
bash scripts/preview-installer.sh
bash scripts/preview-installer.sh --profile custom
```

Native frontend должен быть подготовлен. В текущем Windows checkout он уже
лежит в `.tools/installer-ui/windows-x64`; в Git бинарь не входит. Developer/CI
сборка на любой из трёх ОС: `python3 -B scripts/build-installer-ui.py --download`
(Windows: `python -B ...`). Нужен готовый Rust SDK; --rustc задаёт его явно.
`--download` разрешает только crates из Cargo.lock, не установку/обновление Rust.
Cargo/target/temp изолированы в .tests/installer-ui, результат и SHA/receipt —
.tools/installer-ui/<platform>. Это команда разработчика, установщик Cargo
не запускает. На Windows перед сборкой TEMP/TMP/TMPDIR направлять на F.

Source entry берёт готовый frontend из developer checkout, явного
-InstallerUIPath/--installer-ui-path либо скачивает native binary по URL/SHA256
из installer-ui/artifacts.tsv. Неверный SHA запрещает запуск. Каталог пока
не содержит опубликованных платформ: публичный one-liner ещё не готов.
Legacy source без UI marker сохраняет прежний advanced путь.

UI вызывает тот же private backend. Видны этапы runtime/plugins/parsers/tools;
полный вывод записывается в source cache/.ui-logs, подробные stage logs остаются
в kit/log. Ошибка сохраняет nonzero exit и показывает путь к логу. Без TTY
автоматический режим даёт обычные строки; Custom без explicit Components
отклоняется до установки. --no-color/NO_COLOR отключают цвет. Рамки/checkboxes
cliclack используют штатный ASCII fallback там, где console не распознал Unicode.
Снимки реального PTY — .tests/installer-ui/preview, без нарисованной симуляции.

Stand: `python -B tests/install-ui.test.py` на Windows; `python3 -B ...` на
Linux/macOS. Нужны готовый native frontend и native Neovim; переопределения
FORGE_INSTALL_UI_BINARY и FORGE_INSTALL_TEST_NVIM. Проверяются настоящий PTY,
localhost доставка UI/source, SHA, install/launch/repeat, failure/log/exit и
foreign snapshots. Init/setup — fixture; это не full SDK/package acceptance.
Для Docker готовый Linux UI помещается в .tests/ubuntu/installer-ui/linux-x64;
команда в tests/README.md. macOS запускается владельцем нативно, gate открыт.

## Модульная доставка компонентов IDE — transport §241

Уточнение2026-11-15: transport остаётся для Neovim/IDE tools/libs. Существующая
closure ещё ошибочно считает node-runtime/go-runtime приватными parts; до
release её надо заменить native prerequisite discovery/выбором пользователя.
Catalog пуст, автоматической поставки языковых SDK сейчас нет. Описанный ниже
Node stand сохраняет историческую проверку transport, не задаёт состав release.

Без RuntimePath/RuntimeArchiveUrl frontend выбирает готовые архивы из
scripts/runtime/artifacts.tsv: platform, component, HTTP(S) URL, SHA256.
Выбор — Core плюс прежняя canonical closure. Снятый в Custom компонент не
скачивается; общая часть скачивается один раз. Preview каталога
не требует. Missing/duplicate/invalid entry останавливает установку до backend.
Catalog пока без release rows: это готовый путь доставки, не опубликованный SDK.

Core сохраняет прежний forge-runtime.json с supported Neovim; дополнительная
часть содержит forge-component.json со schema1/kind component, native platform,
единственным component ID, files/SHA256, executable paths и probes. Все архивы
получаются существующим private downloader в cache по SHA. Общий Lua проверяет
состав/платформу/каждый файл и конфликты, собирает runtime в staging, исполняет
native probes и прежний setup. Итоговый manifest содержит все выбранные части.
Старый kit до успешной подготовки сохраняется. Explicit full-runtime API
продолжает работать и не требует component catalog.

Developer/publisher готовит part из уже подготовленных файлов (обычный
пользователь этого не делает):

```sh
python3 -B scripts/package-runtime.py --source /prepared/python-tools --recipe python-tools.json --component python --output python-tools.tar.gz
```

Windows: `python -B ... --output python-tools.zip`. Это IDE tools, не Python SDK.
Recipe содержит schema1,
platform, components с единственным ID, paths/probes. Core упаковывается прежней
командой без --component и должен содержать supported patched SDK на Windows.
Упаковка не выдаётся за фактическую готовность инструментов: все команды и
используемые data paths должны входить в настоящий release inventory.

Native stand: Windows `python -B tests/install-runtime.test.py`, Linux/macOS
`python3 -B tests/install-runtime.test.py`. Нужны готовые native Neovim/UI и
Node SDK24.11.0 (FORGE_INSTALL_NODE_SDK, либо прежний .tests/node-deps/sdk
stand cache; в Docker — готовый FORGE_E2E_NODE_DEPS). Ничего системного не
ставится, сеть только localhost. Проверяются настоящий source/UI/parts HTTP,
selected downloads/cache, private launch Node/npm, проверки повреждений,
конфликта и сохранения готового kit. Init/setup и feature-marker part — fixtures;
это delivery acceptance, не полная package readiness IDE.

Дальше IDE-138: native prerequisites с предложением установки и выбором
пользователя, затем release Core/IDE-tools inventory и функциональная проверка.
Языковые SDK и их persistent state остаются штатными; Mac/publication открыты.

## Проверка результата setup — §242

Setup проверяет результат после установки, используя те же каталоги, что
lsp/treesitter config (forge.tool_catalog, состав не изменён). Mason package
должен иметь receipt с правильным именем; объявленные bin/share/opt source и
exports должны существовать. Bin export проверяется через native executable
API, включая POSIX mode. Одного каталога пакета либо команды из host PATH
недостаточно. Старый Windows receipt schema1.0 учитывается штатным .cmd правилом.

После установки parsers проверяются их runtime libraries и native Neovim
language loader. Отсутствующий/непригодный parser или incomplete package даёт
nonzero с именем и причиной; следующие stages и публикация kit не выполняются.
Проверка сама не обновляет registry и не скачивает данные. Startup ничего
дополнительного не устанавливает. Success reports записываются в setup logs.

Это postconditions установки. Receipt/файлы не доказывают всю функциональность
LSP/DAP и совместимость SDK: release inventory/языковые E2E/native SDK context
и native Mac остаются отдельными пунктами. Не добавлялись LSP/provider/новые
пакеты и второй mechanism установки.

Команды: Windows `python -B tests/install-readiness.test.py`, POSIX
`python3 -B tests/install-readiness.test.py`. Нужны готовый native Neovim и
Mason plugin из .tests/editor-deps (FORGE_E2E_DEPS). FORGE_INSTALL_TEST_NVIM
задаёт native бинарь явно. Stand использует настоящий Mason Lua registry
provider/receipt/location и parser loader, controlled install callbacks и
fixtures package files, без сетевой установки. Артефакты —
.tests/install-readiness/<id>. Native Mac команда та же, здесь не запускалась.

## Native SDK context — §244

Решение §243 об отдельном профиле каждого SDK отменено. Shared SDK policy и
SDK bin paths удалены. XDG/HOME, SDK variables, caches, registries/auth и
активная venv наследуются. Изоляция IDE штатная, через NVIM_APPNAME=fride;
конфигурация из kit выбирается явно, включая lazy lockfile/rtp и открытие конфига.
PS caller environment восстанавливается, старые kit data/sdk-state не удаляются.

[Границы и команды проверки](SDK_STATE.md). Native prerequisites требуют
отдельного discovery/предложения установки с выбором пользователя; автоматическая
упаковка языка как части fride отменена. Публикация полного one-liner ещё открыта.
