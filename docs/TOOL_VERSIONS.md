# Версии IDE tools

Повторная установка по умолчанию сохраняет установленные Mason packages,
включая версии, выбранные вручную. Недостающие packages устанавливает обычный
Mason provider: закреплённую fride версию, если она есть, иначе штатную версию
registry. Startup не запускает install/update или сканирование packages.

Готовый tool, явно выбранный в пользовательском tools.json, удовлетворяет setup
вместо Mason package — и при preserve, и при baseline. Его package не меняется,
receipt не требуется; path/JS prerequisites проверяются отдельно.
[Поддерживаемые ключи и область setup](TOOL_PATHS.md#явный-setup-приложения).

Обновления/выбор версий доступны в штатном `:Mason`. Свои пути в tools.json и
SDK проекта сохраняются. Этот выбор касается Mason tools, а не plugins,
Neovim, Go/Rust/Node/Python или системных пакетов.

Для осознанного возврата **закреплённых** версий есть отдельный режим frontend:

```text
fride-setup --source REPO --runtime-path CORE --components go --tools-versions baseline
```

`--tools-versions preserve` — обычный режим. Root entry передаёт `-ToolsVersions`
на Windows и `--tools-versions` на Linux/macOS. План/лог показывают выбор.
Это developer frontend новой версии; public Default artifacts ещё не опубликованы.
Для tools без закреплённой версии baseline не превращается в произвольный
rollback или массовое обновление. Загрузка Go build toolchain требует своего
отдельного [allow/deny](GO_BUILD_TOOLCHAIN.md).

Preserve сохраняет проверки receipt, source/exports и нужных файлов. Пакет с
повреждённым receipt/export не становится готовым. Исправление повреждений
выполняется штатными действиями Mason; выбор версии не является автоматической
переустановкой повреждённого пакета той же версии. Preserve также не обещает
совместимость любой пользовательской версии с любым проектом.

Внутри используется native condition mason-tool-installer, проверяемый только
при явной установке; собственной системы обновлений нет. Postcondition API
сохраняет strict baseline по умолчанию для publisher и диагностики, а setup
явно передаёт preserve policy. Готовые Go tools не требуют build compiler
из-за одного различия с baseline.

Native E2E: `python -B tests/install-tool-versions.test.py` (Linux/macOS: python3),
с подготовленным frontend/Mason. Реальные releases тестового native tool v1/v2
проверяют manager policy; это не full Default и не матрица совместимости LSP.
[Фактические результаты](../openspec/changes/preserve-installed-tool-versions/verification.md).
