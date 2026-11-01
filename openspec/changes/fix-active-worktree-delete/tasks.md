# Tasks

## 1. Удаление активного worktree и подготовка

- [x] 1.1 Сохранить реальный Git cwd repro и исходный UI red; проверить CLI на Windows/Ubuntu, данные сравнения оставить в tests/diagnostics и FIXLOG.
- [x] 1.2 Реализовать общий временный патч с pin/SHA, apply/check/revert CLI и Lazy build; проверить CLI E2E (повтор, CRLF, неизвестный payload/revision, отмена) на Windows/Ubuntu, описать явную подготовку.
- [x] 1.3 Включить патч в prepare_editor/Docker и проверки provenance editor/ConPTY; проверить подготовку и отказ неподготовленного профиля без изменения исходников на Windows/Ubuntu.
- [x] 1.4 Добавить real editor регресс удаления чистого текущего worktree, dirty cancel/commit/delete и следующего visit; проверить Windows/Ubuntu, Mac оставить непроверенным.
- [x] 1.5 Дописать FIXLOG §96 со строкой `Спека: IDE-GIT-7 (ADDED)`, HISTORY, PROBLEMS, roadmap, руководство Git/E2E и команды; проверить ссылки и сохранение прежнего префикса FIXLOG.

## 2. Интеграция

- [x] 2.1 Прогнать Git/worktree/deleted-file/editor регресс и quick на Windows/Ubuntu, строгую OpenSpec validate и git diff --check; сохранить точные результаты. Открытые IDE-031/035 и Mac/GUI не объявлять исправленными.

После завершения проверок закоммитить шаг. Windows full был прерван по
IDE-036; оставшиеся unit/trace/ConPTY завершены отдельно после reboot,
результаты и границы сохранены в FIXLOG §96–97, это не цельный full PASS.
