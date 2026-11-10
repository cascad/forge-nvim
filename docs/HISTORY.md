# HISTORY — единая хронология проекта

Обновлено: 2026-11-10. История разработки терминальной IDE от Helix и раннего
Neovim до нынешнего nvim_forge. Здесь одна последовательность и ссылки на
подробности; новые исправления описываются в FIXLOG, затем добавляются сюда.

[Формат новой записи](history/ENTRY_TEMPLATE.md) · [Архив и правила датировки](history/README.md) · [Manifest источников и SHA256](history/sources.json).

## Ранние этапы без точной даты

Порядок Helix → Neovim следует из самих описаний перехода. Точные даты
не восстанавливались по времени файлов. Четыре Neovim-документа совпадают
с резервным снимком, помеченным 2026-05-11; это не точная датировка их эпизодов.
Слова «финальный» и команды в архиве относятся к тогдашнему состоянию.

| Этап / статус источника | Материал |
|---|---|
| Решения по Helix и авторская последовательность шагов | [Источник](history/legacy/helix-rationale.md) — `historical-decisions` |
| Постмортем Helix и причины перехода на Neovim | [Источник](history/legacy/helix-postmortem.md) — `postmortem` |
| Первоначальный план Neovim и выбор стека | [Источник](history/legacy/neovim-initial-plan.md) — `historical-plan` |
| Причины фризов Rust-навигации и сделанный фикс | [Источник](history/legacy/rust-navigation-performance.md) — `historical-fix` |
| Ранний журнал DAP: launch.json, output, фокус и неудачные попытки | [Источник](history/legacy/neovim-debug-setup.md) — `debug-journey` |
| Завершённая заметка о recent projects picker | [Источник](history/legacy/recent-projects-notes.md) — `historical-feature` |

## 2026-05-11 — чистая установка

[Запись runtime-backup](history/legacy/2026-05-11-clean-install.txt):
сохранён прежний runtime, установка из forge-nvim, повтор parser gitcommit и
заявленные в источнике smoke-проверки. Дата взята из поля stamp; результаты
здесь не повторно проверялись и не считаются сегодняшним e2e.

## 2026-05-24 — фиксация подробного DAP-разбора в git

[DEBUG_JOURNEY](../nvim_forge/DEBUG_JOURNEY.md) — отдельный последующий
разбор Rust/codelldb, первого println, терминального pool и window handle.
Дата — дата git-коммита `4fb4e5c`, в котором зафиксирован документ;
это не установленная дата каждого описанного исправления.


## 2026-05-30

