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
- [x] Изучить **VS Code и IntelliJ IDEA**: обнаружение существующих SDK,
  проектный выбор версии/интерпретатора, предложение установки недостающего,
  явное действие пользователя и показ результата. Зафиксировать конкретный
  UX для fride перед реализацией; официальные docs изучены ниже, GUI не запускался.
- [x] Удалить ошибочную общую SDK env/state policy из setup/launch, включая
  скрытое влияние приватных XDG путей на defaults SDK. Сохранить старые
  sdk-state файлы при обновлении, больше не выбирать их автоматически.
- [x] Исправить native E2E под эту границу: Windows7 cases проверены,
  Ubuntu6 PASS/1 Windows-only skip; launcher controls Windows7/Ubuntu6 PASS.
  Mac — отдельный нативный запуск владельцем, пока не проверен.
- [x] Отделить native SDK prerequisites от private runtime artifacts (§246).
  SDK не скачивается вместе с IDE; passive preflight останавливает setup при
  missing/unavailable. Меню выбора пути/штатной установки — следующий пункт.

**Готово на Windows/Ubuntu (§244):** исправление
[reuse-native-language-sdks](../openspec/changes/reuse-native-language-sdks/proposal.md).
Пустая заготовка package-node-runtime отменена. После этого исправления
следующий срез — UX native prerequisites по VS Code и IntelliJ IDEA.

## Предложение SDK: выводы по VS Code и IntelliJ IDEA — §245

