# Tasks

Прогон набора ниже — «оба bash»: в WSL `tests/install-macos.scenarios.sh /mnt/f/repo/forge-nvim bash` (bash 5.2) и тот же скрипт с собранным bash 3.2.57 (`/home/cascad/b32/bash-3.2.57/bash`). Запись FIXLOG у change одна: её заводит задача 2.5, следующие группы дописывают в неё свои строки. Запись последняя в файле, прежние записи не меняются. Если после неё кто-то уже добавил другую, группа пишет запись-продолжение со ссылкой на номер.

## 1. Тестовая обвязка

- [x] 1.1 Добавить в `tests/install-macos.scenarios.sh` заглушки по design Decision 8: `brew`, `rustup-init`, `go`, `xcode-select`, `plutil`, `nvim`. В каждой — комментарий, какое поведение настоящей программы она изображает и где это сверено. `nvim` положить в отдельный каталог, который `run` добавляет в PATH только по запросу. Рядом с `run` — хелпер для сценариев шагов зависимостей без `FORGE_NVIM_SKIP_DEPS`. Проверка: S1–S16 зелёные под обоими bash, число проверок то же, что до правки (windows, WSL).

## 2. Nerd Font и Rust (MAC-INST-6, MAC-INST-5)

- [x] 2.1 Написать S17: шрифт только в `~/Library/Fonts`, cask не установлен; затем без файлов шрифта. `/Library/Fonts` в WSL-песочнице нет, и тестовой лазейки в установщик ради него не добавляем: этот каталог проверяется вручную (2.6, MAC-INST-6). Проверка: на текущем коде S17 красный в случае «только `~/Library/Fonts`» — журнал `brew` содержит `install --cask font-caskaydia-cove-nerd-font` (windows, WSL).
- [x] 2.2 Переписать проверку шрифта на цикл по glob каждого каталога с `[ -e ]` (Decision 1). Проверка: S17 зелёный под обоими bash — при шрифте в `~/Library/Fonts` cask не вызывается и есть `already present in Library/Fonts`, без файлов cask вызывается ровно один раз (windows, WSL).
- [x] 2.3 Написать S18: `FORGE_NVIM_WITH_LANGUAGES=1`, исполняемый `~/.cargo/bin/cargo` есть, `~/.cargo/bin` не в PATH. Затем реализовать Decision 2. Проверка: на текущем коде S18 красный (`rustup-init` в журнале); после правки — зелёный под обоими bash, `rustup-init` в журнале нет, в выводе `rust: already installed (~/.cargo/bin; добавь этот каталог в PATH, если его там нет)` (windows, WSL).
- [x] 2.4 Сверить документы со шрифтом и Rust. Проверка: `grep -n -i "rustup\|Nerd Font\|CaskaydiaCove" README.md nvim_forge/README.md docs/WEZTERM.md` — ни одна найденная строка не противоречит MAC-INST-5 и MAC-INST-6 из `openspec/changes/fix-macos-installer/specs/`; противоречащие поправлены (windows).
- [x] 2.5 Дописать в `nvim_forge/FIXLOG.md` новую нумерованную запись «Проблема → Причина → Решение → Файлы» этого change. Начать с шрифта и Rust: строки `Спека: MAC-INST-6 (MODIFIED)` и `Спека: MAC-INST-5 (MODIFIED)`, «Проверено: S17, S18 под bash 5.2 и 3.2.57». Проверка: `grep -n "Спека: MAC-INST-6 (MODIFIED)" nvim_forge/FIXLOG.md` находит запись; `git diff nvim_forge/FIXLOG.md` — только добавленные строки в конце (windows).
- [ ] 2.6 Передать владельцу шаг для Mac: шрифт только в `~/Library/Fonts`, затем только в `/Library/Fonts`, cask не установлен → `./nvim_forge/scripts/install-macos.sh` дважды в каждом случае. Там же, если удобно, ответить на Open Question: падает ли cask при уже лежащем шрифте. Проверка: все прогоны без `brew install --cask font-…` и без предупреждения; результат записан в запись FIXLOG, пока его нет — там «на Mac не проверено» (macos).

## 3. Бутстрап: git без Xcode CLT (MAC-INST-3)

