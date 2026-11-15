# Design

## Context

Canonical components.tsv остаётся legacy API с hidden node-runtime/go-runtime. Native frontend может отделить SDK prerequisites в plan, не ломая platform scripts. Default install уже gated пустым release catalog. SDK context §244 сохраняется.

## Goals / Non-Goals

**Goals:** отдельные SDK requirements, native CLI readiness и actionable отказ до IDE artifact download; read-only report API; delivery готового IDE tool с обычным Node.

**Non-Goals:** SDK manager/install recipes, project-wide выбор SDK, новые LSP, UI install/path/skip действия. Они следуют отдельным срезом §245. Проверка не обещает совместимость CLI со всеми версиями Mason tools.

## Decisions

- Plan.components содержит только IDE parts, native_sdks — SDK IDs. Legacy closure вычисляется прежним resolver и затем проектируется в два списка.
- Go требуется Go/SQL tools; Node — JS/Python/Bash tools; Python — Python; rustc/cargo — Rust. SDK IDs не являются artifact IDs и отклоняются в catalog/composition/package API.
- Discovery ограничено PATH (Python aliases/platform alternatives), без disk scan. Запускаются только version commands, npm определяется по доступному entrypoint. Windows Store aliases не запускаются. stdout/stderr записываются в own logs, timeout2s, ограниченный текст в JSON. Go auto toolchain и Rustup auto-install отключены в probe и installation subprocess, не в обычном launcher.
- --check-sdks выдаёт JSON и exit2 при missing/unavailable, не запускает backend. --sdk-report позволяет явно сохранить report. Preview/print-plan не проверяют SDK. Actual install выполняет тот же preflight до catalog/downloads.
- Пустой Core SDK set не создаёт отчёт по умолчанию. При отказе plan target не трогается, host SDK не устанавливается; сообщение предлагает выбрать существующий SDK/установить штатно/убрать зависимый компонент и повторить.
- Runtime stand хранит маленький IDE JS tool part и использует готовый host Node, не пакует язык. Старые failure gates SHA/platform/conflicts/rollback сохраняются.

## Risks / Trade-offs

- Ready означает базовый CLI доступен и отвечает ожидаемой версией, не полный release compatibility. Требования конкретных tools и project versions остаются inventory gate.
- Выбор собственного пути и штатной установки пока делается вне frontend; interactive SDK actions — следующий отдельный пункт, не выдаются за готовые.
- Native Mac запуск владельцем; Windows/Ubuntu native frontend/query/transport E2E выполняются здесь.
