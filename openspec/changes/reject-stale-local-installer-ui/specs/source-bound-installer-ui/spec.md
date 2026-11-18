## ADDED Requirements

### Requirement: IDE-BOOT-46 Frontend выбранной версии source

Root installer SHALL выбирать frontend по platform digest из catalog выбранного
source, а не по одному наличию local .tools binary. Локальная копия MUST
переиспользоваться только при совпадении с этим digest. Explicit developer path
SHALL сохранять прежнее поведение. Без catalog/override MUST быть явная ошибка.
Платформы: все.
Проверка: tests/install-ui-source.test.py, tests/install-sdk-settings.test.py.

#### Scenario: Устаревшая локальная сборка

- **GIVEN** local checksum валиден, но digest отличается от source catalog
- **WHEN** root installer получает source
- **THEN** он загружает frontend source catalog и не запускает старую копию
- **AND** новые user SDK/settings semantics source сохраняются

#### Scenario: Совпадающий кэш

- **WHEN** local checkout binary или download cache совпадает с catalog digest
- **THEN** она переиспользуется без download и без изменения исходной копии

#### Scenario: Нет публикации

- **WHEN** catalog не содержит artifact платформы и нет explicit override
- **THEN** старая local binary не запускается, показан developer способ explicit path
- **WHEN** explicit UI path задан
- **THEN** используется эта осознанно выбранная binary без нового compiler/dependency
