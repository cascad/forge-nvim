# Proposal

## Why

В `openspec/specs/` 128 требований с ID, но проверить, что код им соответствует, можно только вручную. Сверка базовой линии нашла 71 расхождение, и все они найдены чтением кода и пробами из временного каталога. Сам WezTerm ошибки прячет:

- сломанный конфиг даёт код 0 и встроенные привязки (`show-keys`), так что по коду возврата ничего не видно;
- при повторе пары (клавиша, модификаторы) побеждает последняя запись, без предупреждения (WT-KEYS-8);
- вывод `show-keys --lua` от запуска к запуску разный: регистр букв `phys:` случаен.

Прототипы, которые это доказали, — поддельный модуль `wezterm` для `nvim -l`, обёртка загрузки, нормализованный снимок, извлечение клавиш nvim — лежат только во временном scratchpad (`C:\Users\cascad\AppData\Local\Temp\claude\F--repo-forge-nvim\7850c143-3e84-4f28-adb8-e12ee169bda2\scratchpad\vl\`, `harness.lua`, `dupcheck.lua`). Соседние changes уже планируют свои куски: `tests/wezterm/fake_wezterm.lua` и `clipboard.test.lua` (`fix-copy-clobbers-clipboard`), `tests/wezterm-keys.scenarios.sh` (`change-search-enter-accept`, `fix-windows-mode-modality`), ручные чек-листы `tests/manual/` (`review-baseline`). Без общего раннера и трассировки это станет несколькими параллельными конструкциями, и связь «требование ↔ проверка» останется в прозе. Слой нужен сейчас: до исправлений поведения и до `restructure-wezterm-config`, который без снимков нечем страховать.

## What Changes

Поведение WezTerm, установщиков и nvim_forge не меняется. Добавляется слой проверок, связывающий ID требований с кодом.

- **Одна команда** `nvim -l tests/run.lua [набор…] [--id ID] [--update-golden] [--strict]`. Каждый файл проверок идёт отдельным процессом с таймаутом. Протокол строк один на всех: `ok` / `FAIL` / `SKIP`, ID требования в имени проверки, итог по коду возврата. Раннер печатает статус каждого ID: PASS / FAIL / SKIP / MANUAL / UNCOVERED. Отчёт с происхождением (коммит, ОС, версии nvim и WezTerm) пишется в `.tests/report.json`.
- **Поддельный модуль `wezterm`.** Загружает `wezterm.lua` для троек windows, macos и linux без GUI, диска и сети: окружение, файлы и встроенные таблицы режимов подставляются. Встроенные таблицы берутся из фикстуры, снятой с настоящего бинарника.
- **Проверки по ID для девяти capability `wezterm-*`.** Файлы `tests/wezterm/<capability>.test.lua`, имена проверок начинаются с ID. Это характеризация базовой линии: код как есть, включая известные баги (фаза 1).
- **Проверка повторов (клавиша, модификаторы)** в `config.keys` и в каждой таблице режима на каждой платформе (WT-KEYS-8). Повторы с тем же действием в copy_mode разрешены.
- **Межслойная проверка WezTerm ↔ nvim_forge** (WT-KEYS-4, WT-KEYS-6, WT-KEYS-7). Сочетания, которые перехватывает WezTerm, сверяются с привязками nvim_forge: `keymaps.lua` в headless nvim без плагинов плюс статически прочитанные `keys` из спек lazy.nvim. Пересечение должно совпасть с исключениями WT-KEYS-7.
- **Проверка загрузки настоящим бинарником** (WT-LOAD-11): `wezterm --config-file … ls-fonts`, потому что `show-keys` ошибок не показывает. Плюс обёртка с настоящим кодом возврата для всех трёх троек.
- **Нормализованные снимки** `show-keys --lua` по ОС и снимок всей конфигурации из подделки. Снимки ловят любое изменение и служат страховкой для `restructure-wezterm-config`. Осознанное изменение принимается через `--update-golden`.
- **`tests/install-macos.scenarios.sh` в общем прогоне.** На Windows — через WSL, на macOS — под `/bin/bash` 3.2. Если среды нет, набор получает SKIP, а не PASS. Сам скрипт не меняется.
- **Трассировка** `tests/trace.test.lua` падает на висячих ссылках:
  - ID в тестах, в ручных чек-листах, в тегах `-- spec:` в `wezterm.lua` и в строках `Спека:` FIXLOG, которых нет в спеках;
  - пути `tests/…` в строках `Проверка:`, которых нет на диске;
  - незарегистрированные shell-наборы.
- **Ручные проверки.** Чек-листы `tests/manual/*.md` заводит `review-baseline`, этот change только читает их. Требование со строкой `Проверка: вручную (…)` или с пунктом в чек-листе получает статус MANUAL с последней отметкой и никогда не засчитывается как PASS.
- **Необязательный хук** `.githooks/pre-commit`. Включается один раз на машине: `git config core.hooksPath .githooks`.
- **Документация:** раздел «Проверки» в `CLAUDE.md` и `tests/README.md` (протокол, как добавить проверку).

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Требования не меняются, delta-спек нет, в `.openspec.yaml` стоит `skip_specs: true`.

## Impact

- **Новые файлы:**
  - `tests/run.lua`, `tests/README.md`, `tests/lib/*.lua`, `tests/trace.test.lua`;
  - `tests/wezterm/`: подделка, обёртка, фикстура, эталонные снимки, `VERSION`, файлы проверок;
  - `.githooks/pre-commit`.
- **Правятся:** `.gitignore` (строка `.tests/`) и `CLAUDE.md` (раздел «Проверки»).
- **Не меняются:** `wezterm.lua`, установщики, `nvim_forge/`, `openspec/specs/**`, `tests/install-macos.scenarios.sh`, FIXLOG (поведение не меняется).
- **Зависимости:** новых нет. Раннер — Neovim 0.12, он есть на обеих машинах. WezTerm 20240203, WSL и bash 3.2 нужны только своим наборам; без них набор получает SKIP.
- **Соседние changes:**
  - `fix-copy-clobbers-clipboard` — одна подделка `tests/wezterm/fake_wezterm.lua` и один `clipboard.test.lua`. Кто применяется первым, тот и создаёт, второй дополняет.
  - `change-search-enter-accept`, `fix-windows-mode-modality` — `tests/wezterm-keys.scenarios.sh`, если он появится, регистрируется в раннере.
  - `review-baseline` — владеет ручными чек-листами, а отчёт раннера (UNCOVERED, MANUAL) служит ему входом.
  - `restructure-wezterm-config` — зависит от этого change.
  - Changes, меняющие поведение, правят проверки в том же коммите, что и код (CLAUDE.md, правило 5).
