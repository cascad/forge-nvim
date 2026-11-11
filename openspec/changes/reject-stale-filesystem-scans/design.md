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

### Отклонённый вариант (§179)

19-line root-generation-only guard проверен через штатный applier и полностью
снят: два controlled RED стали PASS, но current Windows control-набор дал
2PASS/3FAIL. Независимые partial loads и pending initial reveal теряли child;
ordinary create один раз также потерял видимость. Source initial5 —3PASS/2RED
на обеих ОС. Нельзя убирать control/initial-file вариант или ослаблять locator
ради guard. В tests/diagnostics/fixtures сохранён неиспользуемый prototype diff.

Следующее уточнение реализации: поколение корня недостаточно описывает
пользовательский intent. Проверить, как незавершённый native toggle_directory
и show_new_children передают раскрытие в новое full-root snapshot; сохранить
запрошенные открытия при таком overlap. Нужен контроль watcher ownership:
устаревший context не должен оставлять references на уже сменённый root.
Исторические callers для каждого untraced control failure ещё не сняты;
объяснение отменой pending partial совместимо с кодом, но не считается
единственным установленным caller каждого отказа. Нового private scanner/
queue/периодического refresh это решение не разрешает.

Current upstream v3.x1a140830/main760d970: scanner SHA b0bf0f36…68c1,
оба controlled failures воспроизвелись на actual v3.x archive в private
Windows runtime (2PASS/3FAIL всего). Поэтому обновление pin не принято;
эта проверка не означает оценку всех будущих upstream изменений.

### Следующий вариант: intent и принятый snapshot

Семь permanent native cases добавляют два управляемых порядка: полный watcher
refresh пока partial ожидает IO, и завершение полного snapshot после более
нового partial. Последний даёт отдельный source RED даже без смены root;
проверка private native watcher table выявила active watch от obsolete partial.

К поколению root добавляется сохранение запроса открытия обычным node:expand
в native toggle_directory/show_new_children. Новый full scan тогда включает
запрошенный каталог, даже если path_to_reveal заменён watcher refresh.
Перед применением full snapshot проверить актуальные раскрытые каталоги:
если snapshot их ещё не загрузил, оставить live tree и запустить штатный
async get_items с тем же callback/reveal. Проверка actual fs_stat исключает
повтор для уже удалённого каталога. Это реакция на измеренный overlap,
не периодический refresh/таймер/ручной R и не отдельная scan queue.

Это сравнение относится только к обычному full snapshot. Native query view
намеренно исключает несовпадающие папки, а explicit force_open_folders задаёт
собственные раскрытия (в частности, при clear filter). Смешение с live view
даёт rescan loop IDE-105: предварительный candidate вызывал71 fd за5s.
Поэтому search_pattern/force_open_folders исключены из coherence retry.
Два дополнительных native keyboard E2E проверяют filter_on_submit и Ctrl-X:
из раскрытой alpha query beta возвращает beta и восстанавливает alpha;
из исходно свёрнутого root clear возвращает именно свёрнутый вид.

IO completion только помечает local context folder loaded. Снять прежние
watchers и зарегистрировать новые — один раз при принятии coherent full
snapshot; accepted partial добавляет только свои watched directories.
Устаревший context не получает refs. Native IO, callbacks, фильтры и renderer
сохраняются. Изменения ограничены двумя pinned filesystem файлами, existing
backport applier/check/revert; native assertions/watchers и companion preflight
обязательны до принятия. Mac/GUI и большой regression не заменяются source review.

Сначала permanent regression и source RED с final exact test bytes. Затем
минимальный guard, явная dependency preparation Windows/Ubuntu и те же tests,
native filter/clear, old Files/copy/delete/buffers/deleted-files/backport CLI/quick/trace/strict.
Journals raw append, самостоятельный commit. Backport revert штатной командой;
удалить при переходе на upstream source, который проходит тот же regression.
Mac/GUI task не закрывать и change не архивировать до реального запуска.
