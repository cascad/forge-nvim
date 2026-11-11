# Spec Delta

## Purpose

Клавиатурные copy/delete в Files сохраняют несохранённый текст и управляют
реальными файлами через существующий backend, с понятной отменой и повтором.

## ADDED Requirements

### Requirement: IDE-FILE-3 Безопасный normal delete из Files

Normal d в Files SHALL сохранять loaded modified file buffers, включая
скрытые, если цель — этот файл или содержащий его каталог. Проверка SHALL
выполняться до подтверждения и перед фактическим удалением после Yes.
При dirty цели команда SHALL отменять удаление с понятным WARN о save/
явном Discard и повторе; файлы, текст и modified state MUST NOT меняться.
Чистая цель SHALL удаляться через штатное подтверждение/backend; Esc/No
SHALL отменять его. Zoom SHALL использовать действительно выбранную строку.
Общий строковый prefix соседнего пути MUST NOT считаться descendant.
Корень дерева MUST NOT удаляться через normal d; native refusal сохраняется.

Платформы: все.
Проверка: tests/e2e/file-copy-delete.test.lua (IDE-FILE-3).

#### Scenario: Несохранённый выбранный файл
- **GIVEN** autosave штатно выключен и файл содержит несохранённую правку
- **WHEN** пользователь нажимает d в Files
- **THEN** файл и тот же modified buffer сохранены, показан WARN
- **AND** после явного save повтор с Yes может удалить чистый файл

#### Scenario: Скрытый изменённый descendant и соседний prefix
- **GIVEN** hidden modified buffer внутри выбранного каталога
- **WHEN** пользователь пытается удалить каталог
- **THEN** каталог/descendant/текст сохраняются
- **AND** чистый соседний каталог с общим prefix можно удалить отдельно

#### Scenario: Изменение при открытом подтверждении
- **GIVEN** подтверждение удаления чистого файла уже открыто
- **WHEN** реальный buffer становится modified до ответа Yes
- **THEN** Yes не удаляет файл/буфер, правка сохраняется, показан WARN

#### Scenario: Чистое удаление и отмена
- **WHEN** пользователь отменяет normal d через Esc/No
- **THEN** цель и соседние файлы сохраняются
- **WHEN** подтверждает чистую file/directory цель, в том числе из zoom
- **THEN** удаляется выбранная цель, соседние файлы и раскладка остаются рабочими

#### Scenario: Корень дерева
- **WHEN** пользователь выбирает корень Files и нажимает d
- **THEN** native отказ сохраняет проект и файлы без confirmation удаления

### Requirement: IDE-FILE-4 Native copy сохраняет source

Files y/p и c SHALL копировать данные source на диске в выбранное место,
включая Unicode/пробелы и каталоги, без изменения source path/content или
его modified buffer. Полученная копия SHALL редактироваться независимо.
Cancel и отказ занятого имени MUST NOT перезаписывать существующие файлы.
Это baseline существующего native copy, не новый filesystem backend.

Платформы: все.
Проверка: tests/e2e/file-copy-delete.test.lua (IDE-FILE-4).

#### Scenario: Copy file и directory через clipboard
- **WHEN** пользователь копирует файл/каталог y и вставляет p в другую папку
- **THEN** реальные данные скопированы, source/несохранённый текст сохранены
- **AND** запись новой копии не меняет исходник

#### Scenario: Copy с именем и отмена
- **WHEN** пользователь вводит новое имя через c
- **THEN** создаётся независимая копия с введённым именем
- **WHEN** отменяет c или конфликт занятого имени
- **THEN** source и занятый target остаются без изменений
