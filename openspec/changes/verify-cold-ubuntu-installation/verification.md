# Verification — §290, 2026-11-19

## Actual cold baseline

Pinned Ubuntu24.04 digest из tests/containers/Dockerfile, отдельный target
abeab62ce0e0ad0a836d8dceb0e4bcfe198ced057a17ecb65ea1297d15af7a32,
2CPU/3GiB. Host stand `.tests/cold-install/1795073324804404800` смонтирован
на /stand. Перед root entry установлены только curl/CA transport dependencies;
baseline.log заканчивается COLD_BASELINE_OK: нет git/nvim/go/rustc/cargo/
python3/node/npm/nextest, Cargo/Rustup homes, kit и fride data/cache.

Native publisher80a7a7eebd57f659d3c87ce64e10906c978f8253a751af78868d635b51ba3213
подготовил настоящие Core16MB/Terminal64MB/frontend artifacts в другом container.
В target не передавались SDK, Mason packages или prepared plugins. Source archive
собран из tracked working tree с временными catalogs; artifacts/source/entry SHA
и frontend source receipt проверены. HTTP обслуживает только собственный
publisher в Docker bridge, без публикации host port. Root install.sh/native
frontend/SDK actions выполняются через настоящий UI-attached PTY.

## Findings

1. Стандартный HTTP Ubuntu mirror на этом подключении задерживал downloads.
   Первый Git action превысил180s observer deadline. Download прерван до dpkg;
   package sources того же target переключены на HTTPS, подписи/версии сохранены.
   Git установился штатным APT. Это transport/observer, не product fix.
2. Observer сначала принимал промежуточный review после Git за последний.
   Обработчик теперь продолжает SDK groups до exit; raw suffix читается внутри
   RPC, не пересылается весь накопленный output каждые20ms. Старый attempt
   ui-https.json сохранён; новый resume-1795074131668583100.json прошёл Git/
   Go/Rust и дошёл до Python. SDK transactions между attempts не дублировались.
3. Native APT поставил Go1.22.2 и Rust/Cargo1.75.0; rustfmt и rust-src отсутствуют
   (sdk-observed.txt, apt simulation). Delve1.27.2 из actual §289 receipt требует
   Go>=1.25: [upstream compatibility](https://github.com/go-delve/delve/blob/v1.27.2/pkg/goversion/compat.go).
   SDK version header сам по себе не доказывает работоспособный язык/debug.
4. Python APT action остановился на tzdata Geographic area prompt. --yes
   подтверждает пакетные операции, но не отвечает debconf. Лог sdk-install и
   последний PTY screen сохранены; это actual unattended-install gap.

Ни cold Default PASS, ни language/runtime acceptance не заявляются. Target
намеренно остановлен после evidence/exact owner check; --rm удалил контейнер,
PTY exit137 относится к этому stop, не к падению Neovim/IDE. Все SDK writes
происходили внутри disposable target, не на host. Publisher пока оставлен для
следующей цельной реализации; Desktop/WSL/чужие containers не менялись.

## Owner decisions and follow-up

Владелец выбрал official Go + rustup для отсутствующих SDK, с сохранением готовых
установок. Затем изменил момент подготовки: fride устанавливается без обязательных
Go/Rust; первый соответствующий файл предлагает install/existing/later.
Зависимые IDE tools также откладываются, иначе они неявно потребовали бы SDK.
Подготовка асинхронна, edit доступен, предложения не повторяются на BufEnter.

Следующий change `defer-language-environment-setup` фиксирует это поведение;
он заменяет немедленное исправление eager APT recipes. Строгая проверка готовых
tools сохраняется, readiness различает основу IDE и отложенные языки.
После реализации — новый cold origin, first-file workflow и один итоговый
affected/regression пакет. Общий full сейчас не запускался. Native Windows/
Mac/WSL/GUI/publication остаются отдельными проверками.

## Reproduction

Developer native archives готовятся существующими package-core-runtime.py /
prepare-terminal-runtime.py / build-installer-ui.py. Target получает только
их готовые результаты. В owned publisher с label fride.owner=cold-publisher
artifacts смонтированы на /artifacts, repo — /workspace, prepared inputs —
обычный тестовый image. На host нужны Docker Linux engine и prepared native
test Neovim; runner Desktop/WSL не запускает.

```powershell
python -B tests/diagnostics/check-cold-install.py --artifacts .tests/cold-install/artifacts --publisher-container <publisher-id>
```

Для diagnosis --keep сохраняет только собственный target. По умолчанию он
останавливается после capture; source/SDK/probe/UI/process logs остаются на F.
Это explicit network diagnostic, он не добавляется в каждый quick/E2E запуск.
Native artifact catalogs репозитория остаются пустыми: это локальный release-like
stand, не публичный one-liner и не доказательство macOS/Windows чистой установки.
