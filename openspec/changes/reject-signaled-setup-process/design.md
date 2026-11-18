# Design

## Decisions

Использовать оба публичных поля vim.system result: code и signal. Успех только
code=0 и signal=0/nil. Не пересчитывать POSIX signal в shell exit128+signal.
Сохранить прежний префикс Command failed (code) для существующих logs/controls;
добавить signal. Проверка до publication общая для probes и трёх setup stages.

Native fixture child завершает только собственный PID через uv.kill(SIGKILL).
На Windows этот POSIX сценарий SKIP, обычный cquit13 проверяется native.
Предыдущие runtime/config/bin/owner snapshots, запуск и command registration
должны сохраняться. Реальные SDK/runtime изолированы в существующем stand.

## Non-Goals

Новый process manager, реконфигурация Docker/WSL, убийство host процессов,
автоматический retry, изменение runtime package policy и full Default.
