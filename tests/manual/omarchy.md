# Omarchy — native acceptance IDE-BOOT-53

Статус: не пройден. Arch CLI/container не доказывает эти desktop cases.
Нужна настоящая Omarchy VM/машина с Wayland/Hyprland и рабочим GPU/clipboard.
SDK/версии/обычный Neovim/Mise/desktop defaults сохраняем; тестовый проект и
локальный bare Git remote создаём отдельно от рабочих репозиториев.

Из checkout после установки fride в выбранный каталог:

```bash
bash scripts/test-omarchy.sh --kit "$HOME/path/to/fride" --project "$HOME/path/to/project" --versions --quick
"$HOME/path/to/fride/bin/fride" "$HOME/path/to/project"
```

Первый скрипт сохраняет JSON в .tests/omarchy и запускает unit/trace на частном
Neovim комплекта. Без --versions SDK CLI не проверяются. Он не ставит пакеты,
не меняет shell/Mise configs и не запускает Docker/WSL. Полный source E2E требует
предварительной подготовки общих inputs по [README E2E](../e2e/README.md).

| Кейс | Действия и ожидаемый результат | Статус |
|---|---|---|
| O1 | Default и Custom в отсутствующий путь с пробелами; повтор/upgrade; обычный nvim, SDK/версии и configs прежние. Отмена не заменяет рабочий kit. | Не проверено |
| O2 | Запустить fride-terminal; private font, рамки/цвета, размер окон и текст корректны на Wayland/GPU. Desktop defaults прежние. | Не проверено |
| O3 | Space w h/j/k/l, 0/d/c/q/z/?; terminal normal/scrollback/search; clipboard и русская/английская раскладки. Мышь для управления не требуется. | Не проверено |
| O4 | Два проекта с разными SDK/Mise settings; PATH и ручной путь; проверка SDK не ставит версии. Prepare явный, edit/save доступны; cancel/retry и apply SDK работают. | Не проверено |
| O5 | Смешанный Go/Rust/Python/Node/Bash/SQL проект: LSP/ошибки/format/navigation/implementation, поиск файлов/текста/команд и tabs. Нет ожидания фоновой установки при открытии файла. | Не проверено |
| O6 | Run, конкретный debug case, breakpoint/locals/stack/output/panic, continue/stop/restart; Tests discovery/run/output. Фокус и размеры панелей управляются клавиатурой. | Не проверено |
| O7 | Изменить файл; цветной diff, stage файла/строк, commit, history/branches/worktree и push в отдельный локальный bare remote. Рабочие remotes не используются. | Не проверено |
| O8 | Перезапуск восстанавливает tabs/tree/layout/sizes/scroll. Смена репозитория, создание/удаление/копирование файлов; повтор установки сохраняет state и user configs. | Не проверено |

Для результата записать версии Omarchy/Hyprland/WezTerm/GPU, architecture,
source/commit fride, command/JSON report и O1-O8 PASS/FAIL с коротким симптомом.
Непройденное остаётся непроверенным; полный desktop PASS только после всех cases.
