# Python: venv, язык, pytest и debug

Одна конфигурация для Windows, macOS и Ubuntu. Целевые машины предоставляют
Python; сборка не устанавливает SDK при открытии файла. Окружение проекта
создаётся явно, обычно рядом с pyproject.toml:

```sh
python -m venv .venv
# Windows:
.venv/Scripts/python.exe -m pip install pytest debugpy ruff
# macOS/Ubuntu:
.venv/bin/python -m pip install pytest debugpy ruff
```

Pyright и Ruff должны быть доступны редактору: например, явно выполнить
`:MasonInstall pyright ruff` (для Pyright нужен Node.js). Debugpy можно установить
в project venv, как выше, либо явно через Mason. После обновления сборки
выполнить `:Lazy build nvim-dap` и перезапустить редактор: это подготовит
проверяемый по pin/SHA патч classification adapter shutdown. Обычный startup
не переписывает plugin source и не устанавливает инструменты.

## Выбор Python

Для DAP и исходной настройки Pyright используется общий selector:

1. Валидный `vim.g.forge_python_path` или `FORGE_PYTHON_PATH`.
2. Активный VIRTUAL_ENV, затем CONDA_PREFIX.
3. `.venv`, `venv`, `.env`, `env` в корнях проекта.
4. Доступный python3/python в PATH.

У DAP сохранены прежние корни текущего файла, cwd и LSP. Pyright использует
свой project root и получает python.pythonPath до initialize. Поэтому обычный
неактивированный .venv с зависимостями работает без extraPaths в конфиге.
Явный settings.python.pythonPath сохраняется. Его можно поменять штатной
командой `:LspPyrightSetPythonPath <полный путь к python>`; при пробелах это
один целый аргумент команды, без shell quotes. Эта команда настраивает LSP;
общий override для LSP и DAP — forge_python_path/FORGE_PYTHON_PATH.

Neotest сохраняет native resolver окружений: plain project venv проверен,
Poetry/Pipenv/Conda managers отдельно не объявлены проверенными. Активация shell
не требуется для plain .venv. В Windows executable находится в Scripts,
в POSIX venv — в bin; эти различия ограничены границей пути.

## Обычная работа

| Действие | Команда |
|---|---|
| Определение / ссылки / rename | `gd` / `gr` / `F2` |
| Диагностика строки | `gl` |
| Формат и organize imports | `Space l f`, `Shift Alt f`, `:Format`; Ruff также после save |
| Debug / breakpoint / eval | `F5` / `F9` / `Space d e` |
| Python paths для диагностики | `:DapPythonInfo` |
| Tests / Test Output | `Space w t` / `Space w r` |
| Nearest / file / debug nearest | `Space T t` / `Space T f` / `Space T d` |
| Locals / Debug Output / код | `Space w d` / `Space w c` / `F7` или `Space w 0` |

F5 без launch.json предлагает Current Python file и вариант с аргументами.
Для проектного запуска используется существующий `.vscode/launch.json`, тип
python/debugpy, program/cwd/args. Stdout/stderr остаются в Debug Output после
завершения. Для тестов нужны pytest и debugpy в выбранной среде. Успешный
pytest debug не должен перекрываться ложным adapter exit WARN; настоящий
отказ adapter до client close остаётся видимым.

Готовому Python adapter отводится30 секунд на initialize+launch до предупреждения
об отсутствии ответа. Холодный запуск в смешанном проекте занимал6,7 секунды;
прежний native budget4s вызывал Press ENTER до завершения handshake.
Использована штатная настройка nvim-dap, одинаковая на ОС. Настоящий exit
адаптера сообщается сразу, независимо от этого бюджета (IDE-122/IDE-DAP-8, §210).
Windows mixed+Python8 проверены; финальный Ubuntu budget и Mac ещё открыты.

Отдельные adapter overrides `forge_debugpy_adapter`/FORGE_DEBUGPY_ADAPTER и
`forge_debugpy_python`/FORGE_DEBUGPY_PYTHON задавайте до загрузки DAP конфигурации
или перед запуском редактора. Выбор backend и Python отлаживаемой программы —
две разные настройки; обычному project venv эти overrides не нужны.

## Подготовка постоянных E2E

Сначала общие plugins и Node SDK по [инструкции E2E](../tests/e2e/README.md).
Затем (Windows python, macOS/Ubuntu python3; путь к выбранному Neovim):

```sh
python -B tests/e2e/prepare_python.py --download --nvim <nvim>
python -B tests/e2e/prepare_python.py --nvim <nvim>
<nvim> -l tests/e2e/python-language.test.lua
```

Host Python >=3.10 записывается в manifest; на этом Windows проверяется 3.14.0.
Зафиксированы Pyright 1.1.414, pytest 9.2.0, debugpy 1.8.22, Ruff 0.17.3,
полные npm/wheel locks и SHA. Подготовка wheel/parser/venv/cache явная,
Windows output на диске checkout. SDK Python автоматически не скачивается.
Private project venv создаётся offline из проверенного wheelhouse; отдельный
локальный package собирается в wheel, устанавливается pip и реально выполняется.
`.venv`/cache не дублируются в snapshots; source/locks/manifest/logs сохраняются.
`FORGE_PYTHON_CASE` ограничивает запуск по подстроке имени случая.

Первичные источники настроек и инструментов:
[Pyright settings](https://github.com/microsoft/pyright/blob/main/docs/settings.md),
[debugpy](https://github.com/microsoft/debugpy),
[pytest](https://docs.pytest.org/en/stable/getting-started.html),
[neotest-python](https://github.com/nvim-neotest/neotest-python).
