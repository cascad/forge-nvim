# Design

## Context

См. proposal.md. IDE-GIT-2 уже покрывает успешный push в локальный bare
remote. Штатный Neogit предлагает force-with-lease при divergence, вывод
доступен через `$` и раскрытие строки истории команд. Конфигурация редактора
эти пути не переопределяет.

## Goals / Non-Goals

**Goals:** проверить отказ, читаемую причину, отсутствие потери commit и
повтор после исправления состояния; сохранить real Git output/UI артефакты.

**Non-Goals:** credentials/внешние сервисы, автоматический force, разрешение
merge/rebase-конфликтов, собственный Git backend, глобальная настройка Git.

## Decisions

1. Два постоянных real editor E2E с локальными fixtures. Первый создаёт
   peer clone и независимый remote commit, второй меняет origin на частный
   несуществующий путь. Альтернатива mock exit/error не проверяет PTY,
   notification, подтверждение и историю настоящего Neogit.
2. Действия stage/commit/push, отказ force, раскрытие истории и возврат в код
   выполняются клавишами. Git CLI служит подготовкой и независимым оракулом
   refs/index/файлов. Согласование независимых изменений перед retry — явный
   Git fetch/merge --no-edit в fixture; UI merge не объявляется покрытым.
3. Ожидаемый ERROR rejected принимается по точному тексту. Для missing origin
   независимый Git CLI push сначала сохраняет настоящий code 128/stderr;
   допускаются только fatal fragments из этого stderr с учётом PTY whitespace
   и известный summary отказа. Другие ERROR продолжают проваливать тест.
   Общий RPC/harness не ослаблять.
4. Каждый test сохраняет исходные Git refs/status, command history и UI/
   notifications snapshots. Bare refs и обе исходные вершины проверяются
   до/после отказа; retry не содержит force и сохраняет оба commit как ancestors.

## Risks / Trade-offs

- Многострочный notify может открыть hit-enter → принимать только конкретный
  ожидаемый вывод после его сохранения, прочие блокировки остаются FAIL.
- Штатный confirm временно блокирует редактор → наблюдать mode/screen,
  отвечать настоящим вводом, не вызывать внутренний push handler напрямую.
- Различия Git locale → fixture LC_ALL=C, отдельная проверка кода/refs/вывода.
- Ubuntu load на этом Windows хосте → тяжёлые наборы последовательно.

## Migration Plan

Добавить сценарии и registry, выполнить Windows и Ubuntu. При найденном
нарушении дополнить причину/решение до runtime fix. Записать точные результаты
и локальный commit; macOS/GUI доставки клавиш остаются непроверенными.