- [x] 3.1 Написать S19: `curl | bash` (скрипт со stdin), заглушка `xcode-select` с `FAKE_XCODE_SELECT_RC=2`, git в PATH — `/usr/bin/git`. Проверка: на текущем коде S19 красный: клон создан, код 0 (windows, WSL).
- [x] 3.2 Реализовать проверку «git доступен» по Decision 3 одной функцией, которую зовёт бутстрап. Проверка: S19 зелёный под обоими bash: сообщение `git is required: run \`xcode-select --install\`, then rerun this command.`, код 1, `FORGE_NVIM_SRC` не создан; S7 без заглушки `xcode-select` по-прежнему зелёный (windows, WSL).
- [x] 3.3 В разделе Quick Install для macOS в `nvim_forge/README.md` написать, что без Xcode Command Line Tools скрипт остановится и подскажет `xcode-select --install`. Проверка: `grep -n "xcode-select --install" nvim_forge/README.md` находит строку в разделе macOS (windows).
- [x] 3.4 Дописать в запись FIXLOG change строку `Спека: MAC-INST-3 (MODIFIED)` и «Проверено: S19». Проверка: `grep -n "Спека: MAC-INST-3 (MODIFIED)" nvim_forge/FIXLOG.md` находит её (windows).
- [ ] 3.5 Передать владельцу шаг для Mac без CLT (свежая учётная запись или VM): `curl -fsSL …/install-macos.sh | bash`. Проверка: сообщение скрипта, системный диалог установки CLT не всплывает, `~/forge-nvim` не создан. Результат — в записи FIXLOG; нет такого мака — там «на Mac без CLT не проверено» (macos).

## 4. Профили шелла: присваивание после блока (WT-LOAD-7)

- [x] 4.1 Написать S20: в `~/.zshrc` блок forge-nvim, после него новый `export WEZTERM_CONFIG_FILE=/x.lua`. Три прогона подряд. Проверка: на текущем коде S20 красный: второй блок не дописан, после `source` переменная задана (windows, WSL).
- [x] 4.2 Смотреть только хвост после последнего `# <<< forge-nvim <<<` (Decision 4, хвост вырезает `awk`). Проверка: S20 зелёный под обоими bash: после второго прогона блоков два, прежние строки — нетронутый префикс, после `source` переменной нет, третий прогон файл не меняет; S3, S12, S16 зелёные (windows, WSL).
- [x] 4.3 В `docs/WEZTERM.md` §9 (или в его разделе про установщик, если `sync-docs-with-baseline` уже переписал файл) дописать: присваивание, появившееся после прежнего блока, получает ещё один блок в конце. Проверка: `grep -n "после прежнего блока" docs/WEZTERM.md` находит строку, и она не противоречит WT-LOAD-7 из `openspec/changes/fix-macos-installer/specs/` (windows).
- [x] 4.4 Дописать в запись FIXLOG строку `Спека: WT-LOAD-7 (MODIFIED)` и «Проверено: S20». Проверка: `grep -n "Спека: WT-LOAD-7 (MODIFIED)" nvim_forge/FIXLOG.md` (windows).

## 5. LaunchAgent: только настоящий setenv (WT-LOAD-8)

- [x] 5.1 Переписать фикстуру S13 в настоящий plist LaunchAgent: `ProgramArguments` = `launchctl setenv WEZTERM_CONFIG_FILE /elsewhere.lua` (Decision 8). Написать S21:
  - только `launchctl unsetenv WEZTERM_CONFIG_FILE`;
  - переменная только в `EnvironmentVariables`;
  - `sh -c "launchctl setenv WEZTERM_CONFIG_FILE ~/<путь к репо>"`;
  - путь к репо через симлинк;
  - `sh -c "… setenv WEZTERM_CONFIG_FILE /elsewhere.lua"`;
  - два plist с чужими путями.

  Проверка: на текущем коде S21 красный — первые четыре дают код 1, из двух plist назван один (windows, WSL).
