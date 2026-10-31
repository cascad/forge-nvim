# macOS: задержки shell и повторная загрузка Go

Связано: [план, этап 1](IDE_ROADMAP.md#этап-1-быстрый-и-предсказуемый-запуск),
[IDE-001](../PROBLEMS.md#ide-001--macos-медленный-shell-и-повторная-загрузка-go).
Статус: пассивный сборщик и его проверки готовы; на Mac ещё не выполнено.

## Начать с одной команды

Из **каталога, в котором возникает задержка**, вызвать скрипт из чекаута
(подставить реальный абсолютный путь к репозиторию на Mac):

```sh
python3 /путь/к/forge-nvim/nvim_forge/scripts/diagnose-shell.py
```

Не переходить в чекаут только ради запуска: `cwd` нужен для поиска именно
проблемных `go.mod/go.work`. Если Python 3 отсутствует, использовать ручные
шаги ниже; инструмент ничего не устанавливает.

Сборщик читает файлы и выбранные переменные, **не запускает Go, zsh, prompt,
source или другие команды**. Ничего не меняет и не записывает. В отчёте:

- `GO_CALL` — строка с `go env/version/install`;
- `PROMPT` — кандидаты prompt/hooks (в том числе Starship);
- `SOURCE` / `SOURCE_DYNAMIC` — статически найденный файл / ссылка,
  которую нельзя разрешить без исполнения shell;
- `GOENV_FILE` — сохранённые настройки `GOTOOLCHAIN/GOSUMDB`, отдельно от env;
- `PROJECT` — ближайшие требования `go`/`toolchain` проекта и workspace.

Исходные строки профилей и полный environment не выводятся. Пути и выбранные
значения Go в отчёте видны: перед пересылкой их можно проверить и сократить.
Обход ограничен 40 файлами и 256 KiB на файл. Это эвристика: найденная строка
может находиться в неисполняемой функции; неизвестные/dynamic source, ZDOTDIR,
который задаётся внутри профиля и не экспортируется, и системные профили могут
потребовать ручной проверки. Причина подтверждается локальным trace и замером.

У Starship Go-модуль действительно вызывает `go version`:
[исходник модуля](https://github.com/starship/starship/blob/master/src/modules/golang.rs).
Это кандидат для проверки, **не подтверждённая причина на данном Mac**.
Если trace укажет на Starship, проверить модуль отдельно (`starship timings`,
`starship explain`) и затем выбрать точечную настройку prompt. Не отключать
проверку checksum и не менять глобальный `GOTOOLCHAIN`, чтобы скрыть симптом.

## Что известно

Пользователь видит при работе в WezTerm:

```text
go: downloading go1.26.0 (darwin/arm64)
go: download go1.26.0: golang.org/toolchain@v0.0.1-go1.26.0.darwin-arm64: verifying module: checksum database disabled by GOSUMDB=off
```

Это автоподбор/загрузка другой версии Go, а не доказательство запуска
`brew install`. При `GOSUMDB=off` загрузка toolchain не проходит проверку:
[официальная документация Go](https://go.dev/doc/toolchain#downloading-toolchains).
Повторный вызов может повторять неудачную попытку. Владелец подтвердил:
сообщение и задержка возникают **до запуска nvim**, shell — **zsh**.
Причину выбора 1.26.0 и команду, вызывающую Go, ещё нужно установить на Mac.

В репозитории WezTerm не запускает установку Go; `nvim_forge.sh` только
запускает nvim. В Neovim есть отдельные кандидаты: фоновый `go version`
для статуслайна, `go env`/проверки Delve в DAP, автоустановка Mason.
Они не объясняют задержку до shell-приглашения без запуска Neovim.

## 1. Проверить фактически запущенную сборку

В shell Mac (из каталога чекаута):

```sh
printf 'shell=%s\n' "$SHELL"
printf 'ZDOTDIR=%s\n' "${ZDOTDIR:-$HOME}"
git rev-parse --short HEAD
git status --short
ls -ld "$HOME/.config/nvim" "$HOME/.config/wezterm/wezterm.lua"
```

В работающем Neovim:

```vim
:lua print(vim.fn.stdpath('config'))
:lua print(vim.fn.stdpath('data'))
:lua print(vim.env.NVIM_APPNAME or '(обычный nvim)')
```

## 2. Разделить терминал и shell

Записать, когда появляется сообщение и задержка: новая вкладка без nvim;
пустой Enter; `clear`; переход в Go-проект; запуск nvim; запуск DAP.
Повторить вне Go-проекта и внутри него. У каждого шага отметить примерное
время; не смешивать задержку исполнения `clear` с перерисовкой prompt после него.

Для zsh запустить временный shell без обычных пользовательских профилей:

```sh
/bin/zsh -f
```

Внутри проверить Enter, `command clear`, переход между каталогами. `exit`
вернёт прежний shell. Окружение наследуется, а системный `/etc/zshenv` всё
ещё может читаться: этот опыт проверяет прежде всего пользовательские hooks.
Если задержка исчезла, проверять prompt/профили прежде Neovim.

## 3. Посмотреть Go без автоматического скачивания

В обычном shell, где возникает проблема:

```sh
type -a go clear
printf 'GOTOOLCHAIN=%s\nGOSUMDB=%s\nGOENV=%s\n' \
  "${GOTOOLCHAIN:-<не задано>}" "${GOSUMDB:-<не задано>}" "${GOENV:-<не задано>}"
GOTOOLCHAIN=local go version
GOTOOLCHAIN=local go env GOTOOLCHAIN GOSUMDB GOENV GOMOD GOWORK GOPATH GOROOT
```

`GOTOOLCHAIN=local` здесь действует только для конкретной команды; глобальные
настройки не меняются. Вывод `go env GOTOOLCHAIN` с этим префиксом ожидаемо
покажет `local`, а не исходную сохранённую настройку. Исходную переменную
показывает `printf`, сохранённую — следующий шаг. Если `go` оказался alias/
функцией/обёрткой, отдельно проверить её определение.

```sh
goenv_file=$(GOTOOLCHAIN=local go env GOENV)
if [ -f "$goenv_file" ]; then
  rg -n '^(GOTOOLCHAIN|GOSUMDB)=' "$goenv_file"
fi
```

В найденных `go.mod` и `go.work` посмотреть только директивы `go`/`toolchain`:

```sh
rg -n '^(go|toolchain)[[:space:]]' /путь/из/предыдущего/вывода/go.mod
```

Если есть `go.work`, повторить для него. Не менять требование версии проекта
или `GOSUMDB`, пока не найден инициатор и не выяснены ограничения окружения.

## 4. Найти вызывающий hook (zsh)

В обычной сессии zsh:

```sh
typeset -p precmd_functions preexec_functions chpwd_functions 2>/dev/null
zd=${ZDOTDIR:-$HOME}
rg -n 'go (env|version|install)|GOTOOLCHAIN|GOSUMDB|source |shellenv|precmd|preexec|chpwd|PROMPT|starship|p10k|mise|asdf|direnv' \
  "$HOME/.zshenv" "$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.zlogin" \
  "$zd/.zshenv" "$zd/.zprofile" "$zd/.zshrc" "$zd/.zlogin" 2>/dev/null
```

Отсутствующий файл или отсутствие совпадений нормально. Просмотреть также
скрипты, которые подключаются найденными строками `source`. Не выполнять
повторный `source` вслепую: он может дублировать hooks.

Если статического поиска недостаточно, в текущей **zsh**-сессии включить
трассировку в локальный файл, выполнить пустой Enter и `clear`, затем выключить:

```sh
trace_file=$(mktemp "${TMPDIR:-/tmp}/forge-shell-trace.XXXXXX")
forge_saved_ps4=$PS4
exec {forge_trace_fd}>&2
exec 2>"$trace_file"
PS4='+%N:%i> '
set -x
```

Теперь пустой Enter, затем `clear`. После этого:

```sh
set +x
PS4=$forge_saved_ps4
exec 2>&$forge_trace_fd
exec {forge_trace_fd}>&-
printf 'trace=%s\n' "$trace_file"
rg -n -C 3 'go1\.26|go (env|version|install)|GOTOOLCHAIN|GOSUMDB|source ' "$trace_file"
```

Записывать в IDE-001 только проверенные фрагменты с именем функции/файла,
номером строки и командой Go. Полный trace может содержать значения окружения
и команды пользователя; перед передачей фрагментов убрать секреты.
Не держать трассировку включённой во время обычной работы.

## 5. Что считать доказательством

- Версия/путь конфига на Mac и используемый shell установлены.
- Видно, возникает ли задержка без nvim и исчезает ли в `zsh -f`.
- Найдена команда, которая просит Go 1.26.0, и её вызывающий hook/файл.
- Установлено, откуда берутся `GOTOOLCHAIN` и `GOSUMDB=off`.
- После точечного исправления повторены вкладка, Enter, clear, переход
  в Go-проект, запуск nvim; записаны время до/после и отсутствие загрузок.

Если проблема остаётся только внутри nvim, отдельно исследовать
`nvim_forge/lua/forge/go.lua`, `plugins/dap.lua` и `plugins/lsp.lua`.
