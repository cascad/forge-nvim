## Context

См. proposal.md; владелец выбрал Space w в async-ответе. Направления уже
заняты штатными wincmd, d/c/0/z/? свободны. wv/ws/wo сохраняются. DAP sidebar
составной: scopes/watches/stacks/breakpoints — один ide компонент. Edgy q
закрывает одно физическое окно, оставляя остальные; состояние sidebar может
рассинхронизироваться. REPL/console/terminal — разные источники вывода.

## Goals / Non-Goals

Goals: рабочий пилот focus/help/hide/zoom Run & Debug и real Delve E2E.
Non-Goals: глобальная замена FSM, перенос всех панелей, новые tree actions,
перехват Space в insert/terminal, закрытие старых алиасов и подтверждение
GUI-доставки клавиш без запуска GUI. Дальше подключаются Outline/Git/tests.

## Decisions

- Небольшой ide.controls над ide.state/dap; направления используют wincmd,
  скрытие — зарегистрированный debug component. Фокус не вызывает DAP commands.
- Буферные normal q/Esc/? только для debug-панелей. Native Enter/j/k остаются.
  Русские aliases создаёт существующий ru_keys wrapper; реальные ru/en RPC
  sequences проверяются отдельно от физического WezTerm ввода.
- Заголовок показывает [focus], имя секции и ?. Winbar обновляется после
  появления окна/смены фокуса; остальные панели сохраняют свои заголовки.
- Zoom — временное увеличенное окно с тем же буфером, не перестройка edgebar.
  Исходные windows/buffers/dimensions не закрываются. Повтор/Esc закрывает
  overlay; q сначала возвращает исходное окно, затем скрывает компонент.
  При уходе в другое окно/tab или закрытии источника overlay убирается.
- Output фокусируется по видимому DAP каналу; при скрытии помним последний
  repl/console/terminal в ide.dap. Не подменяем PTY на REPL и не чистим буфер.
- E2E: один private editor, Go/Delve fixture с struct Value=42, настоящий
  breakpoint, ввод через mappings, наблюдение публичного DAP session и буферов.
  Проверяются Enter, help, alias, навигация, zoom/restore, q/Esc, REPL текст,
  сохранность stdout, паузы и исходного окна. Старый q — исходный red.

## Risks / Trade-offs

- FT/autocmd/Edgy порядок → отложенное обновление winbar, buffer-local mappings,
  scope пилота и общий регресс. Не включать tool maps в обычных файлах.
- Повторное окно prompt/terminal → общий buffer и real REPL E2E; PTY других
  адаптеров/Mac остаётся отдельным проверочным долгом.
- Late DAP events и закрытый источник → проверка валидности window и очистка
  overlay без перезапуска программы или восстановления уже закрытой панели.
- GUI/Mac → явно непроверено; RPC input не доказывает доставку физических клавиш.
- После перезагрузки Docker выключен. Для red replay сохранён исходный
  config-source Windows-прогона; harness принимает явный FORGE_E2E_CONFIG_SOURCE,
  проверяет совпадение lock и записывает config-origin. Это реальный старый
  config, не подмена backend; default по-прежнему текущий nvim_forge.
- Go E2E используют общий приватный compiler cache прогона в native temp
  через FORGE_E2E_GO_CACHE. Вариант .tests/go-build-cache на Docker/Windows
  bind mount оказался слишком медленным для deadlines Go tests и заменён
  native FS. Это не test-result cache; источники и flags учитываются Go.
  Холодная сборка может показать штатный adapter-slow
  WARN: E2E сохраняет уведомление, снимает hit-enter и ждёт реальный breakpoint;
  ERROR не игнорируется, ожидание ограничено deadline.
- Внешнее закрытие source на Windows/Ubuntu воспроизвело Satellite ERROR
  Invalid height: список исключений содержал старые dap-view FT, но не
  нынешние dapui_scopes/watches/stacks/breakpoints. Добавлены актуальные
  debug scratch FT в штатный excluded_filetypes, без подавления ERROR.

## Migration Plan

Перезапуск Neovim; новых плагинов нет. Старые aliases сохранены. Откат —
новый controls/setup/keymaps; DAP stdout/eval предыдущих changes остаются.