- [x] 5.2 Реализовать разбор команды plist по Decision 5: `plutil -convert xml1 -o -`, если `plutil` есть; строки из `ProgramArguments`/`Program`; setenv аргументами или в строке `sh -c`; раскрытие `~`/`$HOME` только во втором случае; список нарушителей. Проверка: S13 и S21 зелёные под обоими bash, в том числе с заглушкой `plutil` в PATH и без неё (windows, WSL).
- [ ] 5.3 Передать владельцу шаг для Mac: plist с `launchctl setenv WEZTERM_CONFIG_FILE /elsewhere.lua`, сохранённый `plutil -convert binary1`, в `~/Library/LaunchAgents` → установщик → plist удалить. Проверка: plist назван, код 1, после удаления код 0; результат — в записи FIXLOG (macos).
- [x] 5.4 В `docs/WEZTERM.md` §9 уточнить фразу о LaunchAgent: называется plist, который при входе выставляет переменную с путём не в репо; plist, который её только снимает или задаёт своему процессу, не считается. Проверка: строка не противоречит WT-LOAD-8 из `openspec/changes/fix-macos-installer/specs/`; `grep -n "LaunchAgent" docs/WEZTERM.md` находит её (windows).
- [x] 5.5 Дописать в запись FIXLOG строку `Спека: WT-LOAD-8 (MODIFIED)` и «Проверено: S13, S21; двоичный plist — …». Проверка: `grep -n "Спека: WT-LOAD-8 (MODIFIED)" nvim_forge/FIXLOG.md` (windows).

## 6. Подсказка о перезапуске (WT-LOAD-12)

- [x] 6.1 Написать S22 (`FAKE_PGREP=0`, `WEZTERM_PANE=1`):
  - `WEZTERM_CONFIG_DIR=$H`, `~/.wezterm.lua` → файл репо — подсказки нет;
  - в панели `WEZTERM_CONFIG_FILE` на файл репо под другим именем — подсказки нет;
  - то же с путём не в репо — подсказка есть.

  Проверка: на текущем коде S22 красный в первых двух случаях (windows, WSL).
- [x] 6.2 Реализовать Decision 6: переменная панели авторитетна; иначе кандидаты `$WEZTERM_CONFIG_DIR/wezterm.lua`, `$WEZTERM_CONFIG_DIR/.wezterm.lua` и launchd-переменная с каталогом, равным `WEZTERM_CONFIG_DIR`. Проверка: S22 зелёный под обоими bash; в S3 подсказка есть на первом прогоне и нет на повторном (windows, WSL).
- [x] 6.3 Сверить описание подсказки о перезапуске в `docs/WEZTERM.md` и `nvim_forge/README.md`. Проверка: `grep -n "Cmd+Q" docs/WEZTERM.md nvim_forge/README.md` — найденные строки о подсказке установщика не противоречат WT-LOAD-12; противоречащие поправлены (windows).
- [x] 6.4 Дописать в запись FIXLOG строку `Спека: WT-LOAD-12 (MODIFIED)` и «Проверено: S22». Проверка: `grep -n "Спека: WT-LOAD-12 (MODIFIED)" nvim_forge/FIXLOG.md` (windows).

## 7. Режим ~/.config/nvim — симлинк (MAC-INST-10, MAC-INST-11, MAC-INST-13, бутстрап MAC-INST-3)

