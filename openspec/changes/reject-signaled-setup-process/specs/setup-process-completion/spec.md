## ADDED Requirements

### Requirement: IDE-BOOT-44 Отказ при завершении подготовки сигналом

Private installer SHALL считать process result с ненулевым signal ошибкой,
даже если code равен нулю. Отказ probes либо setup stages MUST запрещать
publication нового комплекта и сохранять прежний работающий комплект.
Платформы: все; POSIX signal scenario Linux/macOS.
Проверка: tests/install-process-exit.test.py.

#### Scenario: Первый setup прерван сигналом

- **WHEN** plugins, parsers либо tools child завершён сигналом
- **THEN** установщик возвращает ошибку с code/signal и путём к log
- **AND** launcher и ready marker нового комплекта не публикуются
- **AND** последующие этапы не запускаются, внешняя команда не регистрируется

#### Scenario: Прерванная повторная установка

- **GIVEN** прежний комплект установлен и работает
- **WHEN** очередной setup child либо runtime probe завершается сигналом
- **THEN** прежние runtime/config/bin/owner сохраняются и launcher работает
- **AND** причина и stdout/stderr child доступны в logs

#### Scenario: Обычный выход

- **WHEN** native child завершается ненулевым code без signal
- **THEN** прежний отказ и диагностика сохраняются
- **WHEN** все probes/stages завершаются code0 без signal
- **THEN** обычная установка и повтор остаются доступны
