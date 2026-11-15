# Spec Delta

## Purpose

Сделать публикацию подготовленного комплекта устойчивой к кратковременной Windows file-sharing блокировке, сохранив ограниченное время ожидания и прежний rollback.

## ADDED Requirements

### Requirement: IDE-BOOT-20 Временная блокировка staging на Windows

Installer SHALL ограниченно ожидать освобождения Windows rename lock; постоянная ошибка MUST завершать установку без ложного success и сохранять прежний комплект.
Платформы: windows; другие ОС сохраняют обычный atomic rename.
История: FIXLOG §248.
Проверка: tests/install-locks.test.py с настоящим deny-delete handle.

#### Scenario: Transient lock
- **WHEN** файл staged runtime кратковременно открыт без FILE_SHARE_DELETE
- **THEN** rename повторяется ограниченно только для Windows sharing/permission/busy ошибок и продолжается после освобождения

#### Scenario: Persistent lock
- **WHEN** блокировка не снимается в течение1.5s
- **THEN** установка сообщает ошибку, rollback восстанавливает прежние runtime/config/bin
- **AND** установщик не закрывает чужие процессы и не меняет ACL
