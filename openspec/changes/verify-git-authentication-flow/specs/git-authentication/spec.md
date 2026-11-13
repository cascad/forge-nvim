## Purpose

Быстрый native Push и понятный credential flow без отдельного auth manager.

## ADDED Requirements

### Requirement: IDE-GIT-14 Native Push и credentials
Редактор SHALL запускать native Git Push с клавиатуры, включая действие до
первой публикации repo metadata. Отсутствие hook metadata MUST NOT вызывать
Lua error или отключать настоящие Git hooks. Credential input SHALL скрывать
пароль; отмена и неверные credentials SHALL сохранять local/remote refs,
а повтор с верными credentials SHALL отправлять тот же commit.
Ввод Username и Password MUST передаваться Git как отдельные ответы без
дополнительного пустого ответа между ними.
Платформы: все.
Проверка: tests/e2e/git-auth.test.lua.

#### Scenario: Быстрый Push
- **GIVEN** только что открыт native Git status
- **WHEN** пользователь выбирает Push до завершения первого repo refresh
- **THEN** Git process запускается без nil hooks error
- **AND** настоящий pre-push hook не обходится

#### Scenario: Отмена и повтор
- **GIVEN** HTTP remote требует credentials
- **WHEN** пользователь отменяет Username и заново выполняет Push
- **THEN** отмена сохраняет refs, а верные credentials отправляют тот же commit

#### Scenario: Неверный пароль и исправление
- **GIVEN** HTTP remote отклоняет неверный пароль
- **WHEN** пользователь видит отказ и вводит верный пароль в native retry
- **THEN** до успеха refs не меняются, пароль скрыт, тот же commit отправлен
