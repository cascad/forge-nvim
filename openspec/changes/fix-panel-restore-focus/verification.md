# Проверка IDE-116 / IDE-PANEL-23

2026-11-12. Runtime source7aa0ba9, Windows SDK
74AFF15B3B6BC288753B721365B088AB44C9B2BFFF152F8D27F5885B4B1C6AD9.
Ubuntu image sha256:f63a05ca328aa03d4229f1da0330511e18266107280c5771330db98a62f933d0,
готовый engine, network none, 2 CPU/3 GiB/256 pids, checkout read-only.
Windows/Ubuntu тяжёлые тесты последовательно; Desktop/WSL не управлялись.

## Полнота и соответствие

| Проверка | Результат |
|---|---|
| Задачи | 1.1–1.3 выполнены; 2.1 остаётся FAIL интеграции, 2.2 Mac открыт |
| Requirement/scenarios | IDE-PANEL-23: все четыре сценария покрыты пятью native E2E Windows/Ubuntu |
| Design | Optional focus=false в state/init/registry, weak request по source state в прежнем Neo-tree lifecycle |
| Общий regression | По68 PASS/1 FAIL из69 прежних проверок на каждой ОС; новый набор по5 PASS |
| Unit/trace | На каждой ОС360+11 PASS/1 SKIP;18 файлов PASS |
| OpenSpec |101 items strict PASS |
| Не проверено | Native Mac, physical key delivery; общий зелёный результат не получен |

Mapping: restore/fallback — state.toggle_panels → show(opts) → lifecycle.open;
возврат после native render — существующий lifecycle.rendered scheduled
callback; отмена явным выбором Files — lifecycle.focus. Штатный backend
command/reveal/scan не заменён, дополнительных таймеров нет. Другие wrappers
могут игнорировать optional context. SDK/67 pins/6 patched dependencies прежние.

## Исходный дефект и постоянный E2E

Первый общий Ubuntu target: profile4427955966267, panel-transitions12 PASS/
1 FAIL — toggle all Files+Quickfix оставил neo-tree вместо text. Native
WinEnter/BufEnter diagnostic5218296537742: main1000/text8.8 ms → Files1005
66 ms → neo-tree571 ms. Отложенный navigate действительно завершился позже
focus_main, это не недоставленный ввод.

panel-restore-focus.test.lua удерживает настоящий filesystem navigate
callback после штатного debounce. Реальные backend/IO/renderer получают
исходные аргументы; готовность определяется строками дерева и очередями,
ввод — F35 barrier. Проверяются same main window/buffer, панели/Quickfix,
Logs/Files, отсутствие install, native outcome и API errors.

| ОС | Source | Target | Native/config evidence |
|---|---|---|---|
| Windows |3 RED/2 controls |5 PASS |10 profiles: exact8 config files/test/helper, root0/signal0/APIerrors[], scopes empty; runtime FS checked |
| Ubuntu |3 RED/2 controls |5 PASS |10 profiles: same bytes/root/API/scopes; target5 FS checked в том же pod, source5 только metadata |

Windows logs .tests/restore-focus-{source,target}-panel-restore-focus.test.txt;
audits .tests/restore-focus-{source,target}-audit.json. Ubuntu evidence
.tests/ubuntu/integration-20261112/restore-focus-{source,target}*.json/txt.
Source config frozen из git7aa0ba9; source/target используют тот же финальный
test/helper. Runtime/config SHA фиксируются в каждом profile.

Ошибки разработки fixture сохранены отдельно и не засчитаны как RED:
первый EOF hold дал source5 PASS — окно уже было открыто до удержания IO.
Первый debounce wrapper оборачивал свой callback при повторном native
вызове, WrongProducer/prompt/RPC timeout затронули даже controls. Финальный
selector проверяет native callback source до обёртки. После коррекции
source/target выполнены заново на обеих ОС с неизменными bytes.

## Ubuntu предыдущих changes и исходный общий результат

