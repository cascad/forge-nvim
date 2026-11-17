# Design

## Context

См. proposal. config.start уже использует native Neovim :restart и Persistence
с сохранением layout/views. Адаптеры вызывают go/cargo по имени. GoToolchain
меняет GOTOOLCHAIN текущего процесса; installed_versions смешивает SDK и wrappers.

## Goals / Non-Goals

**Goals:** явный выбор существующей среды процесса, пассивный старт,
bounded async validation/discovery, rollback при отказе и реальные UI E2E.

**Non-Goals:** установка/обновление SDK, менеджер окружений, отдельные SDK homes,
правки адаптеров, Python/Node selector и бесшовная смена уже работающих процессов.

## Decisions

- User stdpath(config)/sdk.json и project .fride/sdk.json, version1/sdks go/rust
  со строковым root/executable либо auto. Отсутствующий project key наследует user;
  project auto явно выбирает исходную среду. Запись атомарная, ошибочный файл не
  затирается. SDK configs независимы от IDE tools.json.
- Early Lua module читает только settings/filesystem до plugins. Explicit Go
  выбирает bin/GOROOT/GOTOOLCHAIN=local; Rust — bin/RUSTUP_TOOLCHAIN и compiler
  paths. Сохраняется baseline только затрагиваемых env keys через native restart;
  SDK homes/cache/auth не меняются. Auto восстанавливает inherited baseline.
- Target project передаётся через restart environment до init, чтобы plugins
  не успели стартовать со SDK прежнего проекта. Existing config.start использует
  ту же подготовку при project switch; одинаковый проект допускается только
  для явного SDK apply. Modified buffers сохраняются прежним session механизмом.
- UI использует существующие vim.ui.select/input. Discovery по PATH, штатным
  SDK directories, rustup home и saved choices; filesystem enumeration bounded,
  CLI только по явному menu, timeout, max2 concurrent probes. Проверки задают
  GOTOOLCHAIN=local/RUSTUP_AUTO_INSTALL=0 только своим subprocess.
- Apply проверяет running DAP/Neotest/Overseer/terminal до restart, вместо их
  скрытого завершения. Можно сохранить для следующего запуска без restart.
  Neotest использует public client.running_positions через существующий consumer;
  одних асинхронных UI status_counts недостаточно для этого guard.
- Полный independent SDK executable API потребовал бы adapter patches;
  native process environment решает выбранную владельцем задачу без них.

## Risks / Trade-offs

- Restart требует поддерживающего UI → native TUI уже работает; E2E использует
  session_tui, а не headless restart emulation.
- Две среды в одном процессе → применяем только через явное reopen; проектный
  переход восстанавливает baseline, не исходный selected PATH прошлого проекта.
- Missing SDK после сохранения → source-aware error и отказ применения,
  без молчаливого выбора другой версии; auto доступен для исправления.
- Go module требует более новый SDK → native ошибка при explicit local;
  selector не скачивает другую версию; Auto сохраняет исходные project rules.
- Discovery Go отключает GOENV/GOWORK/GOFLAGS только для read-only probe:
  сохранённый GOROOT не должен выдавать другую установку за проверяемую.
- Native Windows Rust/MSVC может оставить VCTIP. Только SDK E2E явно разрешает
  проверенный MSVC helper внутри своего Job и закрывает Job после native exit0;
  неизвестные процессы и обычные session controls сохраняют строгий drain.
