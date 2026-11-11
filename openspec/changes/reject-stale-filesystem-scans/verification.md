# Verification Report: reject-stale-filesystem-scans

2026-11-11. Repo-local F:/repo/forge-nvim, spec-driven. Проверены proposal,
design, delta, tasks, declaration/config diff и actual source/current artifacts.
Финальный payload §181; предварительный вариант §180 сохранён в истории.
Planning complete не равно полной реализации: task2.3 открыт, archive не выполнен.

## Summary

| Dimension | Status |
|---|---|
| Completeness | 4/5 tasks;1/1 ADDED requirement имеет реализацию. Mac/physical GUI task2.3 не выполнен |
| Correctness | IDE-FILE-5 и все6 spec scenarios покрыты9 native E2E Windows/Ubuntu. Scenario Coverage Mac/physical GUI: Not verified (нет actual запуска) |
| Coherence | Design Adherence/Code Pattern Consistency проверены:2 native source файла через existing backport applier, без своего scanner/queue/controller |

## Requirement Implementation Mapping

IDE-FILE-5: declaration neo-tree.nvim в patches/plugins.json, native fs_scan
primary и filesystem/init companion. Config commit/build/check соответствует
прежнему паттерну Gitsigns/Neogit/Neotest; lock/revision не менялись.

- is_current_scan/job_complete/render_context не принимают obsolete root
  generation. IO/handles завершаются штатно, callbacks старого snapshot
  не меняют новый root. Independent partials разделяют актуальное поколение.
- toggle_directory/show_new_children сохраняют open intent через native
  node:expand до IO. Watcher refresh включает папку даже без path_to_reveal.
- Если full snapshot не загрузил уже раскрытую live папку, старое live tree
  сохраняется, native async get_items пересобирает snapshot. fs_stat исключает
  повтор для удалённого каталога. Это обработка конкретного overlap без таймера
  или отдельной scan queue.
- on_directory_loaded сначала помечает local folder.loaded. Watchers снимаются/
  добавляются при принятии coherent full результата; partial регистрирует свои
  папки, obsolete context не добавляет refs. Native filters/renderer сохранены.
- IDE-105: query и explicit force_open_folders намеренно задают другой view.
  Они исключены из normal coherence retry; native filter/clear сохраняют
  поиск и прежние раскрытия вместо бесконечного rescan.

Итоговый native diff +41 строка net в двух файлах; common Forge runtime diff
только plugins/neo-tree.lua7 строк и declaration. Primary SHA353a15d7…0320,
companion b388ad0a…4839. Данные и before/after fragments source-locked по целым
файлам; новый SDK binary/LSP/backend не добавлен.19-line prototype §179 остаётся
отклонённым историческим fixture, runtime его не загружает.

## Scenario Coverage и evidence

7 E2E: ordinary Unicode A/a/Enter/write; old root after newer child с
ORDER_WRITE/second native create/real watcher; independent folders; old partial
после next-root с actual watcher refs; initial-file/pending reveal; pending
folder при newer full refresh; newer partial при pending full snapshot.
Ещё2 native keyboard cases в file-filter.test.lua: f/beta/Enter исключает
раскрытую alpha, Ctrl-X возвращает её; из свёрнутого дерева clear возвращает
закрытые папки. Предварительный payload ce85bdd8…4618 (§180) дал0PASS/2RED на
каждой ОС: filter и clear зацикливались. Первая Windows проба:71 fd за5 секунд.
Финальный query/force guard проходит2/2 теми же exact tests на обеих ОС.

Source0b16d23 с final exact tests: Windows2PASS/5RED, Ubuntu4PASS/3RED. Обе ОС
воспроизвели3 controlled нарушения; дополнительные Windows ordinary/partial
visibility failures сохранены. Предыдущие7-case4/3 до init source capture
и baseline5 §179 отдельно, latest green не перезаписывает их. Source bytes
scanner/init скопированы из actual runtime. Test-only native IO callbacks
не меняют entries/errors; второй overlap использует две вложенные private
задержки с cleanup в обратном порядке.

Private candidate7PASS — предварительный probe с явно изменённым driver и
двумя SDK файлами только в own runtime. По ошибке часть этого probe пересеклась
с окончанием Ubuntu source; оба handles доведены до terminal exit, факт сохранён.
Performance выводов из этого нет. Финальные prepared Windows/Ubuntu прогоны
и большой selected regression выполнены последовательно.

Current9/9 Windows/Ubuntu; прежние Files7/copy-delete9/buffers8/deleted-files5,
Outline focus3/worktree refresh3 — ещё35 checks на ОС. Итого44 editor +15 CLI
на ОС; CLI включает LF/CRLF companion apply/check/repeat/revert и unknown
companion preflight до записи primary.101 captured editor roots: source14,
private7, filterRED4 и positive76:
exit/signal0, APIerrors[], native QuitPre/VimLeavePre/VimLeave, own scopes
после cleanup пусты, root hard-kill нет.13 Windows owned Jobs потребовали
TerminateJobObject для оставшихся собственных потомков (3 source/2 private/
8 current). Три Ubuntu worktree owned groups44/148/250 получили graceful SIGTERM;
естественный выход всех потомков не утверждается.

Audit .tests/scan-v3-audit.py проверяет63 runtime/pin/patch origins, exact
driver/helper/test и оба actual source files, реальные disk outputs/rows/
watcher refs. SDK74AFF15B…C6AD9,67 pins и прежние3 backports прежние.
Quick360/16files, trace11/2files на ОС, strict92.
Full suite/GUI/fonts/performance всех проектов этими проверками не доказаны.

## Test SDK readiness

Ubuntu local base8a6b73261d91 сохранён; refresh-editor.Dockerfile применяет
known backports offline при совпадающих pins/байтах lock. Все base layers
сохранены, пользователь forge восстановлен; добавлено34252 bytes. Tested stage
f63a05ca328a…33d0 после проверки promoted в прежний основной tag. Предварительный
default c833…5990 (§180) заменён финальным stage после preflight identity. Default
--check и identity совпадают с протестированным stage. Дистрибутивные binaries
и языковые SDK не скачивались/не заменялись, Desktop/WSL не управлялись.
Первый build отказал на non-root permission; исправлен только build USER root
с возвратом USER forge. Default tag менялся после успешного validation.

Windows temp/cache на F:. Existing user install требует явного
:Lazy build neo-tree.nvim и restart; startup только проверяет результат.

## Issues

### CRITICAL

1. Task2.3: пройти native Mac и physical WezTerm keyboard/GUI на целевых
   машинах. До actual результата не отмечать PASS и не архивировать.

### WARNING

Нет в проверенной Windows/Ubuntu области. Historical untraced failures не
имеют scan timeline: единственность их причины этим отчётом не доказывается.

### SUGGESTION

Нет. Modified rename/move, Trash/visual multi-select/cross-volume/case-only/
LSP file operations относятся к отдельной матрице и не объявляются готовыми.

## Final Assessment

Один CRITICAL (task2.3), warning0, suggestion0. Native Windows/Ubuntu реализация
и указанный selected regression проверены. Scenario Coverage Mac/physical GUI
Not verified — нет запуска на целевой машине. Archive отложен; глобальный
IDE roadmap не считается завершённым этим change.