- [x] 7.1 Переписать S11 и написать S23–S28 по Decision 8. `nvim` — заглушка, `FORGE_NVIM_INSTALL_DIR` не задаётся, где сценарий проверяет умолчание.
  - S23: чистый HOME, `FORGE_NVIM_DEPS_ONLY=0`. Итог — `~/.config/nvim` → `<чекаут>/nvim_forge`. Повтор: `forge-nvim config already linked`, бэкапов не прибавилось, код 0.
  - S24: на месте каталог, файл, битый симлинк, симлинк на `nvim_forge/` второго чекаута. Каждый целиком в бэкапе (у симлинка цель не тронута), затем новый симлинк. С `FORGE_NVIM_NO_BACKUP=1` — `Install path already exists`, код 1, путь не тронут.
  - S25: отказы — нет `nvim` (PATH без каталога заглушки), нет `nvim_forge/init.lua`, путь установки = чекаут и путь над ним, путь внутри чекаута. Каждый — код 1, `nbackups "$H"` = 0, `~/.config/wezterm` не создан.
  - S26: `XDG_CONFIG_HOME=$C`, `NVIM_APPNAME=nvim_forge`. Путь — `$H/.config/nvim`, в `$C` ничего нового. В журнале `nvim` — `NVIM_APPNAME=nvim`, `XDG_CONFIG_HOME=$H/.config`. Отдельно `XDG_CONFIG_HOME=$C-other` учитывается.
  - S27: скрипт скопирован вне чекаута, `FORGE_NVIM_REPO` — локальный git-чекаут. Клон в `FORGE_NVIM_SRC`, перезапуск с `FORGE_NVIM_DEPS_ONLY=0`, симлинки `~/.config/nvim` и WezTerm ведут в клон. С `FORGE_NVIM_USE_LOCAL_SOURCE=1` — отказ до любых действий (`FORGE_NVIM_SRC` не создан). С заглушкой `xcode-select` ≠ 0 — отказ бутстрапа, путь установки не тронут.
  - S28: в `~/.config/nvim` git-клон монорепо. Он в бэкапе, его HEAD не изменился, fetch не выполнялся.

  Проверка: на текущем коде S23–S28 и новый S11 красные (windows, WSL).
- [x] 7.2 Вынести общую функцию «симлинк `<dst>` → `<src>` с бэкапом» по Decision 10. `link_wezterm_config` оставить только со своим «`…/wezterm` не каталог». Если `add-linux-installer-parity` уже завёл общий файл функций — функция живёт там. Проверка: S1–S16 и S20–S22 зелёные под обоими bash без изменений ожиданий (windows, WSL).
- [x] 7.3 Путь установки по умолчанию с правилом «`XDG_CONFIG_HOME` внутри чекаута не учитывается» (Decision 13) и проверка вложенности пути и чекаута (Decision 10). Сравнение — по раскрытым путям с `/` на конце. Проверка: часть S26 про `XDG_CONFIG_HOME` и части S25 про вложенность зелёные под обоими bash (windows, WSL).
- [x] 7.4 Предпроверка режима одной функцией сразу после шага зависимостей, до шага WezTerm (Decision 12): `<чекаут>/nvim_forge/init.lua`, вложенность, `nvim` в PATH. Сообщения — из MAC-INST-10. Проверка: S25 зелёный под обоими bash (windows, WSL).
- [x] 7.5 Заменить установку конфига симлинком (Decision 9, 10): убрать ветки git-чекаута в пути установки, «Already running from the target config directory», клон в путь установки и `copy_local_repo`. Сообщения `Linked <путь> -> <чекаут>/nvim_forge` и `forge-nvim config already linked: <путь>`. Проверка: S11, S23, S24, S28 зелёные под обоими bash (windows, WSL).
- [x] 7.6 Бутстрап для файла вне чекаута в режиме установки, с `FORGE_NVIM_DEPS_ONLY=0` в перезапуск. `FORGE_NVIM_USE_LOCAL_SOURCE=1` вне чекаута — отказ с прежним сообщением до любых действий (Decision 11). Проверка: S27 зелёный под обоими bash; S7 (`curl | bash` без флагов → локальный режим) зелёный (windows, WSL).
- [x] 7.7 Синхронизация плагинов по Decision 14: `nvim` с `XDG_CONFIG_HOME` = родитель пути установки и `NVIM_APPNAME` = его имя, `+Lazy! restore` вместо `+Lazy! sync`, Treesitter и Mason — как прежде. Проверка: в журнале заглушки `nvim` в S23 и S26 есть `Lazy! restore` с ожидаемыми `NVIM_APPNAME` и `XDG_CONFIG_HOME` и нет `Lazy! sync`; `FAKE_NVIM_RC=1` на `restore` даёт код ≠ 0 (windows, WSL).
- [ ] 7.8 Передать владельцу шаг для Mac: `FORGE_NVIM_DEPS_ONLY=0 ./nvim_forge/scripts/install-macos.sh` из чекаута, затем ещё раз. Проверка:
  - прежний `~/.config/nvim` в `~/.config/nvim.backup-*`;
  - `readlink ~/.config/nvim` = `<чекаут>/nvim_forge`;
  - `nvim` стартует с конфигом forge-nvim;
  - `git -C <чекаут> status --porcelain` пуст;
  - второй прогон — `forge-nvim config already linked`, новых бэкапов нет.

  Результат — в записи FIXLOG, пока его нет — там «на Mac не проверено» (macos).