| Запись | История проблемы и решения |
|---|---|
| §1 | [Курсор упирается в конце файла (нет scroll-beyond-last-line)](../nvim_forge/FIXLOG.md#1-курсор-упирается-в-конце-файла-нет-scroll-beyond-last-line) |
| §2 | [Курсор строго по центру → резкий прыжок при выделении мышью](../nvim_forge/FIXLOG.md#2-курсор-строго-по-центру--резкий-прыжок-при-выделении-мышью) |
| §3 | [Нет подсветки парной открывающей скобки](../nvim_forge/FIXLOG.md#3-нет-подсветки-парной-открывающей-скобки) |
| §4 | [Как заполнить структуру дефолтами по всем полям (fill / autofill)](../nvim_forge/FIXLOG.md#4-как-заполнить-структуру-дефолтами-по-всем-полям-fill--autofill) |
| §5 | [Как принять предложение LSP/clippy (например «could lift into loop condition»)](../nvim_forge/FIXLOG.md#5-как-принять-предложение-lspclippy-например-could-lift-into-loop-condition) |
| §6 | [Дебаг: остановка на fatalpanic — layout не висит, &lt;leader&gt;pd не открывает, после F5 call stack пустой](../nvim_forge/FIXLOG.md#6-дебаг-остановка-на-fatalpanic--layout-не-висит-leaderpd-не-открывает-после-f5-call-stack-пустой) |
| §7 | [cmd+option+l на автоформатирование](../nvim_forge/FIXLOG.md#7-cmdoptionl-на-автоформатирование) |
| §8 | [(constatation) Подсветка vim-подсказки на v при visual-выделении](../nvim_forge/FIXLOG.md#8-constatation-подсветка-vim-подсказки-на-v-при-visual-выделении) |
| §10 | [Длинные строки Go не переносятся автоформаттером](../nvim_forge/FIXLOG.md#10-длинные-строки-go-не-переносятся-автоформаттером) |
| §9 | [Failed to run config for nvim-lspconfig — Invalid buffer id](../nvim_forge/FIXLOG.md#9-failed-to-run-config-for-nvim-lspconfig--invalid-buffer-id) |
| A | [A. Быстрый toggle левой/нижней панели одной клавишей](../nvim_forge/FIXLOG.md#a-быстрый-toggle-левойнижней-панели-одной-клавишей) |
| B | [B. &lt;Tab&gt; пропускал часть открытых буферов](../nvim_forge/FIXLOG.md#b-tab-пропускал-часть-открытых-буферов) |
| C | [C. Переключение между DAP-окнами на паузе без слома сессии](../nvim_forge/FIXLOG.md#c-переключение-между-dap-окнами-на-паузе-без-слома-сессии) |
| D | [D. format-on-save не работал для Go/Python/Lua](../nvim_forge/FIXLOG.md#d-format-on-save-не-работал-для-gopythonlua) |
| E | [E. :checkhealth forge — агрегированный статус](../nvim_forge/FIXLOG.md#e-checkhealth-forge--агрегированный-статус) |

## 2026-05-31

| Запись | История проблемы и решения |
|---|---|
| Без номера | [WezTerm: шелл/диск, дополнение путей, шрифт, Ctrl+C/V](../nvim_forge/FIXLOG.md#wezterm-шеллдиск-дополнение-путей-шрифт-ctrlcv) |
| Без номера | [Старт проекта через Alpha: пустой \[No Name\] вместо дерева](../nvim_forge/FIXLOG.md#старт-проекта-через-alpha-пустой-no-name-вместо-дерева) |
| Без номера | [WezTerm: окно не перетаскивается](../nvim_forge/FIXLOG.md#wezterm-окно-не-перетаскивается) |
| Без номера | [Автопары не подставляли скобки в файле с ошибкой парсинга](../nvim_forge/FIXLOG.md#автопары-не-подставляли-скобки-в-файле-с-ошибкой-парсинга) |
| Без номера | [Не все ошибки подсвечиваются в "сломанном" коде (undeclared / no-field)](../nvim_forge/FIXLOG.md#не-все-ошибки-подсвечиваются-в-сломанном-коде-undeclared--no-field) |

## 2026-06-14

| Запись | История проблемы и решения |
|---|---|
| §11 | [Go: нет автоимпорта недостающего пакета при наборе strings.](../nvim_forge/FIXLOG.md#11-go-нет-автоимпорта-недостающего-пакета-при-наборе-strings) |
| §12 | [Фриз при форматировании / генерации текста ошибки](../nvim_forge/FIXLOG.md#12-фриз-при-форматировании--генерации-текста-ошибки) |
| §13 | [Ошибки не подсвечены, пока курсор не на строке](../nvim_forge/FIXLOG.md#13-ошибки-не-подсвечены-пока-курсор-не-на-строке) |
| §14 | [Поиск не подсвечивает все совпадения заметно](../nvim_forge/FIXLOG.md#14-поиск-не-подсвечивает-все-совпадения-заметно) |
| §15 | [colorcolumn (линейка длины) в md/txt и прочей прозе](../nvim_forge/FIXLOG.md#15-colorcolumn-линейка-длины-в-mdtxt-и-прочей-прозе) |
| §16 | [WezTerm: нет полосы прокрутки](../nvim_forge/FIXLOG.md#16-wezterm-нет-полосы-прокрутки) |
| §17 | [WezTerm: Ctrl+C/V не работают на русской раскладке](../nvim_forge/FIXLOG.md#17-wezterm-ctrlcv-не-работают-на-русской-раскладке) |
| §18 | [WezTerm: русский файл выводится кракозябрами](../nvim_forge/FIXLOG.md#18-wezterm-русский-файл-выводится-кракозябрами) |
| §19 | [(вопрос) Как wezterm-конфиг из репо синхронизируется с системой](../nvim_forge/FIXLOG.md#19-вопрос-как-wezterm-конфиг-из-репо-синхронизируется-с-системой) |
| §20 | [Подсветка всех совпадений ПРЯМО во время набора поиска](../nvim_forge/FIXLOG.md#20-подсветка-всех-совпадений-прямо-во-время-набора-поиска) |
| §21 | [Счётчик совпадений поиска (nvim-hlslens)](../nvim_forge/FIXLOG.md#21-счётчик-совпадений-поиска-nvim-hlslens) |
| §22 | [Обычный файл открывается в нижней/боковой панели и «прилипает» к ней](../nvim_forge/FIXLOG.md#22-обычный-файл-открывается-в-нижнейбоковой-панели-и-прилипает-к-ней) |
| §23 | [Единый контроллер панелей: маркировка + триггеры + toggle](../nvim_forge/FIXLOG.md#23-единый-контроллер-панелей-маркировка--триггеры--toggle) |
| §24 | [Подсветка ошибок терялась — ни подчёркивания, ни цвета (ревизия §13)](../nvim_forge/FIXLOG.md#24-подсветка-ошибок-терялась--ни-подчёркивания-ни-цвета-ревизия-13) |
| §25 | [Как закрывать info/popup-окна (ConformInfo и подобные)](../nvim_forge/FIXLOG.md#25-как-закрывать-infopopup-окна-conforminfo-и-подобные) |
| §26 | [Форматтер «падал» на нормальных файлах (lua/json/yaml/md)](../nvim_forge/FIXLOG.md#26-форматтер-падал-на-нормальных-файлах-luajsonyamlmd) |
| §27 | [Фризы при наборе кода / навигации (опять) → формат асинхронный](../nvim_forge/FIXLOG.md#27-фризы-при-наборе-кода--навигации-опять--формат-асинхронный) |

## 2026-06-22

| Запись | История проблемы и решения |
|---|---|
| §28 | [Слишком широкая колонка номеров строк](../nvim_forge/FIXLOG.md#28-слишком-широкая-колонка-номеров-строк) |
| §29 | [Плейсхолдеры сниппета неотличимы от написанного кода](../nvim_forge/FIXLOG.md#29-плейсхолдеры-сниппета-неотличимы-от-написанного-кода) |

## 2026-06-27

| Запись | История проблемы и решения |
|---|---|
| §30 | [Esc на сниппет-сигнатуре — свернуть до пустого вызова](../nvim_forge/FIXLOG.md#30-esc-на-сниппет-сигнатуре--свернуть-до-пустого-вызова) |
| §31 | [Ctrl+\[ — outdent (сдвиг строки влево)](../nvim_forge/FIXLOG.md#31-ctrl--outdent-сдвиг-строки-влево) |
| §32 | [wezterm: размер окна при старте + запоминание](../nvim_forge/FIXLOG.md#32-wezterm-размер-окна-при-старте--запоминание) |
| §33 | [Go: ошибка ++/-- видна «только при запуске»](../nvim_forge/FIXLOG.md#33-go-ошибка----видна-только-при-запуске) |
| §34 | [Форматирование «молча не форматирует»](../nvim_forge/FIXLOG.md#34-форматирование-молча-не-форматирует) |
| §35 | [Go: какая версия активна + переключение (как в VS Code)](../nvim_forge/FIXLOG.md#35-go-какая-версия-активна--переключение-как-в-vs-code) |
| §36 | [Линтер/диагностика «тихо ломается» + рестарт](../nvim_forge/FIXLOG.md#36-линтердиагностика-тихо-ломается--рестарт) |
| §37 | [DAP: нижняя панель не открывалась на F5 (Go), молча](../nvim_forge/FIXLOG.md#37-dap-нижняя-панель-не-открывалась-на-f5-go-молча) |

## 2026-07-12

| Запись | История проблемы и решения |
|---|---|
| §38 | [Диагностика раскрывалась сама под курсором (раздражало при наборе)](../nvim_forge/FIXLOG.md#38-диагностика-раскрывалась-сама-под-курсором-раздражало-при-наборе) |
| §39 | [На alpha (welcome/recent projects) лезли номера строк и линейка 100/120](../nvim_forge/FIXLOG.md#39-на-alpha-welcomerecent-projects-лезли-номера-строк-и-линейка-100120) |
| §40 | [«(7 hidden items)» в дереве открывался как файл](../nvim_forge/FIXLOG.md#40-7-hidden-items-в-дереве-открывался-как-файл) |

## 2026-08-01

| Запись | История проблемы и решения |
|---|---|
| Без номера | [WezTerm: leader → липкий модальный режим WINDOWS](../nvim_forge/FIXLOG.md#wezterm-leader--липкий-модальный-режим-windows) |

## 2026-09-27

| Запись | История проблемы и решения |
|---|---|
| §41 | [Windows/WezTerm: не набираются заглавные и запятая на русской раскладке](../nvim_forge/FIXLOG.md#41-windowswezterm-не-набираются-заглавные-и-запятая-на-русской-раскладке) |
| §42 | [macOS/WezTerm: Cmd+C «не копирует» выделение мышью в шелле](../nvim_forge/FIXLOG.md#42-macoswezterm-cmdc-не-копирует-выделение-мышью-в-шелле) |
| §43 | [macOS: всё ставится одним install-macos.sh, ничего не нужно помнить](../nvim_forge/FIXLOG.md#43-macos-всё-ставится-одним-install-macossh-ничего-не-нужно-помнить) |
| §44 | [OpenSpec: спека WezTerm и установщика macOS, сверка кода со спекой](../nvim_forge/FIXLOG.md#44-openspec-спека-wezterm-и-установщика-macos-сверка-кода-со-спекой) |
| §45 | [WezTerm: y в copy mode и гонка при копировании стирали буфер](../nvim_forge/FIXLOG.md#45-wezterm-y-в-copy-mode-и-гонка-при-копировании-стирали-буфер) |
| §46 | [WezTerm: Enter в search mode принимает шаблон](../nvim_forge/FIXLOG.md#46-wezterm-enter-в-search-mode-принимает-шаблон) |
| §47 | [WezTerm: режимы WINDOWS и RESIZE модальные](../nvim_forge/FIXLOG.md#47-wezterm-режимы-windows-и-resize-модальные) |
| §48 | [WezTerm: новые окна — как первое, шрифт нового окна и повторный сброс](../nvim_forge/FIXLOG.md#48-wezterm-новые-окна--как-первое-шрифт-нового-окна-и-повторный-сброс) |
| §49 | [nvim_forge: мёртвые привязки Ctrl+V удалены, вставку делает WezTerm](../nvim_forge/FIXLOG.md#49-nvim_forge-мёртвые-привязки-ctrlv-удалены-вставку-делает-wezterm) |
| §50 | [WezTerm: Super-сочетания шрифта только вне Windows](../nvim_forge/FIXLOG.md#50-wezterm-super-сочетания-шрифта-только-вне-windows) |
| §51 | [WezTerm: правый Alt на Windows — AltGr, Alt+Space и Alt+F4 — окну (решения владельца)](../nvim_forge/FIXLOG.md#51-wezterm-правый-alt-на-windows--altgr-altspace-и-altf4--окну-решения-владельца) |
| §52 | [WezTerm: PowerShell 7 из Store, шрифты без окна ошибки, бейдж не срезается](../nvim_forge/FIXLOG.md#52-wezterm-powershell-7-из-store-шрифты-без-окна-ошибки-бейдж-не-срезается) |
| §53 | [WezTerm + nvim_forge: сочетания nvim_forge на Windows через подмену клавиш](../nvim_forge/FIXLOG.md#53-wezterm--nvim_forge-сочетания-nvim_forge-на-windows-через-подмену-клавиш) |
| §54 | [macOS: установщик — шрифт, Rust, git без CLT, профили, LaunchAgent, подсказка, ~/.config/nvim симлинком](../nvim_forge/FIXLOG.md#54-macos-установщик--шрифт-rust-git-без-clt-профили-launchagent-подсказка-confignvim-симлинком) |
| §55 | [Linux: шаг WezTerm в install-linux.sh — те же дефекты, что §43 починил для macOS](../nvim_forge/FIXLOG.md#55-linux-шаг-wezterm-в-install-linuxsh--те-же-дефекты-что-43-починил-для-macos) |
| §56 | [docs/WEZTERM.md и комментарии wezterm.lua сверены с кодом и спеками](../nvim_forge/FIXLOG.md#56-docsweztermmd-и-комментарии-weztermlua-сверены-с-кодом-и-спеками) |

## 2026-10-31

| Запись | История проблемы и решения |
|---|---|
| §57 | [IDE-001: пассивный сбор сведений о задержках zsh/Go на Mac](../nvim_forge/FIXLOG.md#57-ide-001-пассивный-сбор-сведений-о-задержках-zshgo-на-mac) |
| §58 | [Общий e2e-контур: Windows native, Ubuntu Docker, Mac отдельно](../nvim_forge/FIXLOG.md#58-общий-e2e-контур-windows-native-ubuntu-docker-mac-отдельно) |
| §59 | [Единая история: импорт ранних материалов и обязательный вывод исправления](../nvim_forge/FIXLOG.md#59-единая-история-импорт-ранних-материалов-и-обязательный-вывод-исправления) |
| §60 | [OpenSpec: постоянное разрешение владельца на фиксированный CLI](../nvim_forge/FIXLOG.md#60-openspec-постоянное-разрешение-владельца-на-фиксированный-cli) |
| §61 | [Настоящий editor e2e: pinned плагины, RPC UI и готовность интерфейса](../nvim_forge/FIXLOG.md#61-настоящий-editor-e2e-pinned-плагины-rpc-ui-и-готовность-интерфейса) |
| §62 | [Старт редактора: скрытые загрузки Treesitter и Mason](../nvim_forge/FIXLOG.md#62-старт-редактора-скрытые-загрузки-treesitter-и-mason) |
| §63 | [Отсутствующий gopls: предупреждение только при работе с Go](../nvim_forge/FIXLOG.md#63-отсутствующий-gopls-предупреждение-только-при-работе-с-go) |
| §64 | [Реальный DAP E2E: Go и Delve в частном тестовом окружении](../nvim_forge/FIXLOG.md#64-реальный-dap-e2e-go-и-delve-в-частном-тестовом-окружении) |
| §65 | [Go DAP: невидимый REPL и потеря раннего вывода](../nvim_forge/FIXLOG.md#65-go-dap-невидимый-repl-и-потеря-раннего-вывода) |
| §66 | [Go panic: текст ошибки в Output без продолжения процесса](../nvim_forge/FIXLOG.md#66-go-panic-текст-ошибки-в-output-без-продолжения-процесса) |
| §67 | [Запросы разрешений после переключения Full access](../nvim_forge/FIXLOG.md#67-запросы-разрешений-после-переключения-full-access) |
| §68 | [Go test E2E: явная подготовка parser и runner](../nvim_forge/FIXLOG.md#68-go-test-e2e-явная-подготовка-parser-и-runner) |
| §69 | [Go neotest: nearest, пути с пробелами и фоновый discovery](../nvim_forge/FIXLOG.md#69-go-neotest-nearest-пути-с-пробелами-и-фоновый-discovery) |
| §70 | [DAP eval: No active session и закрытие временного окна](../nvim_forge/FIXLOG.md#70-dap-eval-no-active-session-и-закрытие-временного-окна) |
| §71 | [Snippet: ручной ввод отменяет нетронутые параметры](../nvim_forge/FIXLOG.md#71-snippet-ручной-ввод-отменяет-нетронутые-параметры) |
| §72 | [codelldb: проверка инструмента при запуске](../nvim_forge/FIXLOG.md#72-codelldb-проверка-инструмента-при-запуске) |
| §73 | [Windows Starship: Git timeout и подавление повторных WARN](../nvim_forge/FIXLOG.md#73-windows-starship-git-timeout-и-подавление-повторных-warn) |
| §74 | [Панели Debug: общий маршрут Space w](../nvim_forge/FIXLOG.md#74-панели-debug-общий-маршрут-space-w) |
| §75 | [Satellite: нулевая высота при закрытии debug-панелей](../nvim_forge/FIXLOG.md#75-satellite-нулевая-высота-при-закрытии-debug-панелей) |
| §76 | [Outline слева и общий маршрут панели](../nvim_forge/FIXLOG.md#76-outline-слева-и-общий-маршрут-панели) |
| §77 | [Neo-tree: повторное открытие и отложенные события](../nvim_forge/FIXLOG.md#77-neo-tree-повторное-открытие-и-отложенные-события) |
| §78 | [Дерево файлов: операции и общий маршрут](../nvim_forge/FIXLOG.md#78-дерево-файлов-операции-и-общий-маршрут) |
| §79 | [Move: полный путь в диалоге](../nvim_forge/FIXLOG.md#79-move-полный-путь-в-диалоге) |
| §80 | [Reveal: повторный navigate после rename](../nvim_forge/FIXLOG.md#80-reveal-повторный-navigate-после-rename) |
| §81 | [Neo-tree: выбранная строка после zoom](../nvim_forge/FIXLOG.md#81-neo-tree-выбранная-строка-после-zoom) |
| §82 | [Neo-tree: два владельца Esc](../nvim_forge/FIXLOG.md#82-neo-tree-два-владельца-esc) |

## 2026-11-01

| Запись | Описание |
|---|---|
| §83 | [Файловые вкладки: общая модель и reopen](../nvim_forge/FIXLOG.md#83-файловые-вкладки-общая-модель-и-reopen) |
| §84 | [Закрытие файла: решение до смены окон и autosave](../nvim_forge/FIXLOG.md#84-закрытие-файла-решение-до-смены-окон-и-autosave) |
| §85 | [Git-панель: общий маршрут и реальные сценарии](../nvim_forge/FIXLOG.md#85-git-панель-общий-маршрут-и-реальные-сценарии) |
| §86 | [Windows: hunk patch с относительным путём](../nvim_forge/FIXLOG.md#86-windows-hunk-patch-с-относительным-путём) |
| §87 | [Worktree: стабильный корень рабочей папки](../nvim_forge/FIXLOG.md#87-worktree-стабильный-корень-рабочей-папки) |
| §88 | [Файловый e2e: ожидание готовности дерева](../nvim_forge/FIXLOG.md#88-файловый-e2e-ожидание-готовности-дерева) |
| §89 | [Diffview: закрытие во время загрузки](../nvim_forge/FIXLOG.md#89-diffview-закрытие-во-время-загрузки) |
| §90 | [Тестовые runtime заполнили диск C:](../nvim_forge/FIXLOG.md#90-тестовые-runtime-заполнили-диск-c) |
| §91 | [Neogit: согласованный граф при быстром visit worktree](../nvim_forge/FIXLOG.md#91-neogit-согласованный-граф-при-быстром-visit-worktree) |
| §92 | [Windows terminal: ConPTY lifecycle и временный SDK](../nvim_forge/FIXLOG.md#92-windows-terminal-conpty-lifecycle-и-временный-sdk) |
| §93 | [CLI timeout: сохраняем доказательства](../nvim_forge/FIXLOG.md#93-cli-timeout-сохраняем-доказательства) |
| §94 | [ConPTY: регресс не должен менять плагины владельца](../nvim_forge/FIXLOG.md#94-conpty-регресс-не-должен-менять-плагины-владельца) |
| §95 | [Удалённый файл: буфер остаётся доступным](../nvim_forge/FIXLOG.md#95-удалённый-файл-буфер-остаётся-доступным) |
| §96 | [Neogit: удаление текущего worktree после смены cwd](../nvim_forge/FIXLOG.md#96-neogit-удаление-текущего-worktree-после-смены-cwd) |
| §97 | [Задержки Windows: перезапуск GPU не заменил рестарт ПК](../nvim_forge/FIXLOG.md#97-задержки-windows-перезапуск-gpu-не-заменил-рестарт-пк) |
| §98 | [Docker Windows: старый диск и выбор чистого окружения](../nvim_forge/FIXLOG.md#98-docker-windows-старый-диск-и-выбор-чистого-окружения) |

## 2026-11-02

| Запись | Описание |
|---|---|
| §99 | [Gitsigns: незавершённый diff и исчезнувший worktree](../nvim_forge/FIXLOG.md#99-gitsigns-незавершённый-diff-и-исчезнувший-worktree) |
| §100 | [Живой Git object read без cwd удаляемого worktree](../nvim_forge/FIXLOG.md#100-живой-git-object-read-без-cwd-удаляемого-worktree) |
| §101 | [ConPTY: сохраняем раскладки сессий и полный diff](../nvim_forge/FIXLOG.md#101-conpty-сохраняем-раскладки-сессий-и-полный-diff) |
| §102 | [Git: отказ push и повтор без потери коммитов](../nvim_forge/FIXLOG.md#102-git-отказ-push-и-повтор-без-потери-коммитов) |
| §103 | [Diffview: редактируемый результат merge и rebase](../nvim_forge/FIXLOG.md#103-diffview-редактируемый-результат-merge-и-rebase) |
| §104 | [Neogit: читаемый вывод без terminal title и OSC](../nvim_forge/FIXLOG.md#104-neogit-читаемый-вывод-без-terminal-title-и-osc) |
| §105 | [SDK E2E: отдельный deadline каждого сценария](../nvim_forge/FIXLOG.md#105-sdk-e2e-отдельный-deadline-каждого-сценария) |
| §106 | [Git E2E: готовность панели после checkout](../nvim_forge/FIXLOG.md#106-git-e2e-готовность-панели-после-checkout) |
| §107 | [Editor E2E: завершение child и первичная RPC ошибка](../nvim_forge/FIXLOG.md#107-editor-e2e-завершение-child-и-первичная-rpc-ошибка) |
| §108 | [Подсветка сверхдлинного слова без E339](../nvim_forge/FIXLOG.md#108-подсветка-сверхдлинного-слова-без-e339) |
| §109 | [Рабочие панели: общий Space w и сохранение поиска](../nvim_forge/FIXLOG.md#109-рабочие-панели-общий-space-w-и-сохранение-поиска) |

После §109 снят [первичный аудит шести языков](LANGUAGE_MATRIX.md): настроенные
инструменты отделены от доказанного E2E покрытия; определён следующий Go LSP/
format шаг. Это документация текущего кода, без изменения runtime и новых PASS.

## 2026-11-03

| Запись | Описание |
|---|---|
| §110 | [Go LSP: реальные сценарии и fallback форматирования](../nvim_forge/FIXLOG.md#110-go-lsp-реальные-сценарии-и-fallback-форматирования) |
| §111 | [Node: язык, задачи, debug и Jest](../nvim_forge/FIXLOG.md#111-node-язык-задачи-debug-и-jest) |

## 2026-11-09

Python реализован и проверен 2026-11-03; после возобновления работы 2026-11-09
исходники сверены с сохранёнными RED/GREEN, завершены история и коммит.

| Запись | Описание |
|---|---|
| §112 | [Python: project venv и реальный workflow](../nvim_forge/FIXLOG.md#112-python-project-venv-и-реальный-workflow) |
| §113 | [DAP: ожидаемый shutdown и настоящие ошибки adapter](../nvim_forge/FIXLOG.md#113-dap-ожидаемый-shutdown-и-настоящие-ошибки-adapter) |
| §114 | [Rust: Cargo workspace, язык и переносимый запуск тестов](../nvim_forge/FIXLOG.md#114-rust-cargo-workspace-язык-и-переносимый-запуск-тестов) |
| §115 | [Rust debug tests: результат сохраняет настоящий output](../nvim_forge/FIXLOG.md#115-rust-debug-tests-результат-сохраняет-настоящий-output) |
| §116 | [Bash: язык, native Tasks и Bats Tests](../nvim_forge/FIXLOG.md#116-bash-язык-native-tasks-и-bats-tests) |
| §117 | [Bash rename: URI aliases больше не стирают аргументы](../nvim_forge/FIXLOG.md#117-bash-rename-uri-aliases-больше-не-стирают-аргументы) |
| §118 | [Trace: project fixtures отделены от самостоятельных suites](../nvim_forge/FIXLOG.md#118-trace-project-fixtures-отделены-от-самостоятельных-suites) |
| §119 | [SQL: схема, запросы и общие Results](../nvim_forge/FIXLOG.md#119-sql-схема-запросы-и-общие-results) |
| §120 | [SQLS: первый символ rename и Unicode координаты](../nvim_forge/FIXLOG.md#120-sqls-первый-символ-rename-и-unicode-координаты) |
| §121 | [Autosave: публичные события вместо старых callbacks](../nvim_forge/FIXLOG.md#121-autosave-публичные-события-вместо-старых-callbacks) |
| §122 | [Sqruff: parse diagnostics через native CLI](../nvim_forge/FIXLOG.md#122-sqruff-parse-diagnostics-через-native-cli) |
| §123 | [SQLStop: штатный выход не становится crash](../nvim_forge/FIXLOG.md#123-sqlstop-штатный-выход-не-становится-crash) |
| §124 | [SQL probes: изоляция LSP log на F](../nvim_forge/FIXLOG.md#124-sql-probes-изоляция-lsp-log-на-f) |
| §125 | [SQL: повторяемый регресс и границы этапа](../nvim_forge/FIXLOG.md#125-sql-повторяемый-регресс-и-границы-этапа) |
| §126 | [SQLS: комментарий перед SELECT больше не теряет rows](../nvim_forge/FIXLOG.md#126-sqls-комментарий-перед-select-больше-не-теряет-rows) |
| §127 | [SQL SDK readiness: проверка без build scratch и compiler](../nvim_forge/FIXLOG.md#127-sql-sdk-readiness-проверка-без-build-scratch-и-compiler) |
| §128 | [SQL Results: выбранный workspace обновляет видимый вывод](../nvim_forge/FIXLOG.md#128-sql-results-выбранный-workspace-обновляет-видимый-вывод) |
| §129 | [SQL tests: native SQLLogicTest/SQLite SDK](../nvim_forge/FIXLOG.md#129-sql-tests-native-sqllogictestsqlite-sdk) |
| §130 | [SQLLogicTest: scripts в Tests и Test Output](../nvim_forge/FIXLOG.md#130-sqllogictest-scripts-в-tests-и-test-output) |
| §131 | [Run all: несколько adapters одного workspace](../nvim_forge/FIXLOG.md#131-run-all-несколько-adapters-одного-workspace) |
| §132 | [Neotest: native identity directory/file paths](../nvim_forge/FIXLOG.md#132-neotest-native-identity-directoryfile-paths) |
| §133 | [Node E2E: pending tree в диагностическом снимке](../nvim_forge/FIXLOG.md#133-node-e2e-pending-tree-в-диагностическом-снимке) |
| §134 | [Neotest: canonical adapter root без дубля pytest namespace](../nvim_forge/FIXLOG.md#134-neotest-canonical-adapter-root-без-дубля-pytest-namespace) |
| §135 | [SQL tests: общий регресс и открытая startup диагностика](../nvim_forge/FIXLOG.md#135-sql-tests-общий-регресс-и-открытая-startup-диагностика) |

| §136 | [E2E: завершение editor охватывает собственных потомков](../nvim_forge/FIXLOG.md#136-e2e-завершение-editor-охватывает-собственных-потомков) |
| §137 | [POSIX: editor jobs входят в собственный scope](../nvim_forge/FIXLOG.md#137-posix-editor-jobs-входят-в-собственный-scope) |
| §138 | [SQL E2E: перенос terminal не скрывает PASS](../nvim_forge/FIXLOG.md#138-sql-e2e-перенос-terminal-не-скрывает-pass) |
| §139 | [SQL E2E: crash notices по настоящему exit tuple](../nvim_forge/FIXLOG.md#139-sql-e2e-crash-notices-по-настоящему-exit-tuple) |
| §140 | [Docker: принадлежность хранилищ и заблокированный cleanup](../nvim_forge/FIXLOG.md#140-docker-принадлежность-хранилищ-и-заблокированный-cleanup) |

## 2026-11-10

| Запись | История проблемы и решения |
|---|---|
| §141 | [Повторный аудит и внешнее состояние хранилищ](../nvim_forge/FIXLOG.md#141-повторный-аудит-и-внешнее-состояние-хранилищ) |
| §142 | [SQL references: исходный RED и начальный resolver](../nvim_forge/FIXLOG.md#142-sql-references-исходный-red-и-начальный-resolver) |
| §143 | [SQL prototype отменён; обзор фич до рефакторинга](../nvim_forge/FIXLOG.md#143-sql-prototype-отменён-обзор-фич-до-рефакторинга) |
| §144 | [Review: upstream patches, частный UI и native fzf gap](../nvim_forge/FIXLOG.md#144-review-upstream-patches-частный-ui-и-native-fzf-gap) |
| §145 | [DAP и панели: карта ответственности перед рефакторингом](../nvim_forge/FIXLOG.md#145-dap-и-панели-карта-ответственности-перед-рефакторингом) |
| §146 | [Git/root review и пассивные Go процессы](../nvim_forge/FIXLOG.md#146-gitroot-review-и-пассивные-go-процессы) |

## Как читать и дополнять

- FIXLOG — фактические записи и границы проверок. Точный порядок внутри
  одной даты сохраняет порядок записей автора; существующие номера не меняются.
- Большой DAP-постмортем и ранние журналы — приложения с разбором попыток.
- Ранний план сохраняет статус плана. Его стек и хоткеи не задают текущий runtime.
- Новая запись: что было → причина → изменение → проверка/e2e → вывод → файлы.
  Добавляем ссылку здесь, уточнение старого вывода — новой записью со ссылкой на прежнюю.
- Для IDE-003/004 сначала прочитать старые эпизоды output/PTY/REPL, затем
  сверить с нынешним стеком. Старое решение не переносится автоматически.
