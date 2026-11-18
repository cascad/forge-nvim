# Verification — 2026-11-18

## Implementation

IDE-BOOT-43 и согласованный MODIFIED IDE-BOOT-22: native mason-tool-installer
condition сохраняет установленные pinned packages при preserve; baseline
использует обычный pinned spec. Unpinned packages сохраняют штатное поведение.
Setup передаёт одинаковую policy в build guard и postconditions; receipt/name/
required exports/files всё ещё обязательны. Strict API для publisher прежний.
Frontend/root CLI --tools-versions preserve|baseline, plan/review/log. Parent env
не выбирает baseline, Go build consent остаётся отдельным.

## Native evidence

Один affected batch каждой ОС: Windows1795008886439389100 (157.2s),
Ubuntu1795008897029427886 (96.32s). Три registry-файла и шесть Python suites:
tool_versions, test-batch, trace; install-tool-versions, install-go-toolchain,
install-ide-tools, install-ui, install-profile, install-sdk-settings.
Остальные suites прошли сразу. Новый fixture не создавал state для Mason log:
1 PASS/7 FAIL на каждой ОС. После mkdir повторены только семь failed cases:
Windows7 PASS59.022s, Ubuntu7 PASS5.965s. Первичные FAIL logs сохранены.

Совокупный результат последних cases: Windows89 PASS/2 informational SKIP;
Ubuntu85 PASS/6 SKIP. Включает77 native Python cases и12 registry checks;
Ubuntu4 native SDK/platform skips. Composite:
.tests/toolchain-research/tool-versions-composite.json.
Windows root case после нормализации PowerShell enum дополнительно21.998s PASS
с -ToolsVersions BASELINE. Это адресная проверка изменённого root entry.

Новые8 native cases используют реальный Rust binary с releases v1/v2,
локальный HTTP, настоящий Mason GitHub provider/MTI/InstallReceipt и production
setup-stage/private Neovim. Проверяют missing baseline, ручную v2 через Mason,
повтор без release requests/изменения receipt и binary, explicit downgrade,
повреждение export/receipt, preview, root flag и invalid CLI. Binary запускается
для проверки версии. Registry checks: startup не загружает registry; preserve
готового Go tool не требует compiler. Реальный UI собран из текущих sources
на обеих ОС, без замены прежнего .tools payload.

## Bounds

Это проверка политики manager на native fixture, а не full Default delivery
или совместимости любых пользовательских LSP версий. Native macOS открыт;
проверки других ОС его не заменяют. Общий regression checkpoint не повторялся.
Требуется отдельный Default/Custom acceptance и publication. Повреждённый пакет
той же версии восстанавливается штатным Mason, без нового repair manager.

Frozen SDK/locks/backports/старый UI проверены; tests/registry.lua имеет только
новую строку unit case. Журналы сохраняют прежние raw/staged prefixes.
MODIFIED22 ссылается на ещё active prepare-managed-ide-tools: strict advisory
о незасинхронизированном base не означает archive этого предшественника.
