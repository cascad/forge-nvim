# Проверка IDE-BOOT-12

## Windows

- .tests/fride-windows-v1.txt:23 cases,2 FAIL/2 ERROR. Register cases обнаружили ложный PATH conflict на cwd; поздний conflict abort оказался раньше setup. Observer terminal.json перезаписывался driver JSON, хотя UI child уже принял ввод и вернул7.
- .tests/fride-windows-v2.txt:23 cases,3 FAIL/1 ERROR. Разделение отчётов исправлено; vim.split trimempty убирал только крайние empty entries. В native PATH найден внутренний пустой segment42, explicit cwd entries отсутствовали. Новая проверка setup failure исключила ложный PASS от раннего отказа.
- .tests/fride-windows-v3.txt:23 PASS,73.447s. Empty Windows entries пропускаются явно; POSIX сохраняет cwd semantics. Проверены canonical/legacy/full names, args/cwd/environment, настоящий PTY и ввод :cquit7, checkout CMD/PS1 и регистрация с Unicode/apostrophe/$ в путях, bare-name lookup, repair/repeat/conflicts/setup rollback.
- .tests/fride-policy-before.json: read-only negative probe Exit1/ExternalScript при ExecutionPolicy Restricted — bare fride выбирал fride.ps1 и блокировался до запуска. User/system policy не менялась.
- Исправление: вне kit публикуются fride.cmd и скрытый .fride-command.ps1, поэтому bare fride разрешается как Application. .tests/fride-windows-policy.txt:7 affected cases PASS,32.095s, включая новый case24 с Restricted, exit7. Старые unaffected cases не повторялись ради зелёного.
- Shared keyboard observer controls: .tests/fride-ui-controls-windows.txt,2 PASS.

## Ubuntu

- Ready Docker28.5.1/image без build/pull/lifecycle; после Windows, native work FS /tmp, evidence export в .tests.
- .tests/fride-ubuntu-v1.txt:24 cases,22 PASS/2 Windows-only skip,10.664s.
- Первый UI-controls driver path отсутствовал в overlay (.tests/fride-ui-controls-ubuntu.txt,exit2 до tests). Driver скопирован в host .tests/ubuntu, правильный guest path /workspace/.tests/fride-ui-controls.py: .tests/fride-ui-controls-ubuntu-v2.txt,2 PASS.

## Границы

Настоящий native Neovim, SDK/hash/package/bootstrap/install/launch и PTY. Init/setup callbacks — fixture, не full Default SDK acceptance. Чужие файлы/профили/SDK сравниваются, за исключением явно выделенного native PowerShell StartupProfileData cache до script entry. Регистрация выполнялась только внутри private stands, host PATH/registry/profile не изменялись. Native Mac пока не запускался. UI LocalVox и полная доставка SDK остаются IDE-138/141. Main specs/lock/payloads/frozen test drafts не менялись, release/push не выполнялись.
