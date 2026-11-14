## Context

См. proposal.md. Private installer переключает staged config/runtime/bin только после setup, хранит их под собственным root и пока создаёт forge. Windows PowerShell и POSIX shell получают окружение из существующих launch-managed scripts. IDE-141 требует fride без подмены системного nvim.

## Goals / Non-Goals

Дать реальную fride, совместимость и opt-in регистрацию, с native доказательствами. UI LocalVox, SDK delivery, изменение registry PATH/profile и переименование NVIM_APPNAME/data directory не входят в этот change.

## Decisions

- Один источник launch-managed на ОС создаёт fride/forge-nvim/forge внутри owned bin; NVIM_APPNAME=forge сохраняет существующие данные. Checkout wrappers делегируют прежним helpers.
- Root entry и private backend принимают -CommandDir/--command-dir. По умолчанию пусто, а не автоматически выбранный user bin. Если каталог уже есть в PATH, fride доступна по имени; иначе показан полный путь, сам PATH не меняется.
- Общий Lua registration module читает PATH и выбранный каталог до изменения target и повторно перед публикацией. Links и конфликты не заменяются; aliases/functions shell сохраняют собственный приоритет, дочерний installer не объявляет их полностью обнаруженными.
- Файлы регистрации создаются exclusively, без перезаписи существующих. Receipt содержит product/schema/kit и hashes точных wrapper bytes. Валидный повтор — no-op; недостающий собственный файл можно восстановить, изменённый файл/другой kit дают отказ.
- CMD wrapper вызывает соседний .fride-command.ps1, абсолютный kit path хранится в PS single-quoted literal с UTF8 BOM для Windows PowerShell5.1. Имя fride.ps1 вне kit не публикуется: иначе PowerShell выбирает его вместо CMD и блокирует запуск при Restricted. Пользовательская policy не меняется. POSIX path shell-quoted, argv передаётся через "$@", без eval. Это защищает обычные пути с Unicode/пробелами/apostrophe/$.
- Setup failure не создаёт внешнюю команду. Ошибка регистрации возвращает nonzero; созданные этим вызовом собственные файлы убираются, ранее существующие не пишутся. Коммит config/runtime/bin восстанавливается при ошибке публикации.

## Risks / Trade-offs

- [Не видны aliases/functions родительской shell] → их не меняем, сохраняем приоритет и объясняем проверку command -v/Get-Command в документации.
- [Registry/profile PATH не меняется] → пользователь явно выбирает доступный bin; full-path launcher всегда доступен.
- [Native Mac недоступен агенту] → owner gate с той же командой, Linux contract не считать Mac acceptance.

## Migration Plan

Новые launchers появляются после успешного обновления private kit. Forge и old checkout scripts сохранены. SDK/data/config не мигрируют из-за имени команды. Registrations создаются только по выбранному CommandDir; чужой fride никогда не заменяется.
