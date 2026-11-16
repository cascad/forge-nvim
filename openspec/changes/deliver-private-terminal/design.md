# Design

## Context

Прежний runtime-parts/component catalog уже проверяет SHA, файлы, native probes
до публикации staging; Terminal row существует. Legacy WezTerm state общий в
home; root config один. Private kit имеет bin/config/runtime, устойчивые log/tmp
и rollback. Ubuntu console image намеренно не содержит GUI libraries.

## Goals / Non-Goals

Goals: pinned official WezTerm20240203, CaskaydiaCove3.4.0 (четыре normal/bold/
italic faces), штатные font_dirs/ConfigDirsOnly, прежняя композиция artifacts,
явный launcher fride-terminal и отдельный state без SDK/global changes.

Non-Goals: обновление WezTerm, другой терминал/тема/хоткеи, font registration,
изменение shell startup, общий license audit всего Default, native Mac acceptance
здесь или Linux GUI acceptance в console container; production publication.

## Decisions

- Windows official portable zip; macOS universal .app zip; Linux x64 official
  AppImage с штатным --appimage-extract, без FUSE. SHA проверяется до extraction.
  Подготовка выполняется publisher; пользователь получает прежний ready component.
- Prepared input хранит проверенные sources и exact payload metadata. Publisher
  перепроверяет их по pinned archives, версию native executable и лицензии, затем
  использует package-runtime.py --component terminal. Terminal paths пусты:
  обычный wezterm в PATH не затеняется; launcher знает собственный executable.
- В config копируется тот же root wezterm.lua. Тонкий fride-wezterm.lua задаёт
  private font dirs/locator и передаёт state path через аргумент Lua chunk
  (loadfile(...)(context)). Root без context ведёт себя как раньше. Собственный
  state/wezterm-window.json сохраняется между повторными установками/upgrade.
- PS/Bash launchers вызывают explicit binary --config-file ... start
  --always-new-process --cwd <current> -- <existing fride launcher> <args>.
  Дополнительные host environment/registry/profile не пишутся. Новый процесс
  не переиспользует уже открытое пользовательское окно/конфиг.
- Только выбранный Terminal создаёт эти launchers/config/state directory.
  Native version probes используют штатный manifest. Config/font readiness
  подтверждается реальным ls-fonts до publish staging; проверяется private font
  path/face, errors не маскируются exit0 WezTerm. E2E передаёт hash-valid архив
  с invalid TTF и проверяет сохранность runtime/config/bin/ready прежнего kit.
- Для Ubuntu CLI/font acceptance обычные GUI runtime libs готовятся отдельно
  как disposable test inputs из official Ubuntu packages, без host install,
  image build/pull или Desktop/WSL управления. LD path ограничен test child;
  в продукт этот override не попадает. Native GUI Ubuntu/Mac — отдельные gates.

## Risks / Trade-offs

- Официальный AppImage требует host GUI libs (libxcb/X11/fontconfig/Wayland).
  Чистый server/container не объявляется Desktop support; зависимости явно
  документируются, автоматической скрытой установки нет.
- Конфиг может молча откатиться к defaults с exit0 → oracle проверяет фактический
  loaded config, private font path/glyph и roundtrip редактора через новый GUI.
- Windows GUI tests завершают только собственный процесс/панель по полученным
  native IDs; чужие WezTerm/редакторы не перечисляются для закрытия.
