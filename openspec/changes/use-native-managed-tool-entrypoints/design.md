# Design

## Decisions

Обобщить существующий Node LSP setup для ts_ls/pyright. Native root callback
сохраняется; для declarative root_markers используется штатный vim.fs.root.
Существующий before_init/settings Pyright остаётся. Command — Node executable
и npm entry langserver.index.js со stdio; выбранные Node/tools.json honored.

При Windows PATH .cmd в Mason bin либо отсутствующем PATHEXT resolution читать
только receipt своего пакета через native InstallReceipt/InstallLocation API.
Возвращать существующий .exe из exports. Нормальный внешний PATH/explicit wrapper
не менять; registry/network/installation отсутствуют. Receipt reads только по
запросу executable, а не при объявлении каталога. BashLS использует штатные
shellcheckPath/shfmt.path, Sqruff/Conform общий resolver.

## Non-Goals

Новый LSP/formatter, изменение SDK PATH глобально, замена upstream packages,
частная правка Mason registry, source patches адаптеров, nightlies или FFI.

## Evidence

Initial installed observer имел также test defects: RPC nil truthiness,
90s child lifetime и принудительный Cargo offline для незакэшированного rust-src.
Они исправляются отдельно в test-only verify-installed-language-consumers;
не выдаются за product bugs. Native runtime gaps проверяются отдельно.
