# Проверка IDE-155 / IDE-FILE-11

На `8f2c7b9` точный найденный файл подтверждён через состояние picker.
Из Files `Enter` закрывал список и оставлял `file_one.txt` в редакторе.
Из окна кода тот же ввод открывал нужный файл. `.tests/file-search-enter/windows-source.log`
сохраняет 1 PASS и 1 RED.

Настроен штатный `get_selection_window` Telescope через `ide.buffers.editor_window`.
Нативный `Enter` сохраняет выбранный split кода либо переводит результат из
панели в код, сохраняя её буфер и `winfixbuf`. Поиск по тексту из Logs
открывает другой файл на конкретной строке.

Пакет `acceptance-navigation.test.lua` прошёл один раз на Windows и Ubuntu,
по 8 PASS. Логи `windows.log` / `ubuntu.log` в `.tests/file-search-enter`.
Палитра команд, Ctrl+J/K, F1, Alt+B, дерево и открытие из split проверены в том
же пакете. Strict OpenSpec и trace прошли. Native macOS остаётся для приёмки.

`F:/apps/fride/config/forge/lua/plugins/telescope.lua` обновлён из `e61742a`
после сверки с `8f2c7b9`. Резервная копия в
`F:/apps/fride/backups/file-search-enter-20261122-e61742a`. Сценарий из Files
повторён с установленной конфигурацией и бинарём. Дополнительный 1 PASS,
лог `.tests/file-search-enter/windows-installed.log`. Для рабочей сессии
правка вступит в силу при перезапуске fride.
