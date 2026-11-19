# Tasks

## 1. Native Arch providers

- [x] 1.1 Добавить optional pacman catalog mapping, единый family routing и OS transaction/recheck/error без sync/upgrade; расширить native system fixtures/unit и проверить Windows/Ubuntu/Arch после всей реализации.
- [x] 1.2 Маршрутизировать Git/Node/Python package recipes тем же family, общий sudo boundary с сохранением APT env. При наличии Mise на Arch явный prepare SDK использует его native project config без переписывания defaults; без Mise Go/rustup и package fallback прежние. Добавить tests/install-arch-packages.test.py: provider/SDK actions/preserve/no-op/fail и actual Mise; проверить Windows/Ubuntu/Arch.
- [x] 1.3 Обновить Omarchy/installation guides, IDE-143/145/roadmap и FIXLOG294–295 (Спека: IDE-BOOT-53 ADDED), HISTORY/commands202–203; проверить ссылки, append-only и отсутствие native desktop PASS до реального прогона.

## 2. Воспроизводимые проверки и handoff

- [x] 2.1 Дать простой explicit Arch container entrypoint с pinned image/native profile/source reports, real Default/Custom missing path/Core workflow/repeat и preservation ordinary Neovim/SDK/settings; проверить настоящим CLI stand без копирования SDK/cache в target.
- [x] 2.2 Подготовить native Omarchy commands/report и tests/manual/omarchy.md O1-O8 для install/Wayland/font/clipboard/hotkeys/panels/mixed-project/Mise/native workflows; синтаксис/CLI commands проверить, реальные desktop cases оставить явно непроверенными до машины владельца.
- [ ] 2.3 Пройти O1-O8 на настоящей Omarchy VM/машине владельца, зафиксировать version/architecture/results/artifacts; container PASS не подменяет этот шаг. При отсутствии native машины — открытый blocker только этого gate.

## 3. Итоговый checkpoint

- [x] 3.1 После цельной реализации один affected packet Windows/Ubuntu/Arch и current native frontend builds; затем только failed/affected repeats. Проверить strict/trace/syntax/source manifests/frozen SDK+old UI+locks/journal/index; export evidence, cleanup exact own containers и local commit. Непроверенный Mac/Omarchy desktop явно указать.
