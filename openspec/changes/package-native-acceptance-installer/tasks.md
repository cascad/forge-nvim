# Tasks

## 1. Native publisher и локальная установка

- [x] 1.1 Добавить явную подготовку pinned official POSIX Neovim; Linux/macOS policy, native version probe и repeat без downloads. Проверка — tests/install-native-neovim.test.py и native Ubuntu actual asset, macOS отдельно; инструкции в ACCEPTANCE_INSTALLER.
- [x] 1.2 Собрать local acceptance package существующими runtime/manifest/frontend contracts, добавить native entrypoints и проверки current source/SHA. Проверка — tests/install-acceptance-package.test.py: настоящий native frontend plan/argv, missing/tamper/conflicts/private source controls Windows/Ubuntu, native Mac открыт; инструкции в том же guide.

  Packaging/entrypoints и Custom Core-only готовы:10 package cases/ОС и3 native
  install/launch/foreign-files controls/ОС PASS aggregate. Владелец выбрал готовую
  native fzf library в Core и Lua fallback. Завершение включает publisher ABI
  probe и реальные setup/search E2E без CMake, плюс affected setup controls — PASS.
- [x] 1.3 Подготовить актуальный Windows комплект из существующих проверенных inputs и дать точную команду запуска; Mac publisher recipe с явными prerequisites/границами, без утверждения native PASS. Проверка — actual bundle/frontend preview и saved manifest/source/версии, прежние SDK/config/pins сохранены.
- [x] 1.4 Записать FIXLOG301/HISTORY/commands209/roadmap, source/pins/backports/journal guards и local commit. Один affected packet после всей реализации, только failed/affected repeats; strict/trace/syntax. Native Mac/GUI/publication остаются отдельными gates.
