# Design

## Context

Мотивация — proposal.md. Новый обзор source8d721c3 включает SDK/installer/Mise
последних этапов и новый обязательный IDE-146. Прежний FEATURE_REVIEW смешивает
исторические варианты с уже принятыми решениями; PLUGIN_INVENTORY всё ещё
совпадает с67 lock pins, но часть оценок устарела.

## Goals / Non-Goals

Goals: один текущий обзор, отдельный полный plugin inventory и сохранённая
история; у каждого кандидата — потеря/выигрыш, evidence и следующий шаг.
Non-Goals: runtime refactor, удаление фич, смена pins/SDK, новые плагины/LSP,
новый тестовый framework или повтор тяжёлого E2E ради документации.

## Decisions

- FEATURE_REVIEW остаётся текущей точкой входа; прежний текст переносится в
  docs/history с перебазированными relative links. PLUGIN_INVENTORY содержит
  все67 имён/pins, актуальные оценки и отдельно прежние runtime snapshots.
- LOC — только source cost, не CPU/startup benchmark. Installed/loaded/pinned
  и REGISTERED/PASS различаются. Старые native результаты имеют свои даты.
- Breadcrumbs/navic/Satellite, Comment и базовые workflows сохраняются согласно
  принятым решениям. Дополнительный SQL не удаляется без решения владельца;
  ожидаемый ответ не препятствует завершению самого read-only обзора.
- IDE-146 записывается как будущий сценарий с source legacy route и E2E cases;
  хоткей и реализация будут отдельным изменением поведения.

## Risks / Trade-offs

Старые anchors/relative links → проверить ссылки и сохранить исторический текст.
Переоценка числа plugins → группировать по пользовательским обязанностям.
Недоступные native среды → явные gaps, без новых behavioral PASS.
