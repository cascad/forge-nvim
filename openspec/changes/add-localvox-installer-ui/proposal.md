# Proposal

## Why

IDE-141 требует единый установщик в стиле localvox-light. Сейчас Custom рисуется независимо в PS/Bash, а подготовка показывает необработанный backend output. Нужен IDE-BOOT-13: общий готовый frontend без Rust/Cargo/Neovim/Python на машине пользователя до доставки комплекта.

## What Changes

- Native frontend fride-setup на закреплённом cliclack, с темой/навигацией LocalVox: компоненты, пути, регистрация команды, Back/Cancel и итог.
- Default и explicit component flags остаются автоматическими; Custom требует TTY. No-color/plain вывод, безопасный preview без backend.
- Frontend вызывает существующий private backend, показывает его stages и сохраняет полный лог; ошибки/exit не маскируются.
- Root entries выбирают подготовленный frontend из локального SDK либо автоматически получают проверенный artifact по manifest. Пользователь не собирает frontend.
- Общая TSV components остаётся источником состава. Прежний source без frontend marker сохраняет advanced совместимость, новый source требует готовый UI artifact.
- Native PTY regressions, безопасный developer preview и build/package команды с cache/temp на диске workspace.

## Capabilities

### New Capabilities

- `installer-ui`: единое оформление и frontend установки, безопасный preview, delivery contract.

### Modified Capabilities

Нет. IDE-BOOT-10/11/12 сохраняются; не переносим package manager/модели LocalVox.

## Impact

Небольшой Rust crate, UI delivery helpers, root dispatch и progress events private backend, существующие profile/isolation stands и отдельные UI scenarios. Native Mac и опубликованные UI/полные runtime artifacts остаются release gates, а не автоматически закрываются сборкой Windows frontend.