Evidence .tests/ubuntu/integration-20261112, frozen sources в соседнем
integration-20261112-sources. Первый source запуск сохранён в source-initial:
launch routes читали PTY до доставки stdout, profile2954754232052. IDE-115
исправлен только в observer: pause и ROUTE_BEFORE42 ожидаются независимо,
timeout/backend прежние; stdout_at_stop сохранён. Source-v2 это новый запуск
после реального изменения теста, не замена исходного отчёта.

Source-v2: panels3ef37e0 —12 RED/1 control + tab1 RED; launchfd6b965 —1 PASS;
debugpy83cf655 —1 RED; focusdc748b7 —4 RED/2 controls.22 profiles:18 RED/
4 controls. Дополнительно shell observer2 RED/2 SKIP. Все24 config/test/
root/API/scopes и runtime FS проверены внутри того же source pod.

Whole target7aa0ba9 + исправленный test IDE-115:74 файла,71 PASS/1 FAIL/
2 SKIP;351 checks PASS/1 FAIL/6 SKIP,1148.7 s. Shell bash/sh2 PASS/2 SKIP,
launch1/debugpy1/command-order6 PASS. Original FAIL — IDE-116. Native review
265 paths: неожиданных отказов нет; SIGKILL9 stopped-child fixture отдельно
классифицирован по фактическому PASS case/hardkill/RPC failure. Это не
разрешение игнорировать остальные ненулевые exit.

Base target audit22 остановился на несовпадении ожидаемых counts панели.
Он НЕ подтверждает independent FS audit всех22 target profiles; namespace
уже удалён. Отдельные readiness target2 и новый restore target5 проверены
в своих живых pod. Сводные native metadata и отчёт полного набора сохранены.
Whole Windows из §191 остаётся71/74 PASS,3 FAIL/5 check SKIP; не повторялся.

## Выбранная интеграция после исправления

14 прежних файлов/69 checks на каждой ОС: panel-transitions13, window-lookup2,
Files7, outline-focus3, tool-panels9, work-panels6, code-focus3, Debug5,
tab-scope1, frame1, buffers8, project1, legacy4, Outline6. По54 native
profiles, exact8 config files сверены; по68 PASS/1 FAIL. Новый набор5 PASS
на каждой ОС даёт73 PASS/1 FAIL из74 target checks, а не общий PASS.

- Ubuntu IDE-117: legacy winfix-direct profile8785983585636 functional
  report.ok=true/root0/APIerrors[], но ps -ax -o pgid= -o stat= вернул nonzero.
  Stderr пуст, code/signal/stdout не сохранены. Scope.ok=false/active_after
  неизвестен. Причина не установлена; обычный no-match не доказан. --rm
  удаление контейнера не подтверждает корректность observer.
- Windows IDE-118: work-panels Go Output22849875041400/PID5876,
  nvim_exec_lua id133 не ответил за10 s. Драйвер отправил SIGTERM, root1/
  signal15/APIerrors[], Job empty. QuitPre/VimLeave отсутствуют. Snapshot
  также не получил config path, независимое FS подтверждение этого profile
  отсутствует. Это RPC stall, не установленный crash или IDE-085 quit delay.

Windows runner остановился после ошибочного файла; запущены только оставшиеся
восемь файлов, без повтора отказа. Audit scripts возвращают1 и сохраняют
обе проблемы. Ненулевой статус не превращён в PASS.

При финальной проверке агент ошибочно передал tests/run.lua обёртке без
unit/trace args, начался лишний общий запуск. Он прерван по проверенному
PID/command/parent только собственного runner/tree; результат не засчитан.
Затем прямые unit trace прошли на обеих ОС. Лог restore-focus-final-run.txt
сохранён; SDK hash и tracked pins/backports после этого прежние.

## Остаток

CRITICAL: task2.1 интеграция не зелёная (IDE-117/118); task2.2 Mac/physical
не выполнена. Спецификация и пять focused сценариев соответствуют коду.
Archive readiness не заявляется. Далее IDE-114 — native outcome обычного
E2E, IDE-117 — полный результат scope probe; причина IDE-118 открыта.
