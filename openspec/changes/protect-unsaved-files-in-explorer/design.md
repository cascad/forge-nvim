# Design

## Context

Реальные native Files actions уже доступны, но отдельные copy/delete cases
в roadmap не проверены. Neo-tree fs_actions.clear_buffer после unlink
форсированно удаляет buffer; recursive native directory removal не даёт
защиты dirty descendants. Existing ide.buffers.safe-close/IDE-032 относятся
к другим маршрутам и не являются защитой этого command boundary.

## Goals / Non-Goals

**Goals:** normal Files d не теряет modified file buffers, в том числе hidden
descendants и изменение во время confirmation; native чистое удаление,
copy/cancel/конфликт остаются рабочими, контрольные пути с общим prefix
не блокируются. Native Windows/Ubuntu evidence, Mac/GUI явно отдельно.

**Non-Goals:** собственный filesystem backend, monkeypatch plugin APIs или
global BufDelete interception, сохранение/Discard за пользователя, Trash,
visual multi-select, cross-volume/case-only rename/LSP file ops, layout/
SDK/pins/setup changes. Тест не удаляет данные вне private project.

## Decisions

- Использовать существующий filesystem.commands boundary в plugins/neo-tree.lua
  и safe_tree_node/controls.tree_action, чтобы выбранная строка zoom сначала
  вернулась в native source. Не создавать новый registry/controller.
- Сканировать loaded file buffers (включая hidden/unlisted) по modified и
  filesystem имени. Canonical realpath/normalize, разделители и case-fold
  Windows задают равенство/descendant с явной границей '/', не string prefix.
- Guard выполняется до popup и после ответа Yes. На dirty цель выдать WARN
  с save/явным Discard/retry; файлов/буферов не менять и FILE_DELETED не
  посылать. BEFORE_FILE_DELETE handled не используется как veto: native
  handled всё равно вызывает complete/FILE_DELETED, это неверный контракт.
- Для чистой цели существующий inputs.confirm создаёт штатный Nui input;
  callback захватывает path/тип выбранной цели и повторно проверяет dirty.
  Затем fs_actions.delete_node(path, native refresh callback, true) выполняет
  фактическое удаление без второго диалога. Каталог в вопросе явно означает
  всё содержимое. Root/message/invalid type сохраняют native refusal.
- Не делать постоянный/временный monkeypatch inputs.confirm и не менять
  global use_popups_for_input. Callback принадлежит одной текущей команде.
- Source acffa63: девять fresh profiles, native y/p/c/d/zoom/cancel/root refusal и
  :ASToggle (public enabled=false) для сохранения несохранённого состояния.
  Direct native buffer edit при уже открытом popup моделирует background
  modification без fake backend; сама команда и подтверждение — клавиатура.
- Перед любым подтверждённым recursive delete тест проверяет realpath target
  внутри собственного project и обычные fixture descendants; никаких путей
  из host inventory не передаётся backend. Exact test/config/driver copies,
  реальные disk/buffer snapshots и native shutdown/scopes сохраняются.

## Risks / Trade-offs

- Буфер может измениться во время popup → второй guard и отдельный native
  late-modification regression; одной начальной проверки недостаточно.
- Autosave скрывает проблему → штатный ASToggle, API enabled только читается.
- FS watcher/follow меняет строки → locator читает actual node name/row и
  двигает курсор настоящим G; одинаковый prefix не считается exact name.
- Native directory delete/platform quoting остаётся backend → не переписывать
  rm/rmdir; source/current positive controls и owned-path guard обязательны.
- Mac/physical GUI и adversarial filesystem races не доказаны этими E2E.
- Первый соседний Ubuntu file-explorer6PASS/1FAIL (IDE-104) потерял видимость
  уже созданного child. Сохраняется raw failure, добавлены только failure-state
  node/path/rows и self source copy, затем один source/current diagnostic replay.
  Locator/deadline не меняются, возможный green не закрывает IDE-104.
