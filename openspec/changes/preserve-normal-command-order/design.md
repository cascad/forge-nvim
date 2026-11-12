# Design

## Context

См. proposal. after_normal_mode используется четырьмя обычными actions.
Для уже normal вызова обязательного перехода нет, но schedule откладывает
чтение current context до выполнения более поздних команд.

## Goals / Non-Goals

**Goals:** синхронная normal ветка в существующем helper.
**Non-Goals:** новый focus manager/generation/timer; перепись режима terminal;
смена алгоритмов buffers.close/cycle или dialog policy.

## Decisions

- Early normal branch вызывает fn и возвращается. Return helper остаётся nil.
- Остальной helper сохраняет прежние stopinsert/feedkeys и schedule.
  Context остаётся выбранным пользователем; снимок window ID и новый state
  для очереди не добавляются.
- E2E отправляет настоящую последовательность клавиш и ждёт F35 + scheduled
  barrier; backend не подменяется. Отдельные insert/real terminal controls
  защищают прежние переходы. Normal close использует сохранённый buffer.

## Risks / Trade-offs

- Synchronous window/buffer mutation → existing buffers/Files/Diffview E2E.
- Изменение не-normal ветки → её source/target controls и terminal escape.
