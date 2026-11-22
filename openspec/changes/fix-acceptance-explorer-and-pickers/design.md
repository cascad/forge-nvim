## Context

Windows owner acceptance обнаружила визуальные дефекты после файловых операций.
Чтение запущенного редактора подтвердило Files, cwd проекта и отдельный root дерева.
Не считать позднее появление файла доказательством исправления задержки.

## Goals / Non-Goals

Goals: disk truth в Files; Git status отдельно; простая root/reveal навигация;
быстрые searchable keys; стабильная палитра.
Non-Goals: новый tree/backend/window manager, IDE-149 owner contract, Git workflow,
новые SDK, полный regression на каждое изменение, macOS PASS без машины.

## Decisions

Использовать native Neo-tree cwd/reveal/options и Telescope keymaps, без отдельной
базы сочетаний. Для нового root action использовать глобальную рабочую папку:
explicit project/worktree уже меняют её штатно. Tree navigation не меняет проект.
F1 и Alt+B — предложенный владельцу необязательный default, старые keys сохраняются.
Исправить caret декларативно. Files не должен рисовать Git tombstones/decorations;
native Git source продолжает показывать deleted/staged/untracked.
Сначала воспроизвести операции в Git-проекте, в том числе после navigate_up.
Если задержка не повторится, записать это ограничение, не выдавая тестовый PASS
за закрытие исходного owner incident.

## Risks / Trade-offs

bind_to_cwd и follow могут влиять на worktree/session: включить их в affected packet.
Нативная клавиша Alt+B может зависеть от терминала; старый Space b b остаётся.

## Open Questions

Дополнение приёмки: bare пК работает; п<S-К> не работает. Native mapping lookup
с production langmap ищет g<S-К>: prefix переведён, modified Cyrillic нет.
Общий ru_keys создаёт обычный RU, shifted RU и mixed Latin-prefix/shifted-RU
aliases; extend_mappings и vim.keymap.set используют одну функцию. Удаление
переназначаемых keys удаляет все её aliases. Сам langmap/terminal не меняются.
Владелец после уточнения решил сохранить текущие hidden filters.

Точная последовательность первоначального временно пропавшего файла не известна;
повторить реальные create/copy/move с expanded/collapsed папками и Git fixture.
