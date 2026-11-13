# Verification — 2026-11-13

IDE-GIT-13 final v2: Windows18 PASS/Ubuntu18 PASS, Git sequence3 и
plugin-backports15 по одному прогону этой версии на ОС. Mac/physical непроверены.

## Native результат

- Submit: C перед B, fixup C в A →2 commits, исходный tree/файлы/main ref.
- Abort изменённого todo → исходные HEAD/refs/tree/clean status/no rebase.
- Настоящий conflict после B перед A → ERROR/unmerged index, native abort
  возвращает исходную историю. Нет общего перехвата notification/errors.
- Windows3265078000200/3272008775000/3278388845200; Ubuntu
  703356536773/705399890672/707227988790. Native0/signal0/APIerrors[]/scope ok.
  Captured test и patches/plugins.json exact, git-sequence-final-audit.json.
- Preparation15 на ОС: LF/CRLF/apply/check/repeat/revert/unknown/real Lazy build.

## Сохранённые отказы

Source submit1923603547100 PASS, abort1972523353100 FAIL false conflict при
неизменённых Git refs/tree/HEAD. Upstream blobed8aa001 содержит старый pattern.
First target Windows2/1: genuine conflict2542895048900 сохранял ERROR/unmerged,
но test r popup открыт до обновления native status. Test wait исправлен по
видимым Rebasing/unmerged/Abort. Ubuntu variant1 abort222708347331 FAIL:
«There was» вместо «there was». V2 common lower-case comparison; no OS branch.

Old git-conflicts: Windows3 PASS/1 FAIL2633297634000 до запуска rebase,
notifications пусты/HEAD/refs unchanged; IDE-124 открыт, причина не установлена.
Ubuntu old4 PASS это не объясняет. IDE-121 также открыт. Full Windows PASS нет.
Mixed/Python final Ubuntu9 в первом combined прогоне закрывает соседний mixed
change task1.2: его Node/DAP branches exact, не повторялись после Git-only v2.

## Подготовка и границы

Existing Neogit pin d7bb91b42f984416adc6116d6ba8fba287857af3. Новый local
companion rebase.lua beforef110b2cb7e6cb9d3d679c4429ef673c0a5d84de3bc9e36b10cd3441c04007391,
afteracfa813fd5c2d1db0edd2a78bfecfaf53f249ffe2160ef09b2290a420a35360b.
Neogit3 files,6 dependencies/14 files,67 pins/Neovim SDK прежние. SDK preparation
явная local CLI; Docker ready image/private overlay, no build/network/lifecycle.
Существующей установке :Lazy build neogit и перезапуск. Удаление companion после
готового upstream equivalent + тех же3 native cases на целевых ОС.
FIXLOG211–212/HISTORY/commands121, raw prefix/draft/partial registry guards.
Push/production history/credentials не выполнялись. Далее очередь4 credentials.
