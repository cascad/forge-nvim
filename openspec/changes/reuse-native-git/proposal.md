# Proposal

## Why

После §256 остаётся Git prerequisite Core: installer проверяет языковые SDK, но может дойти до clone/setup без рабочего Git. IDE-138 и выбранная граница изоляции требуют переиспользовать обычный Git с его настройками/credentials; новый контракт IDE-BOOT-27 закрывает обнаружение и явное предложение штатной установки.

## What Changes

- Core проверяет native Git до загрузки IDE artifacts/setup; preview ничего не запускает.
- При missing/unavailable Git — выбор существующего каталога, установка штатным менеджером с подтверждением, recheck или cancel. Git не пропускается как необязательный язык.
- CLI readiness для tools и --tool-path alias используют существующие discovery/path/manager механизмы.
- Native Windows/Ubuntu E2E проверяют реальные Git/config/launcher и controlled manager flows без host installs.

## Capabilities

### New Capabilities

- `native-git-prerequisite`: обычный Git как обязательная внешняя зависимость Core.

### Modified Capabilities

Нет; baseline specs посвящены WezTerm/macOS installer.

## Impact

Frontend discovery/actions/native package recipes, targeted E2E, журнал и installation plan. Git не входит в private artifacts; обычные конфиги/auth/SSH/profile/SDK не переназначаются. Native Mac и full Default остаются отдельными gates.
