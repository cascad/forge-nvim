## Context

IDE-139, см. proposal.md. Native Mason registry is_installed проверяет только directory. Package:get_receipt() возвращает Optional, receipt описывает bin links; InstallLocation даёт штатные пути. Neovim language.add возвращает nil/error для отсутствующего/незагружаемого parser. Плагины pinned, .tests/editor-deps используются readonly.

## Goals / Non-Goals

Goals: postconditions после setup commands и сохранение exit/log, единый существующий состав, Source RED и native Windows/Ubuntu regression.
Non-Goals: новый installer/registry, per-tool flags --version, новые LSP, полный SDK assembly/readiness всех функций, изменение startup.

## Decisions

- Вынести нынешние fallback lists Mason/парсеров в один forge.tool_catalog, сохраняющий install_profile.filter и Windows CodeLLDB exception. Конфиг и validation используют один источник, новые tools не добавляются.
- Tools проверяет native registry package:is_installed/get_receipt/InstallLocation; каждый объявленный bin/share/opt source и export должен существовать, bin export должен быть executable. Schema1.0 Windows suffix учитывается как в самом Mason. Не считать host PATH или пустой каталог успехом.
- Parsers: runtime file presence и vim.treesitter.language.add; native API проверяет пригодность библиотеки, без собственного компилятора/ABI parser. Fresh stage process — прежний контракт.
- Ошибки агрегируются по selected именам и выбрасываются существующему setup xpcall. Success report пишется в stdout. Check не вызывает registry.refresh/download и не исполняет адаптеры с произвольными аргументами.
- Stand использует настоящий Mason Lua registry provider, native receipts/locations и parser libraries. Install callbacks контролируемые: моделируют nonthrowing failure; функциональная пригодность SDK проверяется отдельной языковой матрицей. Старый orchestration stand получает согласованный минимальный native fixture.

## Risks / Trade-offs

- [Receipt/bin наличие не доказывает всё поведение LSP/DAP] → это postcondition установки; native language SDK E2E и inventory остаются отдельными gates.
- [macOS недоступен] → тот же native stand выполняется владельцем, Linux не выдаётся за Mac.

## Migration Plan

Неполная подготовка теперь даёт отказ вместо done. Обычный startup и прежние lists не меняются. Private installer не публикует staged kit после ошибки. Старые журналы сохраняются, каждое исправление имеет отдельную запись.
