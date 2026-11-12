# Design

## Context

См. proposal. Native adapter root_for_tests ищет go.work/go.mod и рекурсивные
go.mod, discovery кэширует корень. Общий consumer берёт public client trees.
Имеется готовый Treesitter Go parser/gotestsum SDK. Source/диагностический E2E
выявил infinite parent walk на suite root без go.mod; upstream main содержит
тот же алгоритм. Runtime исправляется после добавления delta.

## Goals / Non-Goals

Goals: наблюдать discovery обоих модулей и точный объём nearest/file/all.
Non-Goals: переписывание root detection/parser, новые backend, DAP-тесты,
LSP/mixed-language матрица и развитие общей тестовой инфраструктуры.

## Decisions

- Summary открывается из app; shared file ещё не открыт. Public neotest
  positions должны содержать3 tests. Иначе cold workspace остаётся пробелом,
  открытием shared перед Run all этот пробел не маскируется.
- nearest→all→file→fix assertion→all. Каждый test пишет свой счётчик на диск;
  counters доказывают реальные выполнения даже при сохранённых status results.
- Go test/gotestsum исполняются штатно offline/count1. UI управляется Tt/TA/Tf,
  обычным edit/write и Tp; RPC читает только публичные state/output.
- Если найдётся дефект, до runtime изменения меняем test-only scope на bug
  delta; исходный отказ сохраняется. Private parser/индекс не добавляются.
- Публичная копия Go adapter делегирует build_spec только при native enclosing
  go.mod. Container с go.work возвращает nil; Neotest сам разбивает suite на
  файлы. Нет подмены функций внутри backend/своего go.work parser/cache.
- Native running.concurrent=false ограничивает число одновременно активных
  команд fallback; тестовый процесс Go сохраняет свою стандартную семантику.
  Это общая policy, а не Windows-ветка. Fallback per-file медленнее одного
  module run, но не зависает и не раздувает число процессов.
- Root suite проверяется через общий TA и прямой public Neotest run API,
  чтобы исправление не зависело только от consumer Forge.
- После первого file target выявлен E5560: sequential fallback возобновился
  из fast event, а backend вызывает vim.fn.expand. Public nio.scheduler на
  adapter boundary переводит подготовку следующего target в main context.

## Risks / Trade-offs

- Асинхронный discovery → wait по реальным position/result predicates.
- Ожидаемый fail fixture → E2E проверяет2 pass/1 fail и после исправления3 pass.
- Known POSIX cleanup → отдельный полный verdict и workflow evidence.
- Future upstream workspace builder → удалить helper после source/target
  nearest/file/suite tests на всех целевых ОС; dependency pins сейчас прежние.
