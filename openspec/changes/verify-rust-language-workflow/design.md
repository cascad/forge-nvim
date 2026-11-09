# Design

## Context

Мотивация в proposal.md, baseline 047f827. Существуют rust_analyzer config,
rustfmt, codelldb с Cargo target resolution и preLaunchTask, neotest-rust.
Последний использует cargo-nextest/JUnit, а не обычный cargo test; наличие
cargo не доказывает готовность Tests. На host есть полный Rust 1.96.1 с rust-src.

## Goals / Non-Goals

Проверить обычный Cargo workspace реальными процессами/UI и сохранить
воспроизводимое evidence. Не заменять Rust plugin stack, не обновлять system
SDK, не проверять cross-compile/remote attach/макросы внешних crates; shell
startup и прежние Ubuntu Git проблемы не входят в этот change.

## Decisions

1. Host SDK выбирается явно/через rustup which, затем запускаются настоящие
   binaries из sysroot, без shim auto-install. Версии/host/sysroot/hash записаны
   в manifest; требуется rust-src/rustfmt/clippy. Изоляция CARGO_HOME и offline
   workspace запрещает скрытую загрузку dependencies и пользовательский config.
2. CodeLLDB 1.12.2 и cargo-nextest 0.9.151 из официальных release archives,
   committed platform SHA256; Rust parser по revision pinned Treesitter.
   --download — только явная подготовка, повтор без флага проверяет готовность.
   Альтернатива host adapter не даёт переносимого воспроизводимого pin.
3. Workspace из двух local crates; app с main/bin/example, библиотека и unit/
   integration tests. Нет внешних dependencies. Исходники с пробелом/Unicode,
   соседний fail-marker исключает ложный nearest PASS; target/cache отдельно
   в private runtime, не копируются в snapshots.
4. Пользовательские действия идут через клавиши/команды; публичные LSP/cmp/
   diagnostics/DAP/Neotest/Overseer данные и logs служат наблюдением. Rust
   compiler, analyzer, formatter, nextest, debugger не подменяются. Target
   предварительно не собирается: F5 обязан выполнить настоящий preLaunchTask.
5. Любой подтверждённый runtime failure оформляется отдельным change/ID/source
   replay; fixture/версии не меняются ради сокрытия сбоя. Неизвестный fault
   не объявляется причиной по одному зелёному повтору.

## Risks / Trade-offs

- Host SDK/linker различаются: manifest и compile probe до UI; Windows MSVC
  requirements проверяются без установки Visual Studio. macOS/Linux используют
  native compiler SDK владельца; platform PASS только после фактического запуска.
- Rust indexing/check и сборка асинхронны: ожидания результатов, не sleep.
  Cargo jobs=2 ограничивает нагрузку; тяжёлые suites последовательны.
- Старый neotest-rust и новые nextest/Cargo: сначала real FAIL, затем отдельный
  fix при необходимости. Не откатывать версии ради обхода ошибки.
- Ubuntu engine недоступен: подготовка image/команды отдельно, задача проверки
  остаётся открытой; Mac/GUI не объявляются PASS.
