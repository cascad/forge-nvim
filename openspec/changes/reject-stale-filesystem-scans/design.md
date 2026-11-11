# Design

## Context

См. proposal — Why и FIXLOG §178. Pin84c75e7a: fs_scan.create_context независим
для каждого запроса, но render_context принимает любой completion; renderer.draw
сохраняет текущие expanded IDs и создаёт новые nodes из старого root context.
Получается expanded=true/loaded=false/children=[] после уже показанного child.
Управляемые настоящие FS watcher→native a→late readdir воспроизвели это на ОС.
Это механизм, совместимый с двумя historical failures; уникальность их причины
без старых scan timelines не доказана.

## Goals / Non-Goals

**Goals:** отбрасывать устаревший full-root результат перед записью в live tree;
сохранить native файловые действия, watcher/follow/async и независимые partial loads.
Постоянный native RED→PASS и keyboard create/open/edit/save должны отличать
действительную потерю child от locator-only failure.

**Non-Goals:** свой scanner/renderer/queue, global fs shim в продукте,
периодический refresh, таймауты/retoggle в locator, async=never, новый LSP,
массовое обновление pins/SDK. Диагностический IO hook — только private child.

## Decisions

- Выбирать upstream correction при реальной доступности и доказательстве тем
  же reproducer. Read-only main source review и поиск пока не дали готового
  решения; это не доказательство отсутствия всех возможных upstream fixes.
- Если готового correction нет, использовать existing source-locked backport
  preparation/check/revert, с точными before/after SHA и минимальным guard
  актуальности full-root context. Не добавлять ещё один runtime controller в Forge.
- Актуальность должна принадлежать state дерева; новое полное сканирование
  делает более старое full-root completion неактуальным. Проверять у точки
  применения результата/callback; IO штатно завершается, native handles не
  бросаются. Несколько независимых partial scans не считаются взаимозаменяемыми:
  один global "последний вызов выигрывает" для всех folders неприемлем.
  Partial contexts прежнего root не должны повредить новое дерево; проверять
  отдельным control. Если это требует существенной private архитектуры,
  оставить баг открытым и пересмотреть готовые upstream варианты.
- First source controlled diagnostic использует actual FS_EVENT от owned marker,
  удерживает только последний настоящий async readdir callback private root;
  native a создаёт child и новый root result, затем старый callback выпускается.
  Ошибки/entries/renderer/backend не подделываются. Hook ограничен exact private
  cwd realpath, restored при release/cleanup; producer stack fs_scan.lua обязателен.
- Четыре queue turns после final shallow callback — observation barrier для
  конкретной цепочки on_exit→job_complete→render→AFTER_RENDER, не sleep/таймаут
  для успешного появления child. До/после реальные nodes/disk/rows сохраняются.
  Permanent E2E обязан дополнительно открыть/редактировать child; diagnostic
  exit0 значит успешно снято наблюдение, а не PASS исправления.
- Failure-only collector старого E2E добавляет loaded/children/filtered_by и
  capped128 all-node map; locator и deadline не менять. Обычные bounded PASS
  никогда не заменяют сохранённые source failures.

## Risks / Trade-offs

- Два historical failures не имеют native scan-order trace → не приписывать
  доказанному механизму исключительную причинность задним числом.
- Guard может потерять latest callback/фокус или independent folder result →
  source/current controls, root change/partial loads, native errors и scopes.
- Устаревший context может затрагивать watchers/expanded state до render →
  проверить весь lifecycle применения результата; одного красивого screenshot мало.
- Upstream/default branch изменяется → source lock, removable backport и
  official-source comparison, без silent patch неизвестных bytes.
- Observer меняет timing → controlled IO порядок явен, реальные first failures
  хранятся отдельно. Mac/physical GUI без запуска остаются Not verified.

## Migration Plan

Сначала permanent regression и source RED с final exact test bytes. Затем
минимальный guard, явная dependency preparation Windows/Ubuntu и те же tests,
old Files/copy/delete/buffers/deleted-files/backport CLI/quick/trace/strict.
Journals raw append, самостоятельный commit. Backport revert штатной командой;
удалить при переходе на upstream source, который проходит тот же regression.
Mac/GUI task не закрывать и change не архивировать до реального запуска.
