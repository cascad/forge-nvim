# Design

## Context

См. proposal.md и FEATURE_REVIEW IDE-081. Закреплённый extension загружает
build/libfzf.dll на Windows и build/libfzf.so на Unix, включая macOS.
Наличие файла тоже не доказывает ABI: готовность определяет реальная загрузка.
Lua fallback уже является текущим поведением без рабочей native библиотеки.

## Goals / Non-Goals

**Goals:** optional ускорение без runtime compiler; явная диагностика и
воспроизводимая подготовка pinned C implementation для настоящего E2E.

**Non-Goals:** новый sorter/LSP, private fork, новые pins, обязательная native
зависимость для редактора, сборка/repair при старте, перестройка SDK остальных
языков, измерение ускорения без отдельного benchmark.

## Decisions

- Native plugin остаётся lazy dependency Telescope, cond по cmake удаляется.
  Результат load_extension фиксируется в одном status для read-only health;
  отсутствие/ошибка сохраняет уже настроенные штатные Lua sorters.
- Health не загружает Telescope ради проверки: состояние до первого picker
  не обязательно unknown: существующий DAP может загрузить Telescope раньше.
  Unknown относится к фактически незагруженному модулю; его дополнительно
  проверяет native health без init. Startup notify не добавляется.
- Отдельная короткая test preparation команда делегирует upstream CMake.
  Она собирает в native temp checkout, копирует только библиотеку в pinned
  editor SDK и сохраняет commit/source/artifact SHA в общем manifest.
  Изменение раннего prepare_editor/Docker COPY заново прогрело бы SDK всех
  языков; поздний слой image сохраняет их cache и не меняет Desktop/WSL.
- Native E2E исключает CMake из PATH, но использует настоящую библиотеку,
  C scoring и keyboard file/content переходы. Missing/corrupt варианты меняют
  только приватную копию библиотеки; функции sorter/LSP не подменяются.

## Risks / Trade-offs

- Будущее несовместимое native ABI → fallback и сохранённая причина, отдельный
  реальный native regression; runtime не объявляет loaded-флаг доказательством.
- Native build требует CMake/C toolchain → только явная подготовка; обычный
  редактор продолжает работать без них. macOS/ARM64 до прогона непроверены.
- Library уже загружена, затем изменена на диске → health описывает текущий
  процесс; после явной пересборки перезапустить редактор/перезагрузить Telescope.

## Migration Plan

Подготовить библиотеку, получить source RED без CMake; внести runtime/health
fix, проверить native/fallback Windows/Ubuntu и существующий поиск, записать
историю и commit. Откат — revert, native artifact optional и pins прежние.
