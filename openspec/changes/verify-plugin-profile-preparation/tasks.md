# Tasks

## 1. Подготовка установленного профиля

- [x] 1.1 Windows actual inventory67/16, backup и offline restore двух clean
  revisions; общий CLI apply/check успешны, lock прежний, действия сохранены на F.
- [x] 1.2 Добавить native case в plugin-backports.test.lua; один legacy3 source
  и один all-declarations target на Windows. Проверить Files/Tests/Locals,
  notifications/install0 и отсутствие записи patch при открытии.
- [x] 1.3 Исправить QUICKSTART/README/patch guide, дописать FIXLOG222/HISTORY/
  commands, записать IDE-131/132; strict/diff/prefix/frozen guards и commit.

В исходной итерации §222 Ubuntu/Mac не запускались: владелец работал в IDE, тяжёлые
параллельные suites исключены. Новый case переносим через прежний editor helper;
actual platform PASS сообщается только по выполненному Windows запуску.


Исторический результат Windows §222:1.2 оставался открытым. User profile apply/check успешны,
target Files/Tests открылись, но весь native case FAIL на Locals/60s watchdog
(IDE-133). Legacy source остановился на nvim_ui_attach, не на точном Neo-tree
assert; фактический source config error — stacktrace владельца. Source/target
не повторяем ради зелёного. Инструкция/история готовы; commit всего шага пока
не был выполнен. SDK/deadlines/pins прежние, Rust/Files жалобы записаны IDE-131/132.

Продолжение §226: документация сохранена в a9758ed. Новый bounded stage probe
прошёл; затем без native hooks legacy3 дал точную config ERROR Neo-tree, общий
setup открыл Files/Tests/Locals без ERROR/install/adapter/patch writes. Windows
и Ubuntu по source1 RED → target1 PASS. Ubuntu проверен отдельно plain-text
case при ready engine, без language builds или Docker lifecycle. Все задачи
данного setup среза выполнены; причина исторического IDE-133 не установлена.
