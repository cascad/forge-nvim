# Проверка IDE-149 / IDE-PANEL-32

Дата: 2026-11-22. Исходный код: df7c6df. Объём — владельцы окон и lifetime views;
полный regression всех языков/установщиков не запускался.

## Воспроизведение и реализация

Source RED: `.tests/ownership/source-legacy-help.log`, native legacy Help
не удаляется на прежней конфигурации. Новые6 registered E2E проверяют прямую
подмену/E1513, dirty/splits, sources, Ex/forced edit, gf/quickfix/picker,
Help/legacy/save и реальные terminal jobs. Providers не заменяются mocks.

Контракт registry и один ownership controller заменяют дублирующую
классификацию и размерные repair эвристики. Native API не подменяются.
Разрешённые смены проходят через family transition либо Neo-tree lifecycle.
Help исключён из sessionoptions; старые transient views очищаются.
Существующие view sidecars и правила скрытого Terminal/Debug сохраняются.

## Итог affected packet

Основной пакет выполнен один раз на каждой ОС после блока реализации.
Затем только failed/affected suites и добавленный Git: результаты объединены
по имени сценария, повторы не увеличивают число PASS.

| Группа | Windows PASS | Ubuntu PASS |
|---|---:|---:|
| Ownership / Files / navigation / buffers / focus order | 32 | 32 |
| Files/tools/logs/outline/project/legacy sessions | 12 | 12 |
| Tool/work panels и системная консоль | 17 | 17 |
| Debug / DAP Output (реальный Go/Delve) | 10 | 10 |
| Diffview / Git workflow | 13 | 13 |
| Всего unique | **84** | **84** |

По2 SKIP — исключительно чужие platform shell cases. Windows actual pwsh
повторён с существующим PS7 каталогом в test PATH:1 PASS. Ubuntu — official
Neovim0.12.2 в уже имеющемся image, owned container с2 CPU и network none.
Ничего не скачивалось/не собиралось. Docker Desktop/WSL не запускались агентом.

Local evidence: `.tests/ownership/{windows,ubuntu}-packet.json`, `*-affected.json`,
`*-lifetime.json`, `*-source-mapping-final.log`, `windows-pwsh-final.log`,
`aggregate.json`.184 shutdown records проверены: exit0, no hard-kill/API errors,
owned scopes inactive. Эти184 включают ранние/повторные профили, не184 unique теста.

## Что исправлено/уточнено во время проверки

- Реальная ошибка: SessionLoadPost от native loadview ошибочно закрывал
  terminal windows. Ограничено `g:SessionLoad == 1`; оба buffer cases и
  весь affected session packet повторены.
- Native forced edit освобождает old guard после уже разрешённого BufLeave,
  чтобы cleanup backend в BufEnter не выдавал E1513. Прямой API set_buf
  вне разрешённого transition по-прежнему отвергается core.
- Raw native terminal тоже получает owner. Host TUI transport в session tests
  теперь явно проводит замену уже завершённого carrier в native-terminal
  transition; jobwait/real child/save/restore assertions сохранены.
- Fixture corrections: отключение autosave для действительно dirty документа;
  Terminal key `Space w T`; native TermSelect вместо toggle уже видимого1;
  реальные Persistence SavePre/Post (голый save их не шлёт). Readiness sources
  проверяет ready tree и установленный native next_source mapping. Ранние
  неуспешные результаты сохранены; повторы не маскируют их и не считаются
  отдельными багами продукта.

## Дополнительные gates

Strict OpenSpec PASS, trace9/0/0, syntax16 PASS.66 plugin pins, существующие
backport groups/companions, private Neovim и SDK recipe не менялись. WezTerm,
main specs, trace/shutdown assertions прежние. FIXLOG/AGENT_COMMANDS append-only.
`tests/lib/session_tui.lua` изменён только в авторизации host carrier transition.

## Доставка и ограничения

Code commit `e872ae4e5ca0d580d57d1eebf4d5de3188bd101c`. В `F:/apps/fride/config/forge`
13 Lua файлов обновлены после сравнения baseline сdf7c6df и committed bytes.
Backup: `F:/apps/fride/backups/ownership-20261122-e872ae4`; receipt сохранён
до замены. Установленный конфиг проверен как source всех6 новых native cases:
6 PASS, origin/hash13/6 shutdown guards PASS. Рабочая сессия не перезагружалась.

Candidate: `.tests/acceptance-installer/windows-ownership-fix/install.cmd`.
Clean-source build e872ae4,2521 файлов проверены по payload.sha256:
`155e40f0271c2856b53513399a6bd59ae96c5fad342a1a13ac0731c5094c1b4a`.
Все2357 runtime hashes совпадают с проверенным windows-layout-fix; Core/
Terminal/frontend повторно не собирались. Default `--print-plan` PASS,
prepare_languages=false и tools_versions=preserve. Это проверка нового
пакета/исходников, без повторной GUI установки поверх работающей IDE.
Receipt: `.tests/ownership/delivery-final.json`, логи installed/candidate-plan.

Own container2667a0a0… удалён по exact ID после inspect task label и top:
оставались только init/sleep. Повторный docker ps -a по ID пуст.
Desktop/WSL и чужие контейнеры не менялись.5/5 tasks выполнены; change остаётся
в active changes до отдельного review/archive, main specs не синхронизированы.

Нативный Mac и клавиатурная/GUI приёмка владельцем не объявляются PASS.
Механизм не sandbox-ит arbitrary Lua и bang; проверяет поддерживаемый pinned
набор. Новый backend требует декларации family/lifetime и native regression.
Аудит всех остальных synchronous filesystem операций — отдельный пункт.

## Дополнение от 2026-11-25

Windows-приёмка выявила E1513 при переключении вывода задач и при открытии
второго файла с видимым Outline. Overseer и Aerial обновляют буфер своих
окон по событиям после завершения команды открытия. Для этих окон
реестр разрешает backend менять буфер. Контроллер сохраняет владение и
проверяет семейство входящего буфера. Список Tasks остаётся закреплённым.

Точечные проверки Tasks и Outline прошли на Windows. Tasks меняет вывод
в dock при переходе между двумя задачами и сохраняет живую задачу после
скрытия. Outline показывает символы второго файла. Ubuntu/macOS для этого
исправления ещё не прогонялись.
