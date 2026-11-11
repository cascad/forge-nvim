# Поиск окна кода: ответственность и native проверка

2026-11-10, IDE-080, source `7fe45bc`, change `review-code-window-ownership`.
Это обзор текущего поведения. Production Lua, 67 pins и SDK не менялись.

## Вывод и следующий шаг

Объединять три finder целиком нельзя: они имеют разные полномочия. Выбор
существующего окна и создание нового следует сохранить раздельно; guard
должен сохранить свои exclude/marker/Edgy/winfix правила переноса файлов.

Небольшой следующий change — IDE-088: focus-only поиск принимает terminal,
даже когда обычное окно уже есть. Настоящий `F7`, затем `Space m d` возвращает
фокус в PTY на Windows/Ubuntu. Сначала постоянный E2E с исходным RED; затем
согласованная классификация обычного окна для focus. Кандидат — существующий
`state.is_main_window`, с сохранением прежних дополнительных исключений
activities (SQL/legacy tools). Нового window manager не требуется. Полный
общий tool registry здесь не предложен как обязательное решение.

## Три разные операции

| Условие/эффект | `ide.state` | `ide.activities` | `forge.panel_guard` |
|---|---|---|---|
| Вход | `is_main_window` / `find_main_window` | `find_code_window` / `focus_code_window` | private `find_main_target`, public `sweep` |
| Невалидное окно | Исключает | Исключает | Исключает |
| Float | Исключает | Не исключает явно | Исключает |
| buftype | Только пустой | Всё кроме nofile/prompt | Только пустой |
| Tool filetypes | Свой список | Свой меньший список | Свой список |
| `b:edgy_disable=false` | Разрешает после buftype/float checks | Не учитывает | Не использует как override |
| `w:forge_panel` | Не учитывает | Не учитывает | Исключает как target, использует как source |
| Живой Edgy owner | Не запрашивает | Не запрашивает | Исключает как target |
| winfix | Не учитывает | Не учитывает | Предпочитает clean target; fallback крупнейшее editor-окно |
| Порядок | Первое подходящее текущей вкладки | Первое подходящее текущей вкладки | Первое clean, затем крупнейшее, исключая source |
| Нет кандидата | goto_main, при необходимости vsplit/enew | nil / false, без создания | Не переносит, без создания |
| Side effects | Может создать окно, восстанавливает исходный фокус | Finder чистый, отдельный focus меняет фокус | Меняет buffer target, закрывает source, снимает winfix |

Источники: [state.lua](../nvim_forge/lua/ide/state.lua),
[activities.lua](../nvim_forge/lua/ide/activities.lua),
[panel_guard.lua](../nvim_forge/lua/forge/panel_guard.lua),
[marks.lua](../nvim_forge/lua/ide/marks.lua).

`activities.tool_filetypes` входит и в session cleanup. Замена всего списка
изменит удаление buffers перед сохранением, даже если задача только о focus.
У guard список нужен также buffer-only проверке именованного файла: window
predicate его не заменяет. Прямое применение state predicate в guard потеряет
window markers/Edgy и смысл clean/largest fallback.

## Native наблюдения

Probe `tests/diagnostics/code-window.lua` использует private настоящий editor
с неизменённой сборкой. Public API не оборачиваются, session/данные не
подменяются. Fixtures создают native окна/буферы и PTY. Synchronous снимки
названы в JSON; settled снимки ограничены 200–250 ms и не доказывают отсутствия
всех более поздних событий.

| Сценарий | Windows и Ubuntu, текущий source |
|---|---|
| Два обычных файла | Оба окна main; оба finder выбирают первое; лишний split не создаётся |
| Normal nofile + floating файл, без normal code | Activities выбирает float; State отвергает оба, создаёт normal code split |
| Настоящий PTY в первом окне | Activities выбирает terminal; State создаёт отдельный main, activities продолжает выбирать terminal |
| F7 → Space m d при PTY и main | Перед Debug фокус в main проверен; после открытия REPL/sidebar фокус уходит в terminal (IDE-088) |
| Файл в forge_panel=true, winfix | State считает marked окно main; public guard.sweep переносит файл в clean target и закрывает marked окно |
| Native session с winfix, Persistence.load | LoadPost содержит два файла и winfix; после callbacks одно normal code окно без winfix + Explorer; оба файловых buffer загружены |

