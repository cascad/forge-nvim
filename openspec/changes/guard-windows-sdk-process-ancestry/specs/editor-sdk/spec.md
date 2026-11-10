## ADDED Requirements

### Requirement: IDE-BOOT-6 Проверяемая граница Windows process ancestry

Windows SDK SHALL рекурсивно завершать процесс по связи PPID только при доступном времени создания обоих процессов и времени child не раньше parent. Явно выбранный root завершается и при недоступном времени; более старый процесс или процесс с неизвестной хронологией не завершается через такую связь.
Платформы: windows
Проверка: tests/diagnostics/process-ancestry.py, tests/e2e/process-lifecycle.test.lua, tests/e2e/windows-sdk.test.lua, tests/e2e/editor-descendants.test.lua
Это дополнение IDE-BOOT-3 заменяет прежнее ограничение единственным ConPTY patch на два закреплённых patch: ConPTY и process ancestry.

#### Scenario: Устаревшая связь PPID
- **GIVEN** snapshot связывает более старый процесс с новым процессом, переиспользовавшим parent PID
- **WHEN** SDK завершает дерево нового root
- **THEN** более старый процесс сохраняется, настоящий более поздний child завершается
- **AND** неизвестное время parent/child не разрешает рекурсивное завершение

#### Scenario: Настоящие jobs Neovim
- **GIVEN** настоящий Neovim запустил job с живым child и независимым worker
- **WHEN** вызывается jobstop или редактор нормально завершается
- **THEN** root и child job завершаются, независимый worker сохраняется
- **AND** собственные процессы fixture убираются, native exit равен нулю

#### Scenario: Явная подготовка и замена SDK
- **GIVEN** Windows builder и закреплённые source revision и два patch hash
- **WHEN** выполняется scripts/prepare-windows-sdk.ps1
- **THEN** новый SDK собирается отдельно и проверяется native ancestry и Neovim lifecycle/ConPTY probes до замены выбранного SDK
- **AND** неуспешная подготовка сохраняет байты прежнего SDK, успешная сохраняет его каталог для отката
- **AND** StageOnly оставляет проверенного кандидата отдельно без замены

#### Scenario: Пассивная проверка готовности
- **GIVEN** Windows launcher или test entrypoint
- **WHEN** manifest старого формата, отсутствует process probe либо не совпадают закреплённые process patch/source hashes
- **THEN** SDK не запускается, выводится команда явной подготовки
- **AND** обычный запуск не собирает/скачивает SDK, не управляет Docker или WSL
- **AND** Linux/macOS по-прежнему используют официальный Neovim
