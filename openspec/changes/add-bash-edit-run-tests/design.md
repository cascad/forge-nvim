# Design

## Context

Мотивация в proposal.md. Baseline 4b859b8: есть общие Conform/Tasks/Neotest/
panels и forge.node native Node+entrypoint resolver. Bash-LSP 5.8.1 требует
Node >=20; подготовленный Node 24.11.0 подходит. Native Windows Git Bash
5.2.37 работает; PATH bash.exe — WSL launcher, его не запускаем.

## Goals / Non-Goals

Четыре наблюдаемых workflow и простая явная подготовка. Не заменять shell
WezTerm, не менять hotkeys других языков/плагины/SDK и не выдавать install
script tests за Bash IDE E2E. DAP остаётся следующим обязательным Bash этапом
IDE-057 после выбора Linux backend, не реализуется и не объявляется PASS здесь.

## Decisions

1. Общий forge.bash: guarded Bash-LSP setup через существующий Node resolver,
   script/run/tests native argv. POSIX берёт подготовленный host Bash;
   Windows — явный override, Git Bash или пригодный native PATH, отвергает
   Windows system WSL launchers. Никаких shell string, .cmd или source profile.
   Native executable/path/env отделены в forge.bash_host, adapter в forge.bats.
   Windows paths переводит cygpath того же SDK. Только Bats child получает
   MSYS winsymlinks:lnk, если пользователь ещё не выбрал свой режим.
2. Shfmt подключается к существующим Conform/format callers; ShellCheck
   обслуживает настоящие LSP diagnostics. Mason tools ставятся только явно.
3. Bats 1.14.0 поддерживает Bash 3.2+. Небольшой собственный Neotest public
   adapter использует публичные Bats declaration headers, native
   argv и process exit/output. Исследованный neotest-bash собирает unquoted
   shell commands, теряет output и не имеет DAP; добавлять plugin ради одного
   query и затем патчить его не требуется. Все 67 pins сохраняются.
4. Nearest разбивается на отдельный реальный Bats process для каждого
   выбранного test, exact filter по поддерживаемой CLI семантике. File
   запускает все найденные tests; result/output привязаны к test ID. Отсутствие
   runner даёт понятную диагностику без fake passed и без DAP popup.
   File/dir использует публичный fallback Neotest к test trees: иначе несколько
   specs одного tree получают один process key. Каждый process пишет отдельный
   Bats TAP report до exit; terminal transport не участвует в разборе status.
5. Project root — ближайший Git root, иначе каталог script; runner ищет
   project node_modules/bats/bin/bats, explicit override или установленный script в PATH.
   Это project convention, не скрытая загрузка. Args UI используют native
   command arguments; quoted/escaped space проверяется реальным E2E.
6. prepare_bash явно готовит npm lock/LSP, shfmt 3.14.1, ShellCheck 0.11.0,
   Bats 1.14.0 и grammar по pinned Treesitter. Host Bash/Node фиксируются
   manifest/hash, не устанавливаются. Готовый Node SDK переиспользуется.
7. Private Git workspace с Unicode/space, sourced library, completion/error/
   format/run/pass/fail fixtures. Реальные processes/UI/actions; только публичные
   clients/cmp/diagnostics/Overseer/Neotest наблюдения. Source RED до runtime fix,
   standalone IDs для новых доказанных failures, snapshot/config/source/logs.

## Risks / Trade-offs

- Native Win paths и POSIX tools: Bash argv пути нормализуются на границе,
  CLI fixtures проверяют пробел/Unicode/args/cwd, WSL launcher не пробуется.
- Async indexing/diagnostics/completion: ожидания public notifications/results,
  completion resolve применяется до Esc. Не sleep и не private handlers.
- Bash 3.x/macOS и external CLI: fixture синтаксис совместим с Bash 3.x;
  Mac/Bash 3.2 без фактического запуска остаётся непроверенным.
- Bats filter/exit/output: pinned CLI и реальный nearest/file с соседним
  marker, zero-match не превращается в passed. Поддержка DAP отдельно IDE-057.
- Ubuntu engine недоступен: image/команды готовятся явно; Windows/Ubuntu heavy
  suites поочерёдно, непроверенная среда остаётся открытой задачей.

## Уточнение по CLI probe

Bashunit 0.49.0 и актуальный 0.53.0 в реальном CLI запускают соседний test
с тем же префиксом даже при выборе file:line/file::full_name. Anchored regex
не поддерживается. Поэтому до runtime выбран Bats 1.14.0 с настоящим regex
filter, двумя официальными синтаксисами tests и TAP/output. Исходные FAIL
сохранены; требование exact nearest и соседний marker не ослабляется.

Реальный discovery probe показал, что Bash grammar не поддерживает @test;
трансформация header в функцию также не дала надёжного дерева двух tests.
Вместо shim используем построчные declarations как сам bats-preprocess:
quoted/unquoted @test и function-comment @test. Скрипт при discovery не
исполняется, оба синтаксиса и исходные строки сохраняются. Parser остаётся
нужен редактору Bash, но Bats adapter от него не зависит. IDE-058 отдельно:
одинаковые rename edits под percent-URI aliases объединяются в Bash handler.
