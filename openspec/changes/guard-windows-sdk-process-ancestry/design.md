# Design

## Context

§158 доказал условный source defect, не caller остановки Docker. Контролируемый snapshot меняет одну PPID связь; workers, FILETIME и сигналы настоящие. Прототип сравнения времени уже прошёл четыре сценария. Временный SDK v0.12.2 существует для ConPTY.

## Goals / Non-Goals

Цель — перенести узкий guard в закреплённый SDK и проверить production source и реальные Neovim jobs. Не доказываем Docker RCA, не меняем внешние приложения/WSL, не создаём отдельную постоянную ветку Neovim, не исправляем соседние native дефекты.

## Decisions

- Отдельный patch proc.c; FILETIME через удерживаемые process handles. При API failure пропускаем связь, root TerminateProcess остаётся прежним.
- Native controlled-snapshot harness компилирует фактический patched proc.c; upstream остаётся expected-RED baseline. Производственный код не получает тестовых hooks.
- Schema 2 manifest связывает revision, оба patch hash, нормализованный process source hash, binary hash и успешные probes.
- Preparer использует уникальный staging каталог на диске checkout и parallel=2. Перед продвижением выполняет native fixtures, реальные Neovim lifecycle E2E и ConPTY probe. Старый каталог сохраняется; при ошибке продвижения выполняется откат. Пути проверяются на границы и reparse ancestors.
- StageOnly позволяет проверить дополнительные editor E2E выбранным binary до продвижения. Launcher только проверяет файлы и hashes.

## Risks

Проверка времени необходима, но не является полной идентификацией всех возможных деревьев при гонках. При неизвестной хронологии можно оставить child живым; это предпочтительнее завершения неподтверждённого процесса. При занятом SDK замена может отказать; пользовательские редакторы не завершаются автоматически. SDK guard не обещает исправления IDE-087 без caller trace.

## Open Questions

Точный caller двух остановок Docker; данные не блокируют независимое исправление IDE-089. Снятие обоих backport после подтверждённого upstream fix — отдельная проверка.
