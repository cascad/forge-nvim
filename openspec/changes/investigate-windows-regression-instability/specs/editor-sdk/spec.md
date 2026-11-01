## ADDED Requirements

### Requirement: IDE-BOOT-3 Проверяемый временный SDK Windows

Forge SHALL использовать подготовленный проверяемый SDK Windows через локальный nvim_forge.cmd и scripts/test.ps1; обычный старт не загружает и не собирает SDK. На Linux/macOS запуск остаётся через официальный Neovim.
Платформы: все
Проверка: tests/e2e/windows-sdk.test.lua, tests/e2e/native-probe.test.lua, tests/e2e/buffers.test.lua

#### Scenario: Явная подготовка
- **GIVEN** Windows builder с Git, CMake/Ninja и MSVC C++ Build Tools
- **WHEN** пользователь выполняет powershell -NoProfile -File scripts/prepare-windows-sdk.ps1 -Download
- **THEN** SDK собирается из зафиксированных исходников и единственного проверенного патча ConPTY
- **AND** runtime, source/build/temp остаются на диске checkout, системные Neovim и PATH не заменяются
- **AND** source revision, patch SHA256 и binary SHA256 записываются в manifest

#### Scenario: Подготовленный SDK
- **GIVEN** SDK и manifest соответствуют lock, binary SHA256 совпадает
- **WHEN** пользователь запускает nvim_forge.cmd с аргументами или scripts/test.ps1 quick/e2e/full
- **THEN** запускается проверенный SDK с целыми аргументами и сохраняется его exit code
- **AND** Forge profile и переменные дочернего процесса не изменяют родительский shell
- **AND** запуск не требует сети или компилятора

#### Scenario: Отсутствующий или повреждённый SDK
- **GIVEN** SDK отсутствует, manifest устарел или binary SHA256 не совпадает
- **WHEN** запускается Windows launcher/test entrypoint
- **THEN** запуск завершается ошибкой с командой явной подготовки
- **AND** повреждённый SDK и скрытый системный fallback не запускаются

#### Scenario: Явный диагностический override
- **GIVEN** пользователь установил FORGE_NVIM=system
- **WHEN** запускается Windows launcher/test entrypoint
- **THEN** используется nvim из PATH, без установки/перезаписи программ
- **AND** это не считается доказательством исправления native ошибки официального SDK

#### Scenario: Официальный SDK POSIX
- **GIVEN** Linux/macOS с официальным Neovim в PATH
- **WHEN** запускается nvim_forge.sh или scripts/test.sh
- **THEN** Windows manifest/build tools не требуются и аргументы передаются официальному Neovim

#### Scenario: Завершение терминала во время resize
- **GIVEN** подготовленный исправленный Windows SDK
- **WHEN** настоящий terminal заканчивает echo одновременно с серией window resize и возвратом в код
- **THEN** редактор остаётся доступным и завершает все циклы без native crash
- **AND** исходные buffer/terminal E2E проходят без ослабления ожиданий

#### Scenario: Изолированный ConPTY регресс
- **GIVEN** общий Windows runner запускает реальный ConPTY набор
- **WHEN** внутри ConPTY запускается Forge
- **THEN** используется тот же выбранный SDK и private config/data/cache/state с подготовленными pinned plugins
- **AND** исходный lazy-lock.json и пользовательские каталоги плагинов не меняются
