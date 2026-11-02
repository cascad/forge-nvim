# Design

## Context

Actual pinned provider (0d1e936) строит literal regex по целому слову.
Probe компиляции 512 КиБ проходит; provider match_line переключается на
backtracking и выдаёт E339/internal error. UI prototype 33978419604200
содержит E339/hit-enter и RPC timeout. Large-file лимит сейчас только по
числу строк, а overrides не наследуют should_enable.

## Goals / Non-Goals

**Goals:** общий ресурсный предел слова, восстановление обычной подсветки,
работа длинных строк и large-file режима без системных веток.

**Non-Goals:** новый regex engine/backport, отключение всего большого файла,
менеджер лимитов всех плагинов, изменения SDK/зависимостей/установки,
исправление неизвестных Gitsigns RPC/fixture IDE-047/048.

## Decisions

1. Публичный should_enable проверяет byte length текущего <cword>; бюджет
   4096 достаточно щедрый для идентификаторов и ограничивает LSP/regex работу.
   Обычные короткие слова в длинной строке остаются доступны. Существующее
   исключение rust_external применяется тем же callback.
2. Общий callback назначается основным opts и large_file_overrides, иначе
   после cutoff защита исчезнет. Для неактивного буфера callback возвращает
   false: cursor/word наблюдаются только в текущем буфере.
3. E2E вводит edit/move/write/Alt+n/p настоящими клавишами; экстмарки и курсор
   читаются через Neovim API. Ни provider, ни handlers не вызываются напрямую.
   Наблюдатель очереди после debounce допускает выполнение реального provider;
   неожиданный prompt/ERROR/видимые E… не принимаются автоматически.
4. v:errmsg может хранить прежний silent! loadview E484 при отсутствии
   saved view. Проверяются видимые messages, notifications, mode и реальные
   действия; raw errmsg сохраняется в snapshot, не обнуляется для GREEN.

## Risks / Trade-offs

- Guard слишком широкий → отдельный E2E строки 512 КиБ с короткими словами.
- Guard теряется после cutoff → отдельный файл 5003 строк и восстановление.
- UTF-8 byte/character ошибка → boundary 4096/4097 bytes на кириллице.
- Один зелёный повтор → постоянный UI baseline RED на архиве fa33150,
  source SHA и тот же конечный тест, затем Windows/Ubuntu; Mac/GUI отдельно.
