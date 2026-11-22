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

Доставка/commit/manifest будут дописаны после безопасного installed update
и проверки свежего candidate; task2.2 до этого остаётся открытой.

Нативный Mac и клавиатурная/GUI приёмка владельцем не объявляются PASS.
Механизм не sandbox-ит arbitrary Lua и bang; проверяет поддерживаемый pinned
набор. Новый backend требует декларации family/lifetime и native regression.
Аудит всех остальных synchronous filesystem операций — отдельный пункт.
