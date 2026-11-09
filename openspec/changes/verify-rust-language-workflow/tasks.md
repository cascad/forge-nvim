# Tasks

## 1. Явная подготовка

- [x] 1.1 Host Rust manifest/hash, pinned CodeLLDB/nextest/parser, F: caches; prepare_rust --download и повтор без скачивания, compile probe и команды Windows.
- [x] 1.2 Offline workspace fixtures и private runtime helper, snapshot source/logs без target; настоящий cargo metadata/build probe Windows, ограничения в E2E README.

## 2. Пользовательские сценарии

- [x] 2.1 Реальные Rust UI E2E definition/references/rename/completion/diagnostics и manual/on-save rustfmt Windows; документы по языковому workflow, отдельные ID/delta/source RED для runtime failures.
- [x] 2.2 F5 default/project, правильный workspace binary, preLaunch build, breakpoint/eval/continue/stdout/stderr Windows; user guide и evidence, отдельные changes для найденных багов.
- [x] 2.3 Nearest/file и debug test с настоящими nextest/CodeLLDB, pass/fail/output и соседним marker Windows; постоянный регресс, команды и история наблюдений.

## 3. Интеграция

- [ ] 3.1 Registry/Ubuntu image, при работающем engine явная подготовка и последовательный Rust/language/smoke регресс; без engine оставить открытой, Mac/GUI не PASS.
- [x] 3.2 Windows Python/Node/Go/smoke и unit/trace/strict, source/hash audit; append FIXLOG/HISTORY/команды/матрица/roadmap, проверенный commit и следующий пункт.
