# Design

## Context

См. proposal.md. Treesitter main хранит libraries в `site/parser`, revisions в `parser-info`, queries в `queries`. Locked checkout 4916d6592ede8c07973490d9322f187e07dfefac уже подготовлен в editor-deps. Runtime transport умеет Core archives, hashes, probes и rollback.

## Goals / Non-Goals

Goals: готовые native libraries, native ABI/query проверка, общий Windows/POSIX путь без фонового setup.

Non-Goals: Git/rg/Terminal, full Default acceptance, смена pins, установка SDK, новый parser/package manager, публикация или заявление о native Mac readiness.

## Decisions

- Publisher над existing package-runtime принимает подготовленные Neovim/site/locked plugins. Он использует существующий каталог из Lua, а не копию списка в Python. Подготовка исходников остаётся отдельной явной publisher операцией.
- Общий Core site содержит весь существующий набор33 parser libraries и query dependencies. Это около15MB native libraries на Windows: отдельные archives на каждую грамматику добавили бы много связей без существенной экономии. Во время setup проверяется выбранный каталог; runtime не загружает неоткрытые языки.
- Site находится в `runtime/treesitter` и включается в штатный runtimepath, включая reset lazy. Пользовательский `stdpath(data)/site` не перезаписывается. Прямой native loader с owned path доказывает происхождение libraries при проверке.
- Managed parsers stage только проверяет доставленный site. Отсутствие готовых libraries — ранняя ошибка, не повод ставить компилятор. Unmanaged явная команда сохраняется.
- Revisions читаются из locked nvim-treesitter metadata и parser-info; queries берутся из соответствующего locked checkout, включая query dependencies. Native probe загружает библиотеки и разбирает queries.

## Risks / Trade-offs

- Старый user parser может иметь ту же revision, но неверный ABI → native probe каждого доставленного parser перед упаковкой и до publish kit.
- Native Mac и Linux нельзя доказать Windows запуском → те же команды на каждой ОС; Docker сейчас выключен, его lifecycle не меняем.
- Этот срез не закрывает чистую установку Git/plugins/Mason или Terminal → очередь RELEASE_INVENTORY остаётся открытой.

## Migration Plan

Новый publisher создаёт обычный Core artifact. Новый managed source требует готовый site; неполный Core даёт ошибку в staging, прежний kit сохраняется. Существующий runtime с тестовыми stage fixtures проверяется отдельно и не объявляется полным release.
