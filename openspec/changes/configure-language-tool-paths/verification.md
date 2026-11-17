# Проверка

2026-11-17. Windows, private native Neovim, prepared editor/Node deps и обычные
Python/Git Bash. SDK не скачивались; Python venv создан с --without-pip в own runtime на F.

- Финальный целевой запуск IDE-BOOT-33: 4 passed, 0 failed, 0 skipped.
- Источник: .tests/toolchain-research/paths-windows-final.txt; каждый случай
  содержит свой .tests/editor-e2e path со снимками и native stderr.
- Initial run выявил только ошибку сравнения Windows separator в тесте;
  targeted rerun и финальный набор прошли. Панельный контекст дополнительно
  проверен при смене проекта и повторном ForgeToolPaths.
- Foreign ID при отсутствующих Node deps: ожидаемый exit0/0 cases;
  .tests/toolchain-research/paths-foreign-filter.txt. Это guard, не acceptance.
- Source behaviour: никакой установки/probe в startup/report, native SDK env
  не переназначается; ошибки explicit path не продолжают discovery.
- Ubuntu после запуска engine владельцем:4 PASS/0 FAIL/0 SKIP;
  .tests/toolchain-research/paths-ubuntu-final.txt. Cached backports обновлены
  офлайн в own copy. Snapshot исключает derived venv с symlinks, реальные
  interpreter/prefix сохранены отдельно. Native Windows targeted legacy/venv:1 PASS.
- macOS: не запускалось, native прогон владельцем по docs/TOOL_PATHS.md.

Контроль коммита: отдельная registry delta без включения прежнего WIP,
raw/staged journal prefixes, frozen25 (registry с вычетом собственной строки),
Markdown/local links, OpenSpec strict и git diff --check.
