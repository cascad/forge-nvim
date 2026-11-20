# Design

## Context

См. proposal и явный ответ владельца. Базовый Sqruff уже отдельный module41
строк/IDE-BOOT-34. Дополнительный SQL:5 forge/ide modules плюс native_tools,
Rust runner/SQLS SDK и специальные delivery/prepare/test paths.

## Goals / Non-Goals

Goals: полное снятие дополнительных SQL слоёв без поломки базового SQL,
остальных adapters, user SDK/БД и общих механизмов установки.
Non-Goals: новый SQL provider, DB migration, удаление установленных у пользователя
бинарников/config/данных, изменение Go/Rust/Python/Node/Bash или plugin pins.

## Decisions

- Удалить runtime/commands/панели/adapters/SDK и только их dedicated tests;
  общие backend fixes и IDE-TEST-5/6 сохранить. История/FIXLOG append-only.
- Sqruff использует существующий tool_paths.executable с обычным PATH/Mason,
  overrides и dialect policy. Никакого нового manager/wrapper.
- Prepare SQL теперь только upstream Sqruff + pinned grammar. Existing cache
  не удаляется; fresh manifest не содержит SQLS/SQLite/Go/Rust runner.
- Старые явно переданные archives остаются общими archives; специальной SQL
  readiness/version selection больше нет. Current delivery/inventory не
  предлагает и не перечисляет дополнительные native SQL tools.
- Trace уже разбирает REMOVED, но не учитывает их при проверке старых E2E paths.
  Добавить минимальный removed index/фильтр и regression на реальное снятие
  контракта, сохранив разрешение старых ID для истории. Новая SQL baseline E2E
  доказывает фактическое отсутствие удалённой поверхности.

## Risks / Trade-offs

Dangling UI/setup imports → global source search и реальный startup/Tests.
Потеря Sqruff → existing native SQL2 + negative extras case, user/project paths.
Mixed adapters/installer → affected packet Windows/Ubuntu после всей реализации;
повторять только failed/affected cases. Mac/Omarchy/physical gates отдельно.
