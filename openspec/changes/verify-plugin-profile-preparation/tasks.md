# Tasks

## 1. Подготовка установленного профиля

- [x] 1.1 Windows actual inventory67/16, backup и offline restore двух clean
  revisions; общий CLI apply/check успешны, lock прежний, действия сохранены на F.
- [ ] 1.2 Добавить native case в plugin-backports.test.lua; один legacy3 source
  и один all-declarations target на Windows. Проверить Files/Tests/Locals,
  notifications/install0 и отсутствие записи patch при открытии.
- [ ] 1.3 Исправить QUICKSTART/README/patch guide, дописать FIXLOG222/HISTORY/
  commands, записать IDE-131/132; strict/diff/prefix/frozen guards и commit.

Ubuntu/Mac этой итерацией не запускаются: владелец работает в IDE, тяжёлые
параллельные suites исключены. Новый case переносим через прежний editor helper;
actual platform PASS сообщается только по выполненному Windows запуску.


Результат Windows:1.2 остаётся открытым. User profile apply/check успешны,
target Files/Tests открылись, но весь native case FAIL на Locals/60s watchdog
(IDE-133). Legacy source остановился на nvim_ui_attach, не на точном Neo-tree
assert; фактический source config error — stacktrace владельца. Source/target
не повторяем ради зелёного. Инструкция/история готовы; commit всего шага пока
не выполнен. SDK/deadlines/pins прежние, Rust/Files жалобы записаны IDE-131/132.
