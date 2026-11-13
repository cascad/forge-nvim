# Design

## Context

См. proposal и явный выбор владельца. session_views уже владеет одним version1
sidecar и native Edgy dimension helper. Neotest PersistentWindow владеет одним
штатным Summary window, User NeotestSummaryOpen — событие готовности окна.
Bats discovery существующего public adapter читает declarations без исполнения;
новый parser/SDK для Tests не нужен. Bash debug и Node SDK уже подготовлены.

## Goals / Non-Goals

**Goals:** оставшиеся native geometry без startup процессов и второго storage.
**Non-Goals:** копии/renderer Tests, snapshot раскрытий/results, per-section
высоты DAP, floating/vertical Terminal, эмуляция законченного процесса или
восстановление его scrollback. Не менять shell profiles/backend/SDK/pins.

## Decisions

- Optional tab.tests=false/table(width,columns) добавляется к прежнему JSON.
  Restore Files→Outline→Tests→Logs. Для асинхронного Summary используется
  public NeotestSummaryOpen; остальные tools сохраняют прежний путь. Нет
  polling/таймера/своего consumer. Штатное одно окно не клонируется по tabs.
- Optional tab.deferred хранит terminal(height,lines), debug_sidebar(width,
  columns), debug_output(height,lines). Sidebar width общая для его native
  scopes/watches/stacks/breakpoints, Output height общая для repl/console/PTY.
  Новых окон и commands из этих данных restore не вызывает.
- Память view данных находится в session_views по native tab handles.
  WinLeave/WinResized снимают настоящие размеры ещё видимых окон; это сохраняет
  изменения после q. Capture дополняет их текущими окнами перед cleanup.
- BufWinEnter/FileType/WinEnter применяют размеры только появившегося native
  окна через прежний resize helper. Один queued apply на пару win/buf, затем
  focus не переустанавливает размер. Native close/tab close чистят метки.
  До первого apply наблюдатель не заменяет saved size открывающими defaults.
- Setup только регистрирует UI callbacks в существующем Persistence config;
  никаких child commands/install/probe при startup/restore. Старые sidecars
  без новых fields читаются как раньше.
- E2E — прежний session_tui, реальные Bats positions без run, настоящий shell
  с echo и официальный Bash DAP. SDK/процессы запускаются явно только в Debug
  case, Windows использует выбранный WSL2 backend. Нового test runner нет.

## Risks / Trade-offs

- Async Summary → завершение по native событию, scoped cleanup обработчика.
- Native default dimensions на открытии → читать после Edgy и один apply;
  ручной resize/фокус/скрытие проверяются actual geometry и sidecar.
- Общие Debug groups → размеры боковой/нижней панели, не частных секций.
- Windows/Ubuntu selected serial; Mac/physical остаются обязательными gates.
- Первый source25888173612200 показал native header50 tests, но fixture
  ошибочно ожидал их раскрытые labels. Теперь проверяет public positions,
  не сохранение folds. Source Debug25938345189500 посылал Ctrl-\ из normal
  панели и включал Terminal; escape теперь только для mode=t. Cleanup явно
  завершает свой DAP и возвращает code mode до штатного quit. Terminal source
  25918675252300 уже подтвердил потерю размера после restart.
- Source v2: Tests26520839508500 подтвердил отсутствие сохранённого окна,
  Terminal26556788249700 — потерю height. Debug26577385504800 выявил ещё одно
  предположение fixture: q в Locals скрывает sidebar, Output — отдельный
  component. Теперь они скрываются двумя native действиями; это не runtime fix.

- Основной Windows target:3 новых PASS, selected21 PASS/1 FAIL. Logs27485199147400
  остановился на первом quit до restore: SavePre→SavePost13919.208ms при
  native quit deadline10s. Исходный FAIL сохранён как IDE-129. Один отдельный
  phase probe28333531556800 с прежним runtime/deadline:6 saves, capture max5.467ms,
  cleanup max67.682ms, native save max27.587ms, workflow PASS. Это измерение
  не закрывает исходный инцидент и не подменяет основной verdict.
