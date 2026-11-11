# Files: копирование и безопасное удаление

`Space w e` открывает дерево, `Space E` показывает текущий файл. Действия
ниже — normal mode в Files; `g?` открывает штатную справку, `?` — общую.

| Действие | Клавиши |
|---|---|
| Создать файл / каталог | `a` / `A` |
| Переименовать / переместить | `r` / `m` |
| Копировать в другую папку | `y`, выбрать папку, `p` |
| Копировать с новым именем | `c`, ввести имя, `Enter` |
| Вырезать / вставить | `x`, выбрать папку, `p` |
| Удалить файл или каталог | `d`, затем `y`, `Enter` |
| Отменить удаление | `n`, `Enter` либо `Esc` |
| Отменить ввод имени | `Esc` |
| Вернуться в код | `Space w 0` / `F7` |

`c` предлагает имя в текущем каталоге. Занятое имя не перезаписывается:
Neo-tree предлагает другое имя, `Esc` отменяет. Копируется версия файла
на диске; несохранённые правки исходного буфера остаются в нём.
Копию можно редактировать и сохранять независимо. Копирование каталогов
сохраняет вложенные файлы, Unicode и пробелы в именах.

Перед удалением Files проверяет загруженные буферы с несохранёнными правками,
включая скрытые. Если правка относится к цели или файлу внутри каталога,
операция отменяется с предупреждением. Сохрани файл (`:write`) либо открой его
и явно выбери Discard при закрытии буфера (`Space b d`), затем повтори `d`.
Files не сохраняет и не отбрасывает этот текст автоматически.

Проверка повторяется после Yes: изменение при уже открытом диалоге тоже
сохраняется. Для чистой цели используется штатное подтверждение. Вопрос
для каталога явно включает всё содержимое. Корень дерева сохраняет штатный
запрет удаления. Команда из zoom работает с выбранной там строкой после
возврата в source window.

## Проверки и границы

`tests/e2e/file-copy-delete.test.lua` содержит9 native UI сценариев:
clipboard file/directory, typed copy/conflict/cancel, чистый file delete
с Esc/No/zoom, recursive directory delete/cancel, root refusal, modified
file/save/retry, hidden descendant/sibling prefix и late modification.
Три последних воспроизводят source RED acffa63, остальные — controls.
Для dirty cases тест штатно выключает autosave через `:ASToggle` и проверяет
public enabled=false; новый layout или fake filesystem не используется.

Из корня checkout после явной plugin подготовки:

```powershell
$env:TEMP=Join-Path (Get-Location) '.tests/tmp'
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
$env:TMP=$env:TEMP; $env:TMPDIR=$env:TEMP
$env:NVIM_LOG_FILE=Join-Path $env:TEMP 'files.log'
& .tools/neovim/windows-x64/bin/nvim.exe -l tests/e2e/file-copy-delete.test.lua
```

Ubuntu/macOS: официальный `nvim -l tests/e2e/file-copy-delete.test.lua`.
Один сценарий можно выбрать через `FORGE_FILE_CASE` (подстрока полного
названия), например `native root refusal`; после точечного запуска unset
переменную для полного набора. [Общая схема VM/контейнеров](../tests/e2e/README.md).

История и фактические результаты — FIXLOG §176–177; native Mac/physical WezTerm
GUI не считаются проверенными без отдельного запуска. Этот шаг проверяет
normal `d`, copy и изменённые buffers при delete; Trash, visual multi-select,
case-only/cross-volume операции, LSP file operations и modified rename/move
остаются отдельной матрицей. Это не завершение всех Files-возможностей.
IDE-104: controlled stale-scan механизм исправлен Windows/Ubuntu (§180).
При перекрытии full/partial обновлений сохраняются созданный файл и запрошенные
раскрытия; наблюдатели соответствуют принятому дереву. Нужна явная подготовка
existing install: `:Lazy build neo-tree.nvim`, затем restart. [Детали и снятие
временного backport](../nvim_forge/patches/README.md#neo-tree-согласованный-snapshot-и-ожидающие-раскрытия-ide-104).
Исторические untraced failures сохранены; Mac/physical GUI остаются открытыми.

Native фильтр дерева: `f`, ввести имя и `Enter`; `Ctrl-X` очищает фильтр.
Очистка возвращает раскрытия до поиска. IDE-105: исключённые фильтром папки
больше не вызывают повторный scan; filter/clear проверяются отдельным E2E.
