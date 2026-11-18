# Verification

2026-11-18. Источник125b6a6; большой §275 checkpoint не повторялся.

## Причины

- Rust: no-clippy fixture скрывала SDK bin, новый публичный resolver уже не
  принимал прямую подмену cmd за настройку tools.json. В action-state нет LSP
  clients/diagnostics. Теперь выбран настоящий RA через project tools.json;
  отрицательный cargo clippy probe и hash копии Cargo сохранены.
- DAP routes: экран5447645625085 уже содержал PROJECT_SINGLE, разделённый
  переносом PTY. Теперь проверяются отдельно session argv и actual stdout.
- Go runner: не включал подготовленный gopls. После исправления проявился
  IDE-DAP-10 bug: dap.async.run переиспользует nio coroutine, raw probe yield
  нарушает её protocol. Ubuntu11564440248158 содержит native stack; Windows
  source-case тоже FAIL (root завершился code1/signal15 при cleanup prompt).
  Callback теперь входит в native DAP coroutine из main loop через vim.schedule.
- Mixed SQL: ожидание sqls устарело после перехода на Sqruff (§267).
- Git: native live show5820592554022 завершился0 и вернул525319 bytes;
  тест дополнительно требовал необязательную следующую ошибку Git. Этот gate
  остаётся в completed-case. Live-case дополнен exact SHA256 linked HEAD.
- UI capture: native frame11818239986196 содержит UI_ROW_008 после scroll,
  но Neovim отдаёт grid_line без grid_scroll. Проверяются actual topline,
  реконструированные cells и новый redraw. Первое исправление по ошибке нажимало
  mapped Ctrl+E (Explorer); возвращён normal! и scrolloff0 внутри fixture.
  grid_scroll replay отдельно проверяет существующий ui_grid_test.py.

## Запуски

| Пакет | Windows | Ubuntu |
|---|---|---|
| Исходные5 файлов |1794997122703293800,267.05s,3 PASS/2 FAIL |1794997135716780557,191.89s,3 PASS/2 FAIL |
| Go correction + affected6 |1794997443166395400,175.28s,5 PASS/1 UI FAIL |1794997454409243970,113.43s,5 PASS/1 UI FAIL |
| UI correction + replay controls |1794997634210085300,20.87s,3 файла PASS |1794997596552478452,25.96s,3 файла PASS |

Итог по последнему запуску каждого затронутого файла: Windows41 E2E +2 unit
PASS, Ubuntu41 E2E +2 unit PASS; по11 файлов,0 FAIL/0 SKIP. Это affected aggregate,
а не новый полный regression. Синтаксис7 Lua files и strict OpenSpec PASS.

Артефакты — ignored .tests/{ubuntu/,}batches/<id>/{00.log,report.json}; raw
host logs — .tests/toolchain-research/checkpoint-{windows,ubuntu}-{batch,affected,ui}.txt.
Старые FAIL не заменены PASS. После каждого полного пакета повторялись только
failed/affected файлы; одновременно два OS runner не запускались.

## Границы

Native macOS, Windows positive Bash/WSL и Terminal/default acceptance не проверены.
Два §275 failed файла process/trace принадлежат прежнему незавершённому WIP;
этот commit его не меняет. Полный checkpoint PASS не заявляется. Desktop/WSL
не запускались и не перенастраивались; existing image/offline/limits2CPU/3GiB.
MODIFIED IDE-DAP-10 продолжает незархивированный make-go-debug-discovery-asynchronous;
сначала архивируется исходный ADDED delta, затем этот MODIFIED.
