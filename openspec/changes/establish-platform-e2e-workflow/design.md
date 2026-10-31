## Context

Общий tests/run.lua уже умеет отчёты, фильтры, unit/WezTerm/install/trace.
Расширяем его. Для новых IDE-сценариев ещё нет PTY/GUI-backends.

## Goals / Non-Goals

Goals: одинаковый контракт прогонов, e2e первого CLI, реальные результаты
Windows/Ubuntu и понятный запуск на Mac; документировать недостающее покрытие.

Non-Goals: считать полный IDE e2e реализованным, переписывать все платформенные
ветки без регресса, автоматизировать гипервизор, включать Mint в текущую матрицу.

## Decisions

- Suite e2e запускается обычным runner и входит в его default-набор.
- Тонкие shell-обёртки выбирают набор; сценарии и assertions общие.
- Новая граница CLI тестируется отдельным процессом; аргументы обёрток
  проверяются через дочерний nvim-stub. Это e2e обёртки, не самой IDE.
- Ubuntu image скачивает официальный Neovim фиксированной версии с SHA256.
  Сеть доступна при build; runtime network none, чекаут readonly.
- Тесты запускаются непривилегированно: root меняет семантику chmod/read-only.
  При разработке первоначальный root-прогон выявил это на S16 macOS-installer.
- Windows и Ubuntu отчёты разделены. Mac/GUI-проверки остаются в матрице
  непроверенными до фактического запуска владельцем.
- Явный prepare_editor.py экспортирует git archive pinned commit из локального
  кэша или с --download из GitHub; источники URL отдельно, lazy-lock — revisions.
  Docker делает это при build, runtime не скачивает зависимости.
- Editor backend использует vim.system/stdin + Msgpack-RPC на встроенном
  vim.mpack. Клиент принимает redraw после nvim_ui_attach; UIEnter/VeryLazy
  должны произойти реально. Плагины и обычные mappings не подменяются.
- Сборка полностью копируется в private stdpath(config): lazy сбрасывает rtp
  к stdpath, поэтому внешнего -u недостаточно. HOME/data/state/cache и Git-проект
  изолированы; большой runtime в native temp, артефакты в .tests.
- Polling RPC выполняется вне callback vim.wait, чтобы избежать вложенного
  event loop с повторным predicate. Готовность insert mode, дерева и результатов
  поиска проверяется отдельно; наличие окна не означает завершение его загрузки.

## Risks / Trade-offs

APT пока не snapshot-pinned. Реальные LSP/DAP/языковые fixture-тулчейны ещё
не включены в минимальный образ. Автоматический coverage gate и backends
PTY/GUI — открытые задачи, зафиксированные в roadmap. Текст remote UI —
диагностический артефакт, не пиксельный oracle и не доказательство физической
доставки клавиш. Граница core e2e пока .txt; языковые интеграции не проверены.

## Migration Plan

Запустить quick/e2e/full нативно на Windows, в Ubuntu-контейнере и на Mac.
Артефакты сохраняются в .tests; результаты целевой ОС не заменяются другой.

## Open Questions

Путь к cs2d и детали его runner/артефактов; конкретный Linux GUI-backend.
