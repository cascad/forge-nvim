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

После commit — два installed Lua файла с проверкой исходных bytes и backup,
без hot reload/остановки owner session. Receipt, installed-source native control
и новый package candidate фиксируются отдельным дополнением после доставки.
