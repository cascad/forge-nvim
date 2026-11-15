# Verification

## Результат

Plan.components и native_sdks разделены; SDK IDs не нужны в private artifacts.
Есть --check-sdks/--sdk-report и actual preflight до catalog/download/target
writes. PATH/version queries bounded2s; Go/Rustup auto-download выключен только
для probes и explicit IDE setup. Обычный launcher не меняется.

| Среда | SDK/preflight | Delivery | Native UI |
|---|---|---|---|
| Windows | 10 PASS18.372s + native venv1 PASS8.037s |16 PASS69.051s |12 PASS/1 stale assertion FAIL34.144s; исправленный CSV case1 PASS8.419s |
| Ubuntu24.04 |9 PASS/1 platform skip5.939s + native venv1 PASS6.176s |16 PASS13.814s |13 PASS9.485s |
| macOS |Не запускался, owner native gate |Не запускался |Не запускался |

Source Windows: semantic RED — готовый host Node всё ещё требует архив
node-runtime;1 FAIL31.305s, дополнительно teardown обращался к удалённому
fixture good_node (исправлено). Source Ubuntu: тот же semantic RED1 FAIL4.720s,
без teardown error. Source Windows повторно ради чистого RED не запускался.

## Доказательства

Raw .tests/native-prereqs-*.txt и .tests/ubuntu/native-prereqs-*.txt.
Stand .tests/install-isolation/<id> и host .tests/ubuntu/install-isolation/<id>:
sdk reports/probe logs, argv/exit, SDK env marker, HTTP paths, runtime manifests,
Node/IDE tool output, UI raw frames, SDK/runtime/UI summaries. Windows native
frontend SHA158e43a28cc46170425e31a661ed9948a78a2a25a4965bc3e4bf939809305ed8;
Linux SHA f8dc25de88298f61aeec8bb99e95d7442ecb37f2d7c15611335b4d2428bbd540.
Build receipts содержат normalized source hashes, Cargo.lock не менялся.

Core/SDK fixtures используют настоящий Neovim/frontend, native child processes
и localhost HTTP. Timeout/error SDK — маленький native single-process Rust
fixture. Node и venv — настоящие. Global installs/downloads SDK не выполнялись.
Runtime fixture содержит небольшой IDE tool; Node SDK не копируется в архив.

## Границы

Ready — базовая CLI availability/version response; npm entrypoint только
проверяется на наличие. Нет обещания совместимости всех пакетов и project
versions. Только PATH, без registry/full disk discovery. Interactive выбор
пути/штатной установки/skip/cancel — следующий отдельный срез §245. Release
catalog пуст, полный clean-machine install/publication и native Mac открыты.

Frozen24 inputs, SDK/pins/backports/user WIP и append-only journals проверяются
в .tests/native-prereqs-audit.json. Own payload/archive copies1.42GiB удалены,
metadata98 refs сохранены; proofs/source/canonical SDK/cache не удалены.
