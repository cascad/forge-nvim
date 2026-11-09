# Design

## Context

Мотивация — proposal.md. Исходный runtime — 6988af1; pyright/ruff и Python
DAP/pytest уже настроены. Общий editor harness умеет snapshot exclusions,
готовый Node SDK можно переиспользовать для официального npm Pyright.

## Goals / Non-Goals

Проверить семантику и реальные процессы на project venv без предварительной
активации shell. Не устанавливать system Python, не обновлять runtime plugins,
не перестраивать панели, не проверять Conda/Poetry/uv managers в этом шаге.
Баг не обходится тестовой конфигурацией: сначала RED/ID/delta, затем fix.

## Decisions

1. Host Python >=3.10, его версия/архитектура и pip фиксируются в manifest.
   Новый SDK не нужен: пользователь обеспечивает interpreter целевой машины.
2. Pinned pytest 9.2.0/debugpy 1.8.22/Ruff 0.17.3 и полная wheel lock с hashes;
   setuptools 80.9.0/wheel 0.45.1 только обеспечивают offline build dependency
   fixture. Npm Pyright 1.1.414 использует подготовленный Node 24.11.0 и lock,
   не Python wrapper, который может готовить собственный Node окружением.
3. prepare_python.py готовит tools venv/wheelhouse/npm/parser и настоящую
   dependency wheel явно с --download. Повтор без флага проверяет готовые
   данные; private project venv создаётся из wheelhouse offline до старта UI.
4. Неактивированный .venv, unique local package, пробел/Unicode и src/tests
   исключают ложный PASS на глобальном interpreter/site-packages. PATH tools
   исключает пользовательские pyright/ruff binaries, runtime pip offline.
5. Только UI-клавиши для пользовательских действий, публичные clients/cmp/
   diagnostics/Neotest/DAP данные и logs для наблюдения. Никаких server mocks,
   прямых private handlers и тестовых overrides project interpreter/config.
6. Snapshot сохраняет source/pyvenv metadata/lock/hash/result; .venv/cache
   исключены, runtime очищается finally. Ubuntu готовится в существующем image
   явно; engine сейчас недоступен. Windows/Ubuntu heavy suites последовательны.

## Risks / Trade-offs

- CPython minor/ABI различаются → wheel hashes всех опубликованных wheel
  вариантов + manifest фактически выбранных файлов, только compatible wheels.
- Async LSP/UI и format-after-save → ожидания реальных результатов/записи,
  а не наличия mapping/config. Положительный test включает собственный cwd/env.
- Неизвестная совместимость pytest/debugpy/adapter → исходный FAIL и отдельный
  runtime change; version downgrade не используется для сокрытия бага.
