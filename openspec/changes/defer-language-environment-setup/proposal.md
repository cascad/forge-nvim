# Proposal

## Why

Владелец2026-11-19 изменил порядок IDE-138: устанавливать fride без обязательных
языковых SDK; при первом подходящем файле и отсутствии среды предлагать подготовку.
Cold Ubuntu §290 показал неподходящие Go1.22.2/Rust1.75 из APT и остановку Python
на tzdata. SDK должны оставаться общими средствами языка, устанавливаться только
после выбора пользователя и не блокировать редактирование.

## What Changes

- Default/Custom готовят основу IDE. Отсутствующий SDK/его зависимые IDE tools
  имеют явный отложенный статус, не объявляются готовыми и не вызывают установку
  языка до открытия подходящего файла/явной команды.
- Общий FileType workflow: локальная проверка, existing/manual/install/later,
  отсутствие повторных предложений при каждом BufEnter. Никакой сети до выбора.
- Постоянный раздел «Языки и инструменты» расширяет существующий вход Space l S:
  SDK/version/path/source, LSP/format/DAP/test readiness, install/select/recheck/
  logs. User/project scopes; later и явное отключение предложений для проекта/
  пользователя обратимы в этом разделе. Прямой ForgeSdk selector сохраняется.
- Подготовка выбранного языка асинхронно использует существующие native SDK
  actions, Mason и общий tool catalog; без переустановки работающего Neovim,
  private API или отдельного package manager.
- На новой Ubuntu Go — официальный upstream SDK, Rust — rustup с rustfmt/rust-src
  (решение владельца). Готовые SDK/версии/пути сохраняются. APT действия, где
  остаются нужны, не останавливаются на debconf timezone prompt.
- После цельной реализации — cold Core→первый файл→prepare→языковой workflow,
  cancellation/retry/repeat и один итоговый affected/regression пакет каждой ОС.

## Capabilities

### New Capabilities

- `language-environment-setup`: предложение и явная асинхронная подготовка
  среды по первому файлу, с сохранением SDK и различением ready/deferred/error.

### Modified Capabilities

Нет root IDE baseline: openspec list --specs содержит только WezTerm/macOS.
Полностью прочитаны active contracts IDE-BOOT-10/15/18. Новый контракт уточняет
границу: desired languages не равны текущему preparation mask. Старые строгие
postconditions/preflight сохраняются для явно подготавливаемого набора;
check-sdks остаётся строгим. Отсутствующие main specs не создаются через MODIFIED.

## Impact

Native frontend/private setup, shared SDK/catalog resolvers, runtime FileType/UI/
Logs, installed maintenance entrypoint и existing E2E. SDK не становятся частью
kit, готовые native binaries и штатные managers/upstream переиспользуются.
Native Mac/WSL/GUI/publication не подменяются Linux результатами.

## References

Upstream-паттерны, не буквальная копия UI:
[Python environment selection](https://code.visualstudio.com/docs/python/environments),
[Go tools commands](https://github.com/golang/vscode-go/blob/master/docs/tools.md),
[User/workspace settings](https://code.visualstudio.com/docs/configure/settings).
Общий hub — решение fride; в VS Code эти возможности разделены между UI/командами.
