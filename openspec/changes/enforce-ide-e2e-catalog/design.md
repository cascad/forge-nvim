# Design

## Context

spec_index уже разбирает requirements/Проверка, registry хранит suite.
trace проверяет canonical specs, а ADDED активных changes использует только
как known ID. Повторный каталог с ручными списками IDs не нужен.

## Goals / Non-Goals

**Goals:** автоматическая целостность IDE E2E metadata и запрет завершения
без registered E2E, честный PENDING для ещё не реализованных requirements.
**Non-Goals:** доказывать семантическую полноту тестов статикой, подменять
OS PASS metadata, отменять SQL references/архивировать незавершённое,
вводить новый runner/service или менять пользовательский runtime.

## Decisions

- Existing index сохраняет changed requirement objects ADDED/MODIFIED
  с Проверка. Canonical ids/added/archived роли прежние; REMOVED/RENAMED не
  вводят новую обязанность создать behavioral E2E.
- Existing trace проверяет declared IDE paths даже у открытых changes.
  Каталог использует physical file + registry suite=e2e либо существующий
  native Python inventory batch runner. Discovery переносится в batch_plan
  и переиспользуется trace/CLI, без второго списка. Unit/manual не являются E2E.
  REGISTERED означает presence, никогда runtime PASS; runner виден в JSON.
- Main IDE requirements и changes с непустыми tasks, у которых все checkboxes
  завершены, требуют E2E по умолчанию. Открытое requirement без E2E — PENDING.
  trace --change NAME требует связь до завершения, unknown NAME — ошибка.
- Каталог возвращается из existing trace API, попадает в tests/run.lua JSON.
  Trace CLI может явно записать --catalog-json; без этой опции root read-only.
- Native self E2E запускает реальный trace CLI на минимальном private дереве,
  source driver8c92268 из Git, real exit/stdout/JSON. Не подменять collect,
  fs/registry или vim.system; sample requirements — данные, не новый IDE PASS.
- Existing missing links исправляются в delta metadata; inline Frame
  Проверка разбирается также после поля Платформы. SQL future requirement остаётся
  открытым PENDING, без специальных allowlists и фальшивого теста.

## Risks / Trade-offs

- Каталог может найти незаписанный долг; не создавать no-op E2E ради зелёного.
  Source false PASS и target failure должны быть сохранены permanent CLI E2E.
- Task completion читается из существующих tasks.md checkboxes, не текста
  verification или итогового сообщения. Selected gate не зависит от checkbox.
- Присутствие E2E не доказывает его качество/прогон на ОС. Native feature
  reports и Mac gates остаются отдельными; Ubuntu engine доступен2026-11-18.
- Native CLI plan/Core-gate случаи выделяются из смешанного unit-файла в
  зарегистрированный e2e файл, pure selection cases остаются unit. Container
  shell drivers не объявляются самостоятельными tests только по суффиксу .sh.
