# Design

## Context

См. proposal.md и IDE-106 в IDE_ROADMAP. Native sources inventory —
docs/IDE_LOG_SOURCES.md; существующий Fidget history session-only и начинается
с LspAttach. Его Telescope extension не объединяет native logs/startup.
В проекте уже есть registry/Edgy/controls и готовые native buffer/search APIs.

Первый native diagnostic Windows/Ubuntu показал только сохранение history/
cmdheight, но не доказал visual forwarding. Первая реализация дала Windows2/3:
UI input оказался невидим. ext_messages неявно включает ext_cmdline (native
api-ui-events.txt). Подписка полностью снята; test теперь проверяет видимый
штатный prompt, а не предполагаемый insert mode вместо native command mode.

## Goals / Non-Goals

**Goals:** одна консоль, native sources как владельцы подробностей,
ограниченная история сообщений, постоянные keyboard/restart regressions.

**Non-Goals:** собственные LSP/logging backend для плагинов, копирование
debug variables/env/project output на диск, смена layout owner, новая тема,
автоматический setup, смена pins/Neovim или глобальных logging levels.

## Decisions

- Early capture до config/lazy: тонкий vim.notify delegate сохраняет title/
  level и передаёт оригинальные аргументы/результат. Native :messages читается
  при открытии/r/VimEnter/VimLeavePre; его snapshot помечен временем получения,
  а не выдуманным временем native ошибки. UI subscriptions отсутствуют.
  Direct Fidget notifications через documented
  update_hook с сохранённым set_content_key; progress skip_history исключён.
- Небольшой recorder хранит только displayed text/source/level/time/session.
  Синхронный bounded append нужен для ошибки перед падением; никаких timers/
  фоновых jobs. Per-session файлы избегают конкурирующих writers. По128KiB
  current/previous,200 записей в памяти; сохранять8 последних завершённых
  sessions плюс активные. Только собственные файлы и ESRCH-confirmed stale
  session допускают cleanup. Ошибка IO остаётся видимой в памяти/консоли.
- Console — обычный readonly nofile buffer в существующем bottom slot.
  Registry/Edgy/controls остаются владельцами геометрии и фокуса. Space w i,
  :ForgeLogs; native /, s источник, f текст, v уровень, c сброс, r refresh,
  Enter подробности, y отчёт, H explicit checkhealth forge. Панель не polling.
- Native source facade читает только известные paths/публичные filename APIs
  уже загруженных modules; plugin require не используется для активации source.
  DAP дополнительные logs из cache/dap*.log; active output buffers по filetype.
  До64KiB хвоста источника, с явными status/path/mtime/read boundary. Private
  logger tables не нужны. Неоднозначный native level отображается как unknown.
  При единственной длинной строке сохраняется её доступный хвост; для всех
  каналов начало среза выравнивается по UTF-8. Pre-commit tail E2E дал по2RED
  Windows/Ubuntu до правки reader; source bytes и native shutdown сохранены.
- Общая история содержит сообщения с временными метками; native detail logs
  доступны как отдельные channels. Их времена/форматы не нормализуются в
  выдуманную общую chronology, raw logs не копируются в persistent recorder.
- IDE-107: source84f619c воспроизводит late focus steal прежней Problems на
  Windows/Ubuntu. Существующий focus_code_later получает optional predicate,
  DAP проверяет исходное окно/Debug buffer перед отложенным возвратом в код.
  Новый явный выбор Logs/Problems сохраняется. Другие callers без predicate
  сохраняют прежнее поведение; новый focus manager/таймер не добавляется.
- Redaction распознаваемых credentials применяется к записи и отчёту, поля
  options.data/environment/debug variables не читаются. Native оригинал не
  переписывается. Диагностический report копируется явным действием пользователя.

Альтернативы: Fidget history/Telescope extension полезны для уведомлений, но
не покрывают early/native/persistent/source статусы. Добавление Noice ради этой
задачи меняет message UI и pins; не выбрано. Декоративный overlay/новый panel
manager также не нужен. Native APIs и минимальная интеграция предпочтительны.

## Risks / Trade-offs

- Native history — snapshot, а не live stream → явная подпись времени снимка,
  r и readonly native channel; уведомления записываются сразу. Native message
  UI не подменяется; отказ чтения истории показывается явно.
- Секреты в произвольном тексте нельзя определить по смыслу → не читать env/
  data/locals, скрывать стандартные credential patterns, хранить короткие тексты.
- Native log отключён/путь переопределён → показать known path/status и native
  команду подробностей; loaded public options имеют приоритет над defaults.
- Диск readonly/повреждённая история → console остаётся доступной, status failure
  и сохранившаяся часть истории видны; ошибка recorder не вызывает notify loop.
- Source retention и размер ограничены → UI/doc обозначают лимиты, session IDs
  и truncated state. Active writers не удаляются из-за общего лимита sessions.

## Migration Plan

Новый код штатно загружается без подготовки deps. SDK/pins прежние.
Отмена — убрать setup/component/keymap и capture hook; native logs не затронуты.
Сначала permanent source RED и probes, затем implementation и та же матрица
Windows→Ubuntu. Mac/physical GUI task остаётся открыт до actual запуска.