PTY запускает настоящий `nvim --clean --headless` с таймером выхода 60 s;
probe останавливает именно этот job через jobstop, затем проверяется own scope.
Это контролируемый terminal fixture, не Delve/CodeLLDB.

Legacy session fixture добавляет localoptions в sessionoptions и вызывает
публичный Persistence.save напрямую. SavePre cleanup намеренно не вызывается:
цель — загрузка native файла с сохранённым winfix. Файл копируется в artifacts;
Persistence.load вызывает реальные LoadPre/Post и штатные guard/project:open.
Это не доказательство autosave или восстановления всех старых сессий.

По пять финальных profiles: native exit/signal=0, api_errors=[],
QuitPre/VimLeavePre/VimLeave, own scopes empty. По 63 runtime/pin/patch
источника каждого profile сверены с checkout; source probe скопирован и сверен.
Не называть пять завершённых probes пятью исправленными багами: IDE-088
воспроизведён, классификация пока прежняя.

Windows IDs: `25712524114200`, `25717357850600`, `25722298083800`,
`25727743025300`, `25732486941100`. Ubuntu: `958622497315`, `961970149103`,
`963889831727`, `966487288311`, `968036294383`. Artifacts: code-window.json,
snapshots/screens, config-source, driver source, native quit timeline/shutdown;
session profile содержит native-session.vim. Сводка `.tests/code-window-evidence.json`.

## Запуск и границы

Дополнение при разработке IDE-088: F7 использует четвёртый путь —
`ide.buffers.is_editor_window` и `config/keymaps.lua:focus_editor_window`.
Он исключает float и forge_panel, отдельно допускает alpha; сохраняет фокус
в текущем editor, а в Diffview предпочитает правое diff окно. Сам F7 окна не
создаёт. Создание main доступно через Space w 0 → state.focus_main.
Поэтому F7 нельзя механически заменить state finder или считать его alias
Space w 0 во всех состояниях. В первом варианте нового E2E создание ошибочно
ожидалось от F7; тест и новый контракт исправлены, runtime F7 не меняется.
Таблица выше сохраняет исторические результаты трёх исследованных ролей на
source 7fe45bc; дополнение предотвращает распространение её вывода на все
другие способы focus. Исходная диагностика F7/md уже имела созданный main.

На подготовленной native macOS/Linux машине:

```sh
nvim -l tests/diagnostics/code-window.lua
```

Windows после настройки TEMP/TMP/TMPDIR на F:, с подготовленным SDK:

```powershell
. ./scripts/lib/nvim-sdk.ps1
$forgeNvim=Get-ForgeNvim (Get-Location).Path
& $forgeNvim -l tests/diagnostics/code-window.lua
```

Ubuntu в уже запущенном engine, готовый image, без build/download:

```powershell
docker compose -f tests/containers/compose.yaml run --rm --no-deps --entrypoint nvim ubuntu -l tests/diagnostics/code-window.lua
```

FORGE_WINDOW_CASE выбирает normal, float-only, terminal-only, live-marker или
session-winfix. Итог — `.tests/code-window-review.json` (Docker: под
`.tests/ubuntu/` на хосте). Probe не включён в общий regression registry.

2026-11-11: Ubuntu gate IDE-088 выполнен (§170) —3 code-focus +19 прежних
DAP/Output/Go tests и default Python/Node/Rust debug checks, всего22 PASS,
16 native profiles. Actual editor exit/signal0/APIerrors[]/own scopes empty,
63 runtime/pin/patch sources совпадают; широкий merge по-прежнему не нужен.
Docker engine уже работал, использован готовый image без build/pull/lifecycle.

Native macOS/GUI, физические клавиши, настоящий DAP restart, полный autosave,
многовкладочный restore, modified/unsaved files и tool-only startup с настоящими
панелями остаются отдельными gates. Broad merge и изменение session cleanup
этими пятью fixtures не обоснованы.
