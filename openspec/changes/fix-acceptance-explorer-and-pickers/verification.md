# Проверка IDE-150

2026-11-22, source6a0b4f6, Windows private Neovim0.12.2 и Ubuntu24.04
official Neovim0.12.2. macOS и физические keys/GUI владельца не проверялись.

## Причины и ограничения

- Source palette RED: 12 Ctrl+J/K дают12 дополнительных пробелов. Причина —
  selection_caret=' ' совпадает с началом entry_prefix='  '; native update_prefix
  заменяет недостаточно символов. Теперь caret='> ', upstream не патчился.
- Read-only RPC живого fride: Files, tree root D:/rust_repo, cwd D:/rust_repo/lab;
  этот_файл.txt уже присутствует в позднем render и на диске, не Git-ignored.
  Точная причина исходной временной невидимости не доказана.
- Nested Git fixture после navigate_up скрывает реальные файлы по status/ignore
  родительского repo. Files теперь без Git-ignore и Git decorations, generated
  hide_by_name/обычные .ignore фильтры сохраняются. Git source не менялся.
- Space E запрашивал implicit reveal уже после фокуса дерева, когда native
  get_path_to_reveal возвращает nil. Путь снимается из editor window заранее;
  native navigate callback восстанавливает выбор после async render.
- Первый callback отбирал фокус у нового input: Windows A regression дал E21.
  Теперь focus_node(...,true) не меняет фокус. Отдельный held-native-IO тест:
  source без true RED (neo-tree вместо popup), исправление GREEN на обеих ОС.
- Попытка show_path=absolute для c сломала короткое имя копии (оба OS RED).
  Изменение полностью отменено. c сохраняет штатный путь относительно каталога
  source; y/x→p остаются основным способом копирования/перемещения.
  Initial source test также ошибочно стирал prefilled project/ при relative add;
  fixture исправлен полным путём, это не считалось продуктовым исправлением.
- Deprecated reveal_current_file API была проверена в промежуточной попытке и
  удалена; конечный код использует native navigate/command.execute/renderer API.

## Результат

Один affected packet из12 suites на ОС и только failed/affected повторы.
Итоговый aggregate: **59 unique cases на каждой ОС**:
navigation5, file-explorer7, copy-delete9, scan-order8, filter2, buffers8,
Files-session1, project-session2, active-worktree2, worktree-refresh3,
focus-command-order6, filesystem-errors6. Первые красные логи сохранены;
итоговые file-explorer7 и typed-copy1 заменяют упавшие случаи, не считаются
дополнительными unique cases. После добавления описания gR повторён только
searchable-keymaps case. Новый navigation suite зарегистрирован в общем e2e.

Артефакты: `.tests/acceptance-navigation/{windows,ubuntu}-packet.json`,
`*-affected.json`, `*-keys-final.log`, source RED и screenshots/shutdown profiles.
Временные host файлы на F; Ubuntu — собственный контейнер с task label,
без запуска/перенастройки Docker Desktop или WSL.
Strict PASS, trace9 PASS, syntax4 PASS; append-only журналы,66 pins,
6 backport groups/17 файлов,4 frozen SDK files не изменялись.
Gate проверил60 завершённых editor profiles на каждой ОС: exit0, без hard kill,
owned scope inactive. Это включает промежуточные failed и affected repeats.
Первый расширенный keys-test неверно использовал Telescope Ctrl+U (preview scroll);
fixture заменён закрытием/повторным открытием поиска, итог1 PASS на обеих ОС.

Полный regression, native Mac, исходный GUI-сценарий владельца и IDE-149
не объявляются пройденными. Нужна повторная приёмка create/copy/move на lab
после перезапуска fride; дополнительные зависания расследовать отдельно.

## Доставка

Code commit **88b2006**. Два installed Lua файла в F:/apps/fride/config/forge
сверены с6a0b4f6 и заменены только после backup
F:/apps/fride/backups/navigation-20261122-88b2006. Нет hot reload/остановки
owner session; SDK/backports/plugins прежние. Installed-source navigation5 PASS;
config-origin и5 shutdown receipts проверены. Всего gate подтвердил125 profiles.

Свежий candidate `.tests/acceptance-installer/windows-navigation-fix/install.cmd`
собран с clean-source88b2006,2520 manifest files сверены по SHA256.
Manifest SHA256: `485b55e70025af152e02a6aaa29e114666b1f229fdb0daad4db5c17a36ffde06`.
Default print-plan: prepare_languages=false, tools_versions=preserve.
Native runtime:3 probes,33 parsers/117 queries, fzf ABI PASS.
Receipt/metadata: .tests/acceptance-navigation/installed-delivery.json и
final-candidate.json. Собственный контейнер222ff23d… проверен по ID/task label
и процессам (только docker-init/sleep), удалён; повторный docker ps пуст.
Desktop/WSL не перезапускались. Для обновления текущего owner процесса нужен
обычный перезапуск fride; новая установка не требуется.

## Дополнение IDE-151: русская раскладка

Code **a7cf782**. Sourcebf8b100: bare пК PASS, explicit п<S-К> FAIL;
native lookup с production langmap требует g<S-К>. Общие aliases теперь
покрывают bare/shifted/mixed варианты. Исходный raw event владельца не записывался;
физические keys в его WezTerm остаются ручной приёмкой.

Один affected packet Windows/Ubuntu: native key engine2, editor navigation5,
focus6, ownership46 —59/ОС. Это отдельные59 случая этого блока, а не повтор
полного предыдущего packet. Trace9, syntax5, strict, append-only и frozen4 PASS;
11 editor profiles/ОС завершены exit0/scope inactive. Installed-source root1
также PASS, config-origin подтверждён, clean shutdown; всего23 observed profiles.
Артефакты .tests/ru-root/gates.json, *-packet.json, installed-root.log.

Два файла config/ru_keys.lua и config/keymaps.lua в F:/apps/fride сверены
с bf8b100 и обновлены с backup ru-keys-20261122-a7cf782. Owner process не менялся.
Свежий candidate **windows-layout-fix** clean-sourcea7cf782,2520 SHA entries
проверены; manifest `1ab961f7bd722ae169eacff541e91d4f3698838e6d7252d6ad889a9e7298bfc0`.
Default plan сохраняет prepare_languages=false/tools_versions=preserve.
Runtime hashes совпадают с проверенным windows-navigation-fix, поэтому native
Core/Terminal probes повторно не запускались. Receipt/delivery-final.json содержат
hashes, backup и installed profile. Собственный container1ce6ad23… удалён после
проверки ID/task/ps; повторный docker ps пуст. Desktop/WSL прежние.

Owner live read-only: Node найден, Pyright не найден, Mason pyright отсутствует.
Логи объяснены, tools не устанавливались. Владелец решил сохранить текущие
hidden filters. По его просьбе создан docs/OWNER_TESTED_HOTKEYS.md: реальные
использования/PASS/отказы отдельно от выбранных keys и автотестов.
