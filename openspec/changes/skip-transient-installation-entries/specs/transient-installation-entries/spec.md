## ADDED Requirements

### Requirement: IDE-BOOT-47 Повтор с временными OS ресурсами

Повторный private setup SHALL проверять границу kit/tmp, но не обходить его
временное содержимое. Оставшийся или активный IPC socket внутри tmp MUST не
блокировать setup. Foreign link самой tmp границы и постоянных entries MUST
по-прежнему давать отказ до внешних записей. Временные ресурсы MUST не удаляться.
Платформы: все.
Проверка: tests/install-transient-entries.test.py.

#### Scenario: Сокет после работы

- **GIVEN** установленный kit имеет AF_UNIX node в tmp после закрытия редактора
- **WHEN** выполняется повтор
- **THEN** он завершается успешно, launcher работает, настройки/SDK не меняются
- **AND** socket не читается и не удаляется

#### Scenario: Активный IPC

- **WHEN** в tmp существует ещё открытый socket другого процесса
- **THEN** ownership walk не обходит его и не нарушает endpoint

#### Scenario: Граница и постоянные файлы

- **WHEN** tmp root либо persistent subtree содержит foreign junction/symlink
- **THEN** setup отказывает по прежней policy и внешние файлы прежние
- **AND** runtime/config/bin и их hash/ownership проверки не пропускаются
