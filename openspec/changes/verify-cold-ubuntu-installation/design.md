# Design

## Context

См. proposal. Production artifact catalogs пусты; локальный release-like stand
получает настоящие native Core/Terminal/frontend через временный catalog и HTTP.
Языковые SDK и Mason/plugins caches в target container не подмешиваются.

## Goals / Non-Goals

Goals: доказать cold default SDK/setup и повтор с наблюдаемыми причинами отказа.
Non-Goals: публикация release, native macOS/GUI/WSL, собственный package manager,
новый E2E runner и смена upstream SDK installation policy без решения владельца.

## Decisions

Отдельный pinned Ubuntu24.04 target container2CPU/3GiB. Начальные prerequisites
только transport (curl/CA); отсутствие SDK/Git/Nvim/user caches фиксируется до
запуска. Developer/publisher preparation разрешена в другом prepared container,
к target передаются лишь IDE artifacts/source, не языковые SDK/кеши.
Production root entry/native frontend запускается в PTY существующим подходом;
SDK actions выбираются явно по поручению владельца, с native package commands.
First failure сохраняется. Исправления поведения требуют отдельного FIX/change;
полный end-to-end повтор только после цельного исправления блока, не каждой правки.
Успешный kit проверяется прежними installed observers. Artifact hashes/готовность
SDK/tool paths и mutation boundaries остаются production checks.

## Risks / Trade-offs

Большой network/setup →2CPU/3GiB, logs F, finite process deadlines, без host SDK.
APT SDK может оказаться несовместим с IDE tools → фиксировать actual failure,
не подставлять prepared SDK и не объявлять cold PASS.
GUI libs/Terminal в minimal container → отличать console install от GUI gate.
Native Windows/macOS SDK installation нельзя доказать Linux контейнером →
отдельные простые команды и native результаты владельца.
