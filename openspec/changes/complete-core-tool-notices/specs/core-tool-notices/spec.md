## Purpose

Обеспечить достоверный перечень установленного состава Core и точные документы его инструментов без подмены фактических версий запрошенными опциями и без изменения пользовательских установок.

## ADDED Requirements

### Requirement: IDE-BOOT-32 Фактические версии и source-bound tool notices

Publisher inventory SHALL читать installed version/source/name/links штатным Mason receipt API, а не считать install_options.version фактом установки. При отсутствующем документе только явный --fetch-tool-licenses SHALL разрешать получение лицензии из GitHub source и закреплённой версии установленного инструмента. --license-cache SHALL переиспользовать документы только при совпадении source/version и SHA содержимого, сохраняя вложенные имена. Report MUST сохранять исходные tools/receipts/SDK environment, по умолчанию работать без сети и не считать metadata completeness полным release/native/transitive acceptance.

Платформы: windows, linux/ubuntu, macos; native Mac отдельно.
Проверка: tests/release-inventory.test.py и actual Core CLI report; FIXLOG §262.

#### Scenario: Неявная версия установки
- **WHEN** install_options.version отсутствует либо отличается от installed PURL
- **THEN** inventory показывает native installed version и проверяет pin по ней
- **AND** receipt остаётся неизменным

#### Scenario: Отсутствующий документ
- **WHEN** пакет готов, но не содержит license document
- **THEN** offline mode сообщает gap
- **AND** явный fetch получает точные bytes по source/version и сохраняет их SHA/provenance

#### Scenario: Повтор без сети
- **WHEN** передан прежний report с совпадающими source/version и документом
- **THEN** inventory использует его без сети, включая вложенные documents
- **AND** изменённый SHA отклоняется, чужой source/version не закрывает gap