- [x] 7.9 Обновить документы о режиме `~/.config/nvim`:
  - `nvim_forge/README.md`, раздел «Install as the system Neovim config»: на macOS — симлинк на `nvim_forge/` чекаута, чекаут должен оставаться на месте, плагины по `lazy-lock.json` (`Lazy! restore`), повторный запуск без бэкапов. Linux и Windows пока копируют — абзац про копирование и `Lazy! sync` оставить только им;
  - там же список переменных: смысл `FORGE_NVIM_USE_LOCAL_SOURCE` и `FORGE_NVIM_SRC` на macOS;
  - `README.md` (фраза про «real» install в `~/.config/nvim`);
  - комментарий-шапка `nvim_forge.sh` про удалённую установку.

  Проверка: `grep -n "symlink\|симлинк" nvim_forge/README.md` находит описание режима для macOS, `grep -n "Lazy! sync" nvim_forge/README.md` не относится к macOS, и ни одна правка не противоречит MAC-INST-10/13 из `openspec/changes/fix-macos-installer/specs/` (windows).
- [x] 7.10 Дописать в запись FIXLOG:
  - строки `Спека: MAC-INST-10 (MODIFIED)`, `Спека: MAC-INST-11 (MODIFIED)`, `Спека: MAC-INST-13 (MODIFIED)`;
  - к строке MAC-INST-3 — бутстрап для файла вне чекаута;
  - «Решение владельца 2026-09-27: Q12 = B» со ссылкой на design Decision 9;
  - миграцию: прежняя копия уходит в бэкап один раз; откат — revert, копия в `~/.config/nvim.backup-*`;
  - «Проверено: S11, S23–S28; Mac — 7.8».

  Проверка: `grep -n "Спека: MAC-INST-10 (MODIFIED)" nvim_forge/FIXLOG.md` находит запись; `git diff nvim_forge/FIXLOG.md` не трогает прежних записей (windows).

## 8. Шапка install-macos.sh (divergences 13, 14)

- [x] 8.1 Написать S29: каждая переменная `FORGE_NVIM_[A-Z_]*`, которую читает `install-macos.sh`, названа в шапке (строки до `set -euo pipefail`). Проверка: на текущем коде S29 красный — нет `FORGE_NVIM_REPO`, `FORGE_NVIM_BRANCH`, `FORGE_NVIM_USE_LOCAL_SOURCE` (windows, WSL).
- [x] 8.2 Переписать шапку по Decision 7:
  - `brew shellenv` — `~/.bash_profile` для bash, иначе `${ZDOTDIR:-~}/.zprofile`;
  - полный список флагов с умолчаниями и смыслом `FORGE_NVIM_USE_LOCAL_SOURCE`;
  - пункт 3 — симлинк `~/.config/nvim` → `<чекаут>/nvim_forge` и `Lazy! restore`.

  Проверка: S29 зелёный под обоими bash; `sed -n '1,45p' nvim_forge/scripts/install-macos.sh | grep -n "bash_profile"` находит строку (windows, WSL).

## 9. Интеграция

- [x] 9.1 Финальный прогон `tests/install-macos.scenarios.sh` под bash 5.2 и 3.2.57. Проверка: все проверки зелёные под обоими, код 0; число проверок и дата записаны в запись FIXLOG («Проверено: N из N под обоими») (windows, WSL).
- [x] 9.2 Проверка форматов. Проверка: `openspec validate fix-macos-installer --type change --strict --no-interactive` — valid; `openspec validate --all --strict` — без ошибок (windows).
- [ ] 9.3 Передать владельцу полный прогон на Mac из чекаута без флагов, затем повтор. Проверка: второй прогон — код 0, новых `*.backup-*` нет, снимок `ls -la ~ ~/.config ~/.config/wezterm` до и после повтора совпадает; результат — в записи FIXLOG (macos).