Проверены официальные документы2026-11-15, без запуска GUI референсов.
VS Code Python обнаруживает доступные окружения и показывает активное;
пользователь может сменить интерпретатор через список, отдельно создать
окружение. [Python environments](https://code.visualstudio.com/docs/python/environments).

В IntelliJ IDEA SDK выбирается из найденных, добавляется указанием пути либо
скачивается отдельным действием. Для Download JDK пользователь выбирает
версию, поставщика и каталог. Bundled runtime самой IDEA отделён от project
JDK. Это референс разделения ответственности, Java в fride не добавляем.
[SDKs](https://www.jetbrains.com/help/idea/sdk.html).

Не всё поведение VS Code требует запроса: Go extension описывает попытку
установки отсутствующего gopls. Это IDE tool, отдельно от установленного Go.
Не переносим обобщение «VS Code никогда ничего не решает» на все расширения.
[Go extension](https://marketplace.visualstudio.com/items?itemName=golang.go).

Для fride принимаем следующий сценарий на основе требований владельца:

1. После выбора компонентов показать языковые prerequisites: найденный SDK,
   фактический путь/версия и зависимые IDE tools. Готовое переиспользовать.
2. Для отсутствующего/неподходящего: «Выбрать существующий», «Установить»,
   «Пропустить зависимые компоненты», «Отмена». Всё доступно с клавиатуры.
3. Перед установкой показать штатный способ, версию/источник и затрагиваемые
   каталоги. Никаких SDK download/install/update до явного выбора, включая
   Default. Без TTY нерешённый prerequisite даёт actionable отказ.
4. После действия перепроверить SDK; показать результат и лог. Отмена сохраняет
   прежнюю установку IDE. Не переустанавливать здоровый SDK и не импортировать
   credentials. Редактор не блокируется проверками/установками на startup.

Это проектный сценарий fride, не заявление о точном поведении всех референсов.
SDK preflight и меню реализованы (§246–247). Дальнейшие конкретные срезы:

- [x] Отделить native SDK prerequisites от private artifact closure; passive
  discovery без скачивания toolchains и без полного сканирования диска.
- [x] Подключить выбор существующего пути/штатной установки/пропуска/отмены
  к native UI. Обновить итоговый component selection и логи.
- [x] E2E Windows/Ubuntu: SDK уже есть, отсутствует, CLI не отвечает/не подходит,
  выбран свой путь, отмена,
  отказ установки/повтор; Default и noninteractive не устанавливают SDK молча.
  native Mac/real package installation отдельно владельцем.
- [x] Clean-machine manager flow (§249): отсутствующий WinGet/Homebrew
  предлагается установить официальным способом с отдельным ответом «Нет»
  по умолчанию. Затем отдельно подтверждается SDK. APT — компонент Ubuntu;
  его отсутствие не запускает ремонт ОС. Windows/Ubuntu stand проверен,
  native Mac/настоящая установка менеджеров остаются owner acceptance.
- [ ] Следующий срез: release inventory Core/IDE tools, совместимые native
  artifacts и функциональная проверка полного Default. Затем публикация
  one-liner и native Mac acceptance; публичная установка ещё не готова.

§250: [inventory существующих возможностей](RELEASE_INVENTORY.md) составлен.
Обнаружены пропущенные внешние IDE tools и отдельные Bash/SQL/Windows debugger
steps. §251 закрыл gopls/stylua/gofumpt/golines/prettier, §252 — codelldb/Bash
через Mason и native SQL part. SDK компилятора для SQL не требуется. Следующий
срез — Core/Terminal artifacts, затем actual Default/Custom и native Mac.

## Текущая готовность

§246: `Plan.components` содержит только IDE parts, `native_sdks` — отдельный
список. SDK preflight выполняется до catalog/download/target writes. Статусы
ready/missing/unavailable, путь/версия/причина и probe logs сохраняются в JSON;
nonready останавливает actual setup. Timeout2s/CLI, Windows Store aliases не
запускаются; Python3/активная venv поддерживаются. npm проверяется как доступный
entrypoint, без shell invocation. Это базовая CLI readiness, не полная package
совместимость. §247 добавляет SDK action menu в TTY (в том числе Default).
Без TTY прежний отказ сохраняется; SDK package install без confirm не вызывается.

Отдельная read-only команда после developer build frontend (никаких installs):

```powershell
.\.tools\installer-ui\windows-x64\fride-setup.exe --source . --components go,node --check-sdks --sdk-report .tests\my-sdk-report.json
```

POSIX: тот же `fride-setup` для своей платформы с теми же аргументами и `/` в
пути report. stdout — JSON, exit0 ready/exit2 missing или unavailable. Путь
report должен быть новым; по умолчанию report/probe logs в --log-dir. Preview
и print-plan SDK не запускают. Для actual setup неготовый SDK нужно выбрать
через PATH/штатно установить либо снять зависимые компоненты и повторить;
эти действия доступны из SDK menu в TTY. Для автоматизации existing bin можно
передать frontend через повторяемый `--sdk-path DIR` (fallback после PATH).

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

IDE не заменяет пользовательские Neovim/WezTerm, не пишет в registry PATH,
shell profile, ~/.config/nvim и обычный конфиг терминала. Для отдельно
подтверждённой установки SDK source entry может вызвать штатный WinGet/brew/APT;
этот менеджер управляет SDK и зависимостями в обычных каталогах системы.
Здоровый SDK переиспользуется, отдельный SDK profile fride не создаётся.
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

Уточнение2026-11-15, §246: transport только для Neovim/IDE tools/libs. Native
frontend проецирует legacy closure в components и native_sdks. node-runtime/
go-runtime исключены из IDE parts и отклоняются catalog/package/composition
API. Сами legacy component rows сохраняются для прежних platform scripts.
Catalog пуст, полный release ещё не опубликован.

Без RuntimePath/RuntimeArchiveUrl frontend выбирает готовые архивы из
scripts/runtime/artifacts.tsv: platform, component, HTTP(S) URL, SHA256.
Выбор — Core плюс IDE-часть canonical closure. Снятый в Custom компонент не
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
selected downloads/cache, host Node с маленьким private IDE JS tool, проверки
повреждений, конфликта и сохранения готового kit. Init/setup/tool part — fixtures;
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


## SDK menu — §247

Если SDK не готов и есть TTY: existing root/bin/Scripts, install, skip зависимых
компонентов, refresh, cancel. После изменения план подтверждается ещё раз.
--result создаётся после SDK decisions; cancel130 оставляет прежний kit и
не создаёт успешный plan. Уже подтверждённые SDK остаются standalone.

Install показывает конкретную команду/source/version policy, confirm по
умолчанию «Нет». Tee stdout/stderr сохраняется в sdk-install-*.log, повторные
checks в уникальных sdk-check-*.json; final --sdk-report не конфликтует с retry.
Exit0 без работающего SDK оставляет меню доступным. Fallback paths сохраняются
только при успешном SDK/IDE setup в kit/bin/sdk-paths.txt; после caller PATH,
без копирования SDK/config/credentials. Они переиспользуются на upgrade.

Методы штатные: [WinGet install](https://learn.microsoft.com/en-us/windows/package-manager/winget/install),
[brew install](https://docs.brew.sh/Manpage#install-options-formulacask-),
[APT install](https://manpages.ubuntu.com/manpages/noble/man8/apt-get.8.html).
Named SDK upgrade не запрашивается (--no-upgrade/HOMEBREW_NO_INSTALL_UPGRADE),
зависимости обрабатываются менеджером. Windows IDs проверены по
[Microsoft WindowsDeveloperConfig](https://github.com/microsoft/WindowsDeveloperConfig/blob/main/windows-dev-config/steps/packages.ps1).
При отсутствующем менеджере SDK menu предлагает отдельный bootstrap (§249).
Real package install на машине агента не
делался: native fixture manager в E2E проверяет flow/argv/logs/recheck/cancel.

## Windows publication locks — §248

Пойман EPERM при rename подготовленного runtime в UI control. Тот же staging
позже переименовался; исходный holder не снят. Native deny-delete handle
воспроизвёл этот класс ошибки. Только Windows EPERM/EACCES/EBUSY ожидаются
ограниченно1.5s перед повторным rename; прочие ошибки немедленны. Persistent
lock сохраняет ошибку/rollback, чужие процессы/ACL не трогаются. Обычный startup
и POSIX rename не замедлены. Tests/install-locks.test.py проверяет transient
успех и сохранение прежнего runtime/bin/owner при постоянной блокировке.


## Bootstrap менеджера SDK — §249

Для отсутствующего WinGet/Homebrew: отдельный источник/команда/каталоги и
confirm по умолчанию «Нет», затем discovery менеджера и отдельный SDK confirm.
Microsoft.WinGet.Client/отсутствующий NuGet provider — CurrentUser, существующий
модуль не переустанавливается. Официальный Homebrew/install закреплён commit
 e5b3c5834e3932c8aaa42deef4794076c9b0cbf0; sudo/CLT обрабатывает его native UI.
[WinGet bootstrap](https://learn.microsoft.com/windows/package-manager/winget/troubleshooting),
[Homebrew installation](https://docs.brew.sh/Installation).
Менеджер в стандартном каталоге вне PATH переиспользуется. Ни fride, ни этот
bootstrap wrapper не правят global PATH/profiles. APT считается частью Ubuntu;
его отсутствие оставляет existing SDK/skip/cancel, без ремонта ОС.

Windows: `python -B tests/install-sdk-bootstrap.test.py`,
`python -B tests/install-sdk-actions.test.py`; POSIX: python3 с теми же файлами.
Нужны готовые native UI/Neovim, Rust для fixture и Node stand SDK. Bootstrap/
package manager в E2E — локальный native fixture; host packages не ставятся.
Default No, SDK No, retry/error/exit0-no-manager, Escape, old kit cancel,
standard Windows alias и noninteractive проверены. Сам PowerShell recipe
исполняется с локальными cmdlet doubles. Mac команды подготовлены, но здесь
не выполнялись; для bootstrap нужен clean Mac без standard Homebrew.
Полный Default release inventory/functional readiness остаётся следующим срезом.

## Подготовка существующих IDE tools — §251

Пять уже используемых tools входят в тот же Mason setup, в штатные каталоги
приложения fride. Отдельного менеджера/языкового SDK внутри kit нет:

| Компонент | Tool | Закреплённая версия | Provider |
|---|---|---|---|
| Core | stylua | v2.6.0 | готовый native release |
| Go | gopls | v0.23.0 | Go source build |
| Go | gofumpt | v0.12.0 | Go source build |
| Go | golines | v0.16.0 | Go source build |
| Node | prettier | 3.9.10 | npm в каталоге Mason package |

Источник/версии: official Mason registry
[gopls](https://github.com/mason-org/mason-registry/blob/main/packages/gopls/package.yaml),
[gofumpt](https://github.com/mason-org/mason-registry/blob/main/packages/gofumpt/package.yaml),
[golines](https://github.com/mason-org/mason-registry/blob/main/packages/golines/package.yaml),
[stylua](https://github.com/mason-org/mason-registry/blob/main/packages/stylua/package.yaml),
[prettier](https://github.com/mason-org/mason-registry/blob/main/packages/prettier/package.yaml).
Строки registry меняются; перечисленные pins задаёт tool_catalog. Source/hash/
license inventory полного release этим не заменяется.

Core-only не требует Node или Rust SDK для StyLua. Галочка Node теперь явно
включает также JSON/YAML/Markdown formatting через Prettier. Project
node_modules сохраняет приоритет над shared Mason copy. Rustfmt остаётся
частью обычного Rust toolchain. Остальные language SDK/settings/auth/cache
наследуются, новые инструменты не ставятся в пользовательские global prefixes.

Если требуется собрать Go tools, explicit tools stage заранее проверяет
обычный Go1.26.0+: source modules требуют его в go.mod. При старом SDK ошибка
возникает до install, без скрытой загрузки Go. Готовые packages с правильной
версией переиспользуются без этого build requirement. Только setup process
выставляет GOTOOLCHAIN=local/RUSTUP_AUTO_INSTALL=0; launcher окружение SDK не
переназначает. Native SDK TUI пока не учитывает все build minima заранее;
backend сообщает причину. Полная compatibility matrix остаётся release gate.

Требования Go source:
[gopls](https://github.com/golang/tools/blob/gopls/v0.23.0/gopls/go.mod),
[gofumpt](https://github.com/mvdan/gofumpt/blob/v0.12.0/go.mod),
[golines](https://github.com/golangci/golines/blob/v0.16.0/go.mod).

Postconditions проверяют receipt version и нужный bin alias; Prettier — также
его JS entrypoint и доступный обычный Node. Одного success callback недостаточно.
run_on_start/auto_update остаются false, открытие файла не запускает install.

Проверка этого среза на отдельном stand (не инструкция публичной установки):

```powershell
python -B tests/install-ide-tools.test.py --prepare
python -B tests/install-ide-tools.test.py
```

POSIX: `python3` с теми же аргументами. Требуются подготовленные native Neovim,
Mason/Conform/LSP plugins из editor-deps, обычные Go1.26.0+/Node SDK. Windows
stand использует уже подготовленные .tests/dap-tools/go и .tests/node-deps;
POSIX — Go из PATH и Node stand из FORGE_E2E_NODE_DEPS. --prepare загружает/
собирает только пять IDE tools в .tests, SDK не устанавливает. Последующий
прогон использует готовые tools. Ни системные префиксы, ни обычный nvim не
подготавливаются этим stand. Native Mac здесь не запускался.

Windows/Ubuntu: настоящие Mason providers/receipts, Conform Lua/Go/JSON,
golines long-line, project Prettier, Go LSP definition, repeat и partial/version
failures проверены. Ubuntu — готовый container без сети с локальным Go/npm/
asset cache. Удалены только собственные compiler caches/project fixture copies;
готовые packages/receipts/logs оставлены для повторения. Дальше — debug/test
delivery из [очереди](RELEASE_INVENTORY.md#следующая-очередь-реализации).

## Доставка debug/test tools — §252

Windows/POSIX codelldb v1.12.2 готовится тем же Mason. Историческое Windows
исключение удалено; bundle содержит свои LLDB/Python libraries, чужой Python
SDK не дополняется. Bash adapter закреплён существующим registry tag
untagged-438733f35feb8659d939 (0.3.9). Tools stage применяет принятый patch
только к своему Mason entrypoint; unknown hash даёт nonzero без изменения
исходника. Повтор идемпотентен. Interactive :BashDebugPrepare остаётся доступным.
На startup patch/install не выполняется. Источники:
[codelldb](https://github.com/mason-org/mason-registry/blob/main/packages/codelldb/package.yaml),
[Bash](https://github.com/mason-org/mason-registry/blob/main/packages/bash-debug-adapter/package.yaml).

SQL component получает готовые sqls0.2.48+forge.1 и forge-sqltest0.1.0 из native
part. Managed SQL больше не требует Go/Rust/CC или stock Mason sqls; sqruff
остаётся Mason. Existing source builders нужны publisher, не пользователю.
Пример упаковки уже проверенных native builds:

```sh
python -B scripts/package-sql-tools.py --sqls .tests/sql-deps --runner .tests/sql-test-deps --output .tests/sql-tools.zip
```

POSIX: python3, .tar.gz output. Wrapper использует existing package-runtime,
проверяет platform/source/lock/patch/binary hashes и native versions, создаёт
обычный sql component с sql/bin и probes. Готовые локальные Windows/Ubuntu
archives/receipts — .tests/debug-tools/windows-x64 и
.tests/ubuntu/debug-tools/linux-x64; production catalog пока пуст.

IDE-only FRIDE_RUNTIME указывает staged/installed runtime. Runtime SQL lookup
предпочитает свои binaries перед старым Mason/PATH copy, explicit overrides
сохраняются. Перед ready проверяются именно доставленные native versions.
PowerShell launcher восстанавливает caller FRIDE_RUNTIME даже при exit7.

Команды целевого stand:

```sh
python -B tests/install-debug-tools.test.py --prepare
python -B tests/install-debug-tools.test.py
python -B tests/install-sql-delivery.test.py
```

POSIX: python3. Нужны native Neovim/UI/editor-deps, Node и готовые SQL builds;
Rust нужен только тестовому publisher/probe stand. --prepare получает два IDE
debugger payloads через Mason, языковые SDK не устанавливает. SQL delivery
проверяется через реальный source/UI/parts HTTP и установленный launcher с
Go/Rust скрытыми в PATH; query с комментарием, SQLite и existing Neotest adapter.
Другие Core plugins/parsers/Mason installs в этом stand контролируются;
это не full Default readiness. Нарушенные manifest/versions и сохранность
прежнего kit проверены. Full green suite не повторяется без изменений.

Windows: codelldb breakpoint/continue/output и Bash patch проверены; Bash
launch требует предоставленного WSL2 и здесь не выполнялся. Ubuntu:
codelldb/Bash launch и SQL consumers прошли в готовом offline container.
Native Mac/publication остаются открытыми. Следующий срез — Core/Terminal
artifacts и actual Default/Custom. Проверки этого этапа завершены15 ноября;
16 ноября после возобновления выполняется аудит и локальный commit.

## Готовые native parsers Core — §253

Managed Core содержит `runtime/treesitter`: прежний набор33 native libraries,
queries и query dependencies из locked Treesitter. Упаковщик проверяет grammar
revisions, native Neovim/Windows SDK receipt, фактическую загрузку libraries и
компиляцию queries; записывает platform/source/SHA metadata. Формат архива и
доставка остаются прежними package-runtime/catalog/private installer.

Managed parsers stage выполняет read-only проверку собственного site и не
вызывает tree-sitter/C-компилятор. Site включён в штатный runtimepath с учётом
reset Lazy и имеет приоритет перед старыми app-data parsers. Открытие файла
ничего не собирает. Обычная неменеджерская явная команда подготовки сохранена.

Publisher-команды из репозитория (это подготовка релиза, не шаги пользователя
установщика; нужны уже доступные native Neovim, tree-sitter CLI и C compiler):

```sh
nvim --headless -u NONE -i NONE -l scripts/prepare-parser-site.lua .tests/editor-deps/lazy/nvim-treesitter /prepared/site
python3 -B scripts/package-core-runtime.py --nvim /prepared/neovim --site /prepared/site --editor-deps .tests/editor-deps --output /artifacts/core.tar.gz
```

Windows: `python` и `.zip`, `--nvim .tools/neovim/windows-x64`; каталог site
задаётся явно. Prepared editor-deps создаёт существующий prepare_editor.py.
Source preparation использует штатный pinned Treesitter API; языковые SDK
не устанавливает. Упаковщик принимает уже подготовленные inputs и сам не
загружает/не компилирует их.

Native acceptance после подготовки site для своей платформы:

```sh
python3 -B tests/install-parser-runtime.test.py
```

По умолчанию site: `.tests/parser-runtime/<platform>/site`; другой путь —
`FORGE_PARSER_SITE`. Native Neovim/UI/editor-deps выбираются теми же
FORGE_INSTALL_TEST_NVIM/FORGE_INSTALL_UI_BINARY/FORGE_E2E_DEPS, что в остальных
install stands. Windows4 cases прошли с адресным исправлением fixture;
native load всех33 libraries/queries, HTTP delivery, настоящие Lua parse/captures,
отказы и сохранение прежнего kit проверены. Ubuntu ждёт предоставленного Docker
engine, native Mac открыт. Успешные suites повторно не запускались.

**Граница:** другие plugins/Mason stages в parser stand контролируются. Только
для parser stand отключён bytecode cache Lazy: v1 обнаружил настоящий сбой
vim.loader при basename257 символов в длинном Unicode staged path. Production
cache не изменён; исправление этого сбоя — блокер full Default. Для воспроизведения
задать FORGE_PARSER_TEST_CACHE=1 и запустить только test_parser_01_native_delivery_and_captures.
Git/rg, Terminal, полный source/license inventory и публичный catalog остаются
открытыми. Этот Core archive пока не является полной поставкой.
