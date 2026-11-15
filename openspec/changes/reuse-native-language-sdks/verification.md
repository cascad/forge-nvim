# Verification

## Результат

IDE-BOOT-17 реализован для managed setup/probes/launch. SDK policy удалена,
XDG не меняется, NVIM_APPNAME=fride задаёт штатный отдельный namespace.
Config/binary/logs/temp остаются kit-owned; config выбирается через -u/rtp.
Lazy lockfile/rtp и Open config получают root actual Lua source, не stale env.
Старые kit data/sdk-state сохраняются без миграции. SDK installs не выполнялись.

| Среда | Source RED | SDK/context/Lazy | Launcher controls |
|---|---|---|---|
| Windows | 1 RED на GOPATH,18.994s | 6 PASS35.585s + latest case07 PASS17.824s | 7 PASS34.530s |
| Ubuntu24.04 | 1 RED на GOPATH,6.953s | 6 PASS/1 Windows-only skip9.579s; latest case07 PASS3.373s | 6 PASS6.551s |
| macOS | Не запускался | Native запуск владельцем открыт | Не запускались |

## Доказательства

- .tests/native-sdk-reuse-red-windows.txt, windows-v1/v2/v3.txt,
  lazy-windows*.txt, controls-windows.txt.
- .tests/ubuntu/native-sdk-reuse-red-ubuntu.txt, ubuntu-v1.txt,
  controls-ubuntu.txt; .tests/native-sdk-reuse-lazy-ubuntu-v2.txt.
- sdk-env.jsonl, operation/caller/lazy/sdk-state-summary JSON в
  .tests/install-isolation/<id> и .tests/ubuntu/install-isolation/<id>.
- Native Go/Rustup/compiler/npm/Python queries внутри/вне fride совпали;
  настоящая project venv используется. Original SDK configs не меняются
  от setup/launch. Native Lazy reset сохраняет фактический lockfile/config.

Промежуточные fixture FAIL не удалены: Windows PATH native append, повторный
mkdir профиля и loadplugins=false от -u NONE. Ubuntu outer driver exit1 —
финальный cat с CR после обоих успешных suites; raw controls OK прочитан
отдельно, script приведён к LF без повторения неизменных tests.

## Границы

Это native launcher/SDK-context и native Lazy acceptance с fixture init/setup
и пустым plugin inventory, не установка всей IDE на чистую машину. Каталог
release artifacts пуст. Историческую closure с node-runtime/go-runtime ещё
предстоит заменить native prerequisites с предложением установки и выбором
пользователя; UX изучается отдельно по VS Code/IntelliJ IDEA. Новый provider,
SDK manager или публичная поставка не добавлены. Mac/GUI/full release открыты.

SDK/pins/backports/чужой WIP и raw/staged journal prefixes проверяются в
.tests/native-sdk-reuse-audit.json. Own stand runtime/archive copies1.72GiB
удалены, manifests/receipts сохранены; canonical SDK/cache и proofs не удалены.
