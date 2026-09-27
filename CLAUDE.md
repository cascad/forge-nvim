# forge-nvim — правила работы в репо

Отвечай по-русски. Комментарии в коде, FIXLOG и спеки — по-русски.

## Где что лежит (один источник на каждый вопрос)

| Вопрос | Источник |
|---|---|
| Как фича работает | `openspec/specs/<capability>/spec.md` |
| Что решено поменять / какие баги известны | `openspec/changes/<id>/` — proposal + delta к спеке |
| Что ломалось, почему, как чинили | `nvim_forge/FIXLOG.md` — журнал, только дописывается |
| Новые жалобы и хотелки | `PROBLEMS.md` — инбокс |
| Как пользоваться (для человека) | `docs/*.md`, README — производные |

Формат спек, роли артефактов и текущая фаза — `openspec/config.yaml`.
Спеками покрыты WezTerm (`wezterm.lua`) и установщик macOS
(`openspec list --specs`); nvim_forge — ещё нет.

## Кто прав при расхождении (жизненный цикл)

- **Сейчас — фаза 1, «базовая линия».** `openspec/specs/` сняты с кода и
  описывают его КАК ЕСТЬ. Источник правды — код; README и docs — тоже
  производные от кода. Спека не совпала с кодом → чинится спека.
- **Фаза 2, «источник правды»** — после того как владелец проверит
  базовую линию (change `review-baseline`; строка «ТЕКУЩАЯ ФАЗА» в
  `openspec/config.yaml`). Тогда спека —
  намерение владельца, код, расходящийся с ней, — баг, а README и docs
  производны от спеки.
- В обеих фазах всё, что решено поменять, и найденные баги — это
  `openspec/changes/<id>/` с delta (MODIFIED/ADDED/REMOVED). Пока change
  не применён (`/opsx:apply`) и не заархивирован (`/opsx:archive`),
  specs/ не меняются.

## Правила

1. **Поведение меняется только через change** (`/opsx:propose`) и с
   явного согласия владельца. В фазе 2 не правь `openspec/specs/`, чтобы
   код или тест «прошли».
2. **Баг.** Найди требование (ID вида `WT-CLIP-1`) и открытые changes по
   нему → сверь с кодом (код требования: `grep -n 'spec: <ID>' wezterm.lua`);
   его проверки: `nvim -l tests/run.lua --id <ID>`:
   - (фаза 2) код нарушает спеку → чини код; в FIXLOG `Спека: <ID> (FIX)`;
   - спека молчит → сначала сценарий в change (ADDED/MODIFIED), потом код.
3. **Прежде чем «чинить» странность** — проверь `openspec/changes/`:
   возможно, это уже известный баг или принятое решение.
4. **PROBLEMS → FIXLOG.** Разобранный пункт из `PROBLEMS.md` чинится, в
   `nvim_forge/FIXLOG.md` добавляется нумерованная запись
   `Проблема → Причина → Решение → Файлы` (+ `Спека:` если задето
   поведение), а сам пункт уезжает в карту разобранного внизу
   `PROBLEMS.md` со ссылкой на §.
5. **Доказательства — в репо.** Проверка, которая что-то доказала,
   кладётся в `tests/` в том же коммите. Иначе в FIXLOG пиши
   «Проверено вручную: как, где».
6. **Меняешь поведение — обнови всё, что его описывает** в том же
   изменении: спеку (через change), docs, FIXLOG.

## OpenSpec: штатные команды (Claude Code)

- `/opsx:explore` — обдумать идею или проблему, ничего не меняя.
- `/opsx:propose` — change целиком за один шаг (proposal, delta, design,
  tasks). `/opsx:new` + `/opsx:continue` — то же по одному артефакту.
- `/opsx:update` — поправить артефакты change после нового решения.
- `/opsx:apply` — выполнить задачи change (здесь меняется код).
- `/opsx:verify` — сверить реализацию с change и спекой перед архивом.
- `/opsx:sync` / `/opsx:archive` — влить delta в `openspec/specs/`.
- CLI: `openspec list` (changes), `openspec list --specs`,
  `openspec show <id>`, `openspec status --change <id>`,
  `openspec validate --all --strict`.

## Проверки

- **Одна команда: `nvim -l tests/run.lua`** — всё, что проверяется без GUI
  (наборы `unit`, `wezterm`, `install`, `trace`), и статус каждого ID из
  `openspec/specs/`: PASS / FAIL / SKIP / MANUAL / UNCOVERED. Одно
  требование — `--id WT-CLIP-2`, вся capability — `--id WT-CLIP`;
  осознанное изменение эталонов — `--update-golden` (diff — в тот же коммит).
  Отчёт — `.tests/report.json`, логи — `.tests/logs/`. Протокол, реестр и
  как добавить проверку — `tests/README.md`. Установщик macOS идёт в том же
  прогоне (на Windows — в WSL; ветка bash 3.2 — `FORGE_BASH32=<путь в WSL>`,
  в Git Bash — вместе с `MSYS2_ENV_CONV_EXCL=FORGE_BASH32`).
- Проба клавиатуры через conpty.dll (Windows): `nvim -l tests/run.lua conpty`
  — около 1,5 минут, поэтому в обычный прогон и хук не входит; идёт и с
  `--id WT-KBD-9` / `--id WT-KEYS-10`.
- Один файл проверок — напрямую, например копирование и `y` в copy mode:
  `nvim -l tests/wezterm/clipboard.test.lua` (печатает список проверок,
  код ≠ 0 при любом провале).
- Хук pre-commit (необязательный, `.githooks/pre-commit` — тот же
  `nvim -l tests/run.lua`): включить — `git config core.hooksPath .githooks`,
  выключить — `git config --unset core.hooksPath`. Включает владелец на
  своей машине; агент `core.hooksPath` не выставляет.
- `openspec validate --all --strict` — формат спек и changes (OpenSpec
  1.13.2; без глобальной установки —
  `npx -y @fission-ai/openspec@1.13.2 validate --all --strict`).
- `tests/install-macos.scenarios.sh [repo] [bash]` — установщик macOS в
  песочнице (bash 5 и bash 3.2; нужны bash, git, python3 — WSL/Linux/macOS).
- `tests/install-linux.scenarios.sh [repo] [bash]` — шаг WezTerm
  установщика Linux в песочнице (WT-LOAD-13; те же bash, общий
  `nvim_forge/scripts/lib/wezterm-link.sh`). Оба набора идут и в
  `nvim -l tests/run.lua` (набор `install`).
- WezTerm-конфиг грузится: `wezterm --config-file wezterm.lua ls-fonts`
  (при ошибке — пустой stdout и `ERROR` в stderr; `show-keys` ошибок НЕ
  показывает).
- nvim_forge headless: `NVIM_APPNAME=nvim_forge XDG_CONFIG_HOME=<repo> nvim --headless …`.
- Ручные чек-листы по платформам — `tests/manual/wezterm-windows.md`,
  `tests/manual/wezterm-macos.md`: то, что без GUI не проверить. Результат
  дописывается строкой `Проверено: <дата>, <ОС>, WezTerm <версия>, раскладка <…> —
  совпало | расходится: …`, прежние строки не правятся. Пункт без такой строки
  даёт в сводке `nvim -l tests/run.lua` статус MANUAL.
