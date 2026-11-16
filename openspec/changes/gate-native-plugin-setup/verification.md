# Verification

2026-11-16, IDE-BOOT-30 / FIXLOG §260.

- Windows native Lazy/Git7 PASS6.659s; Ubuntu7 PASS1.875s. Local fixture repos,
  настоящие clone/checkout/build; lock/config/environment сохранены. До final
  fixture исправлены URL normalization, LF bytes и own writable Lazy help tags.
- Legacy coordinator7 PASS Windows3.913s / Ubuntu10.991s. Это отдельный уровень,
  не замена настоящим plugins и установленному consumer.
- Actual Windows source/frontend/Core: first cold новый gate отклонил known
  backports; successful retry/final new target проверил67 source pins/backports,
  33 native parsers, LuaLS3.19.2/StyLua2.6.0. Source/installed lock byte-identical,
  plugin log final без init errors. Существующие actual clones переиспользованы,
  final не объявляется повторным cold download67 repos.
- Installed consumer: Files и keyboard C-p/main.lua PASS, native LuaLS attach
  PASS. Workflow RED на diagnostics20s; log показывает preload plugin libraries.
  Content grep/edit/save/restart ещё не дошли до проверки. Следующий пункт плана
  — устранить этот preload; full Core не считается PASS.
- Отдельный --case missing Windows PASS: обычный startup не ставит временно
  убранный grug-far, lock сохранён; plugin возвращён в own profile.
- Orphan bee socket после scoped LSP exit остановил один retry EACCES; точечное
  удаление отклонено automatic review, файл оставлен, final target новый. Поведение
  обычного пользовательского выхода этим не установлено.
- Linux only existing image/engine, network none2CPU/2GiB. Native Mac/full Ubuntu
  Core/GUI/Default/notices/publication остаются открытыми. Baseline specs не sync.

Raw evidence и команды — FIXLOG260/AGENT_COMMANDS168; frozen25 и raw/staged
append-only journal prefixes проверяются перед exact local commit.

После code review добавлен guard locked plugin, отсутствующий в loaded spec:
Windows адресные01+08:2 PASS2.339s (остальные7 ранее PASS), Ubuntu8 PASS2.166s.
Таким образом8 разных native plugin сценариев прошли на каждой ОС.
