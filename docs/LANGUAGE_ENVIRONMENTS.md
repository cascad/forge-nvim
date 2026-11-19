# Языки и инструменты

`Space l S` или `:ForgeLanguages` открывает постоянный раздел Go, Rust,
Python, JS/Node, Bash и SQL. Быстрый вход: `:ForgeLanguages go`.
Он остаётся доступен после закрытия подсказки и отключения предложений.

При обычной установке Default/Custom готовятся редактор, плагины, выбранная
подсветка и Core tools. Языковые SDK и зависимые инструменты подготавливаются
отдельно. Открытие первого файла показывает короткую подсказку, если нужна
подготовка. Она не перехватывает ввод, не скачивает SDK и не запускает version
probes. Повторные открытия файлов того же языка в проекте её не повторяют.

В разделе языка доступны:

- SDK, версия после явной проверки, путь и источник выбора;
- подготовка недостающего через тот же установленный native frontend;
- выбор существующей версии или своего пути через прежний SDK selector;
- явное применение выбора SDK с восстановлением проекта;
- состояние LSP, форматтеров, debug/test tools, штатный Mason и tools.json;
- повторная проверка, настройки предложений и общие логи подготовки.

Подготовка выполняется в штатной панели Tasks/terminal: можно продолжать
редактирование, а в выводе отвечать на вопросы native установщика. В одном
сеансе работает одна такая задача; повторный запуск открывает её вывод.
После ошибки или отмены можно повторить. SDK и его установщик могут уже
остаться в системе после отмены следующих шагов: выбранные команды показываются
до подтверждения. Result «готово» появляется только после строгой проверки.

SDK ставятся обычными поставщиками ОС/экосистем. Новая Ubuntu получает Go из
официальной поставки go.dev в `~/sdk/go<version>` и Rust через rustup с
rustfmt/rust-src в обычные Cargo/Rustup homes. Готовые версии сохраняются.
Недостающие компоненты существующего Rustup SDK предлагаются отдельно, без
обновления компилятора. Bash/SQL используют готовые инструменты, SQL общего
языкового SDK не требует. Cargo-nextest остаётся общей утилитой в Cargo home.

Новый SDK не переключает процессы уже открытого редактора. Выбор и применение
выполняются явно; активные debug/tests/tasks/terminal блокируют restart.
Подготовка не переустанавливает работающий kit. После успеха обновляется только
fallback список SDK paths; исходное окружение и project/user choices имеют
приоритет. [Версии, пути и применение SDK](SDK_SELECTION.md).

## Предложения и области настроек

В меню языка открой «Предложения»:

- «Позже» действует только в текущем сеансе;
- «Не предлагать для проекта» сохраняет настройку проекта;
- «Не предлагать вообще» задаёт пользовательскую настройку;
- «Спрашивать», наследование и сброс возвращают предложения;
- можно открыть JSON нужной области, включая исправление ошибочного JSON.

Пользовательский файл — `languages.json` в `stdpath('config')` приложения fride;
проектный — `.fride/languages.json`. Project key имеет приоритет над user key.
Отсутствующий key означает наследование, общий default — `ask`.

```json
{
  "version": 1,
  "prompts": { "rust": "manual", "go": "ask" }
}
```

Допустимые языки: `go`, `rust`, `python`, `node`, `bash`, `sql`;
значения: `ask` и `manual`. Другие поля файла сохраняются при изменении меню.
Выбор SDK по-прежнему хранится в sdk.json/tools.json, отдельно от prompt policy.
Ошибка настройки показывается, исходный файл не заменяется пустым default.

## Команды подготовки и диагностики

Обычная установка не требует заранее установленных SDK. Для automation,
которая явно готовит весь выбранный набор сразу, есть `--prepare-languages`
у install.sh и `-PrepareLanguages` у install.ps1. `--check-sdks` и direct setup
сохраняют строгую диагностику выбранного набора. Preview SDK не запускает.

В установленном kit native frontend поддерживает отдельную команду:

```text
bin/fride-setup --prepare-language go --installed-kit /path/to/fride --result /new/result.json --log-dir /path/to/logs
```

На Windows executable — `bin/fride-setup.exe`. Current directory задаёт проект.
Для source checkout без установленного frontend встроенная подготовка сообщает
причину; доступны ручной SDK selector и Mason. Cargo автоматически не запускается.

Общие события: `:ForgeLogs events:Languages`; stdout/stderr — вывод задачи и
каталог `stdpath('state')/language-setup`. Подготовка выбранного языка использует
его project/user SDK/tool paths. Обычная установка kit использует user scope.

Разделение явных действий и User/Workspace scopes опирается на подходы
[VS Code settings](https://code.visualstudio.com/docs/configure/settings),
[Python environments](https://code.visualstudio.com/docs/python/environments)
и [Go tools](https://github.com/golang/vscode-go/blob/master/docs/tools.md).
Общее меню языков — интерфейс fride поверх существующих providers.

## Проверка раздела из репозитория

Стенд требует подготовленные Neovim/editor-deps. Native integration дополнительно
использует явно подготовленный frontend; source UI без него сообщает один SKIP
с причиной. В acceptance этот case обязателен и должен пройти. SDK/CLI не
собираются и не скачиваются во время E2E. Developer preparation (нужен Rust SDK):

```text
python -B scripts/build-installer-ui.py --work .tests/installer-ui --output .tests/installer-ui-candidate
```

Для первой подготовки crates добавь `--download`; последующие сборки offline.
На Windows:

```powershell
$env:FORGE_INSTALL_UI_BINARY="$PWD/.tests/installer-ui-candidate/fride-setup.exe"
powershell -NoProfile -File scripts/test.ps1 e2e -Files tests/e2e/language-environments.test.lua
```

На Linux/macOS используй `python3` при сборке, затем:

```bash
FORGE_INSTALL_UI_BINARY="$PWD/.tests/installer-ui-candidate/fride-setup" bash scripts/test.sh e2e --file tests/e2e/language-environments.test.lua
```
