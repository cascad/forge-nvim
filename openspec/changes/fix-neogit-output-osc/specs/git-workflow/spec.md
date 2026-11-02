## Purpose

Вывод Git в терминальной IDE сохраняет читаемую причину ошибки и текст,
отделяя служебные последовательности терминала от пользовательских данных.

## ADDED Requirements

### Requirement: IDE-GIT-12 Вывод Git без OSC metadata
Редактор SHALL показывать текст Git в уведомлениях и истории команд без
метаданных завершённых OSC title/hyperlink последовательностей с BEL или ST.
Видимый текст, UTF-8 и обычные пути SHALL сохраняться; очистка не меняет
результат Git, local/remote refs или возможность повторить операцию.
Платформы: все
Проверка: tests/e2e/git-errors.test.lua (native fatal, Git hook и parser matrix) | tests/e2e/plugin-backports.test.lua (явная подготовка/read-only проверка)

#### Scenario: Неудачный push с title
- **WHEN** Git возвращает ошибку недоступного origin и OSC title рядом с выводом
- **THEN** уведомление и история содержат причину ошибки без title/BEL
- **AND** после исправления origin обычный retry отправляет исходный commit

#### Scenario: Цветной hook и hyperlink
- **WHEN** настоящий Git hook отклоняет push, печатая цветной UTF-8 текст, OSC title и hyperlink
- **THEN** причина, текст ссылки и обычный путь читаются без OSC metadata
- **AND** remote остаётся прежним, после исправления hook повтор проходит

#### Scenario: Соседние OSC и UTF-8
- **WHEN** в строке чередуются OSC с BEL/ST, видимый текст и UTF-8 рядом с ASCII
- **THEN** видимые участки и UTF-8 сохраняются без захвата текста между OSC

#### Scenario: Явная подготовка существующего Neogit
- **GIVEN** worktree backport уже установлен, output companion ещё исходный
- **WHEN** пользователь выполняет явный build
- **THEN** проверенная версия companion готовится, обычное открытие Git файлы не пишет
- **AND** неизвестный companion отклоняется до изменения любого файла
