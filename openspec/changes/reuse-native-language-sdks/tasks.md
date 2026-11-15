# Tasks

## 1. Исправление границы IDE / SDK

- [x] 1.1 Удалить SDK-wide redirects из install-private.lua и managed launchers, сохранив IDE isolation и штатные SDK defaults, включая XDG. Проверка: Windows7 cases, Ubuntu6 PASS/1 platform skip; Mac отдельно владельцем.
- [x] 1.2 Заменить прежние SDK-state assertions регрессами inherited/unset SDK settings, активной venv, repeat со старыми sdk-state файлами и Windows caller restoration. Проверка: source RED обеих ОС, Windows/Ubuntu native SDK и Lazy traces сохранены; реальные global installs не выполнялись.
- [x] 1.3 Обновить SDK_STATE, installation plan и историю: причина излишней изоляции, изменение и результаты; append-only FIXLOG §244 со строкой «Спека: IDE-BOOT-17 (ADDED)», AGENT_COMMANDS и HISTORY. Проверка: raw prefix journals и точный git diff; пользовательский WIP/SDK/pins не меняются.

## 2. Согласованность и продолжение плана

- [x] 2.1 Проверить strict OpenSpec и зафиксировать локальный коммит исправления. Проверка: strict validate, staged allowlist, git status.

Следующий отдельный срез IDE-138: изучить VS Code и IntelliJ IDEA и спроектировать native SDK discovery/предложение установки с выбором пользователя. Он записан в INSTALLATION_PLAN и не реализуется автоматически в этом исправлении.

Продолжено после команды владельца «дальше». Принят штатный NVIM_APPNAME=fride с данными приложения вне InstallPath; код и Windows/Ubuntu регрессы реализованы. Native Mac остаётся отдельной проверкой владельца.
