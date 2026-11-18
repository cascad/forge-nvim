# Design

## Context

См. proposal. Mason использует штатные Python/npm managers. Его process module
сохраняет initial environment при загрузке, поэтому менять PATH после загрузки
Mason недостаточно. Existing setup tools stage запускается отдельным Neovim.
tests/run.lua уже умеет registry/timeouts/report; менять его не требуется.

## Goals / Non-Goals

**Goals:** согласовать tools setup с сохранёнными Python/Node paths, сохранить
native SDK homes/менеджеры; одна команда блока и видимый план полного regression.

**Non-Goals:** SDK wrappers, provider patches, установка SDK, новая политика
версий/Go build toolchain, изменение installer --sdk-path fallback priority,
управление Docker Desktop/WSL lifecycle, сокращение покрытия или параллельный full suite.

## Decisions

- Общий setup_sdks вызывается pre-init tools процесса до Mason snapshot. Только
  нужные по каталогу языки и explicit overrides; без override среда прежняя.
- В PATH tools процесса добавляются bin directories выбранных native SDK.
  Проверяются штатные executable имена и Node/npm одного SDK. Непредставимый
  custom executable — source-aware ошибка, без генерируемого shim или fallback.
  Совместимую версию пакета по-прежнему выбирает native Mason provider.
- Runtime init/SDK homes/project programs не меняются. Setup report показывает
  выбранные path/source. Проверки готовности Mason receipts остаются прежними.
- Список файлов фильтрует существующий registry перед tests/run.lua; новый
  driver не дублирует runner. Explicit native installer .test.py разрешены отдельно.
  regression добавляет все native installer suites к полному registry.
- --plan/-Plan перечисляет команды/файлы без редакторных E2E. Batch очищает
  унаследованные case filters, работает последовательно, сохраняет exit/time/log.
  Failures не скрываются; timeout останавливает дальнейший batch.
- Во время разработки E2E не запускаются по каждой правке. После целого блока
  один согласованный batch; повторяются только failed cases и их affected checks.

## Risks / Trade-offs

- Mason может выбирать совместимую Python по native правилам → этот контракт
  не обещает override private provider API; ограничения объясняются в docs.
- Full regression длительный → явный отдельный режим с plan, не daily loop.
- WIP runner/catalog вне задачи → сохраняем их bytes и не включаем в коммит.
- Native installer fixtures в Docker держат runtime в guest /tmp, доказательства
  экспортируют на bind mount; иначе SDK copies доминируют по времени.
