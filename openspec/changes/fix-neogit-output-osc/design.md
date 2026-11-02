# Design

## Context

В 24997056234800 real Git дал util строку ESC]0;C:…BEL + CSI ?25h; функция
вернула :…BEL. Upstream HEAD 697ad3e исключает byte 155 из CSI ради UTF-8,
но не удаляет полный OSC. Текущий pin d7bb91b остаётся для обоих backports.

## Goals / Non-Goals

**Goals:** исправить текстовую границу Neogit одинаково на всех ОС, сохранить
причину и полезный вывод, закрепить native/portable воспроизведение.

**Non-Goals:** полный streaming VT parser, смена Git/Neogit версии, фильтр
Windows-путей, runtime monkeypatch и управление Docker Desktop/WSL.

## Decisions

1. Полный OSC с BEL/ST удаляется до существующего CSI filter. Payload pattern
   не пересекает ESC/BEL, поэтому соседние разные terminators не съедают
   видимый текст между ними. UTF-8 byte 155 исключается как в upstream;
   обычный путь без OSC сохраняется. Проверка терминаторов/UTF-8 — parser matrix.
2. В существующий pin/SHA descriptor Neogit добавляется util companion;
   worktree primary не меняется. Общий applier уже делает preflight всех
   файлов. Подготовка явная, startup read-only. Новая CLI/Lazy проверка
   покрывает legacy primary-after/util-before и неизвестный companion.
3. Реальный missing origin воспроизводит Windows случай. Дополнительный
   pre-receive hook частного bare remote печатает OSC и отклоняет push на
   всех ОС. Это настоящий Git code/ref change, не имитация backend.
4. Нативные E2E сохраняют prompts/notifications/history/refs и реальный retry.
   Матрица actual pinned util — дополнительная проверка parser, не UI E2E.
   Неожиданные ERROR/confirm/нативные E… не подтверждаются автоматически.
   Для повторного RED: явные config archive 7938409 и upstream source variant
   восстанавливают только util в частном профиле до запуска child, с проверкой
   обеих SHA; IDE-034 primary сохраняется. Данные старого/нового util копируются
   в artifacts. Родительский prepared cache и пользовательские plugins не меняются.

## Найденные ограничения интеграционных проверок

Первый Windows unit/e2e/trace сохранил 38 PASS / 2 FAIL: SDK CLI class был
прерван общим 30s после 12 завершённых команд (27.28s суммарно), хотя ни одна
не достигла своего 10s; следующий launcher записал результат уже после
внешнего deadline. IDE-045 разделяет исполнение по unittest-сценариям через
discovery, сохраняя 10s команды, 30s сценария и 60s файла. Это исправление
организации теста, не устранение неизвестной причины холодного запуска shell.
Артефакты каждого сценария включают argv, PID, elapsed и результат.

IDE-046: branch/commit/push проверка искала строку до завершения UI refresh;
отложенный Neogit redraw восстанавливал ранее сохранённый курсор. Ожидание
status Head после checkout устанавливает готовность панели до поиска.
Первый Ubuntu full обнаружил лишнее требование текущего фокуса: main Head
уже виден, а cursor вернулся в code. Готовность теперь читается среди видимых
окон текущего tab, без изменения фокуса. Приложение, лимиты и Git операции
не меняются. Три первоначальных повтора PASS
не заменяют сохранённый исходный FAIL и последующий общий регресс.

## Risks / Trade-offs

- Слишком широкий OSC pattern удалит текст между BEL/ST → разные terminators
  и соседние строки в матрице, видимые markers в native hook.
- Частичная/неизвестная зависимость → pin/SHA/preflight до записи, отдельный
  regression для обоих файлов, инструкция обновления и отмены.
- Подготовленный образ содержит прежний manifest → явный rebuild на уже
  работающем engine, старые download layers сохраняются; без lifecycle действий.
- Иные control strings/stream fragments → не объявлять полным VT parser;
  цель — завершённые OSC текстовых results/уведомлений.
