# Tasks

## 1. Явные SDK actions

- [x] 1.1 Добавить TTY menu, existing path/CLI fallback, зависимый skip/cancel/final review; final report/result и launcher metadata. Проверка:12 selectors Windows/Ubuntu, native launch/venv/upgrade/cancel.
- [x] 1.2 Добавить flat native manager recipes, отдельный confirm, tee log, retry/recheck/refresh без false success. Проверка: native fixture manager no-confirm/fail/exit0-no-SDK/success; readiness11 и UI13 controls; real managers не запускались.
- [x] 1.3 Обновить docs/roadmap/FIXLOG §247 (Спека: IDE-BOOT-19 (ADDED)), HISTORY/AGENT_COMMANDS. Проверка: raw/staged prefix и frozen SDK/pins/WIP; explicit Mac/real installer gates.
- [x] 1.4 Исправить пойманный Windows EPERM: bounded native sharing-lock retry и unchanged permanent rollback. Проверка: source RED и2 PASS deny-delete E2E tests/install-locks.test.py, адресный UI control PASS; FIXLOG §248 со «Спека: IDE-BOOT-20 (ADDED)» и HISTORY.

## 2. Итерация

- [x] 2.1 Подготовить native UI Windows/Ubuntu из pinned sources, один целевой прогон и адресные повторы после изменений, strict validate и exact local commit. Проверка: receipts/raw reports/diff; SDK stand payload cleanup, без publish.
