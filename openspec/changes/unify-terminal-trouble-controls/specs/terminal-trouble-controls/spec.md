# Spec Delta

## Purpose

Завершить общую клавиатурную модель рабочих панелей для терминала и списка проблем, сохраняя ввод, выполняемые процессы и штатную навигацию по результатам.

## ADDED Requirements

### Requirement: IDE-PANEL-17 Terminal и Trouble в общей модели панелей

Редактор SHALL предоставлять normal Space w T для открытия/фокуса managed Terminal и Space w x для Problems/Trouble. Повторный focus SHALL сохранять уже открытое окно. Normal q/Space w q SHALL скрывать текущее окно и возвращать фокус в код, сохраняя другие views и jobs. Normal Esc SHALL возвращать из zoom, иначе фокусировать код без скрытия панели. Space w z SHALL разворачивать тот же buffer и возвращать исходное окно; ?/Space w ? SHALL показывать общую помощь, q/Esc закрывать её. Заголовок SHALL показывать фокус. Terminal-input SHALL сохранять печатные символы, native escape и job/output. Native действия Trouble SHALL применять текущий выбор, включая выбор в zoom; g? SHALL сохранять штатную справку. Прежние aliases SHALL сохраняться; UI действия MUST NOT запускать DAP.

Платформы: все.
Проверка: tests/e2e/tool-panels.test.lua; Mac/GUI отдельно.

#### Scenario: Cold focus и пустой список
- **WHEN** из кода нажаты Space w T либо Space w x, затем повторены
- **THEN** виден и сфокусирован нужный компонент, повтор не скрывает окно и не создаёт новый job
- **AND** пустые Problems открываются без ошибки или запуска отладки

#### Scenario: Terminal input и normal UI
- **GIVEN** настоящий shell/job принимает текст и уже имеет вывод
- **WHEN** пользователь вводит печатные q/?/w/h, выходит в normal, открывает помощь/zoom, отменяет и скрывает окно
- **THEN** текст остаётся вводом программы, job/PID/channel и вывод сохранены
- **AND** возврат явной terminal-командой открывает прежний job, native escape и F7 работают

#### Scenario: Несколько окон
- **GIVEN** видны два managed terminal либо два Trouble views
- **WHEN** пользователь скрывает текущую панель через q или Space w q, в том числе из zoom
- **THEN** другая view остаётся видна, terminal jobs продолжаются, фокус возвращается в код

#### Scenario: Выбор Trouble из zoom
- **GIVEN** настоящие diagnostics/Quickfix содержат несколько разных результатов
- **WHEN** пользователь меняет выбор в zoom и подтверждает штатное действие либо сворачивает/раскрывает группу
- **THEN** native backend применяет выбранную строку, переход открывает правильный файл/строку, временный overlay закрыт
- **AND** help/Esc/hide и прежние Trouble aliases сохраняют результаты и не запускают отладку
