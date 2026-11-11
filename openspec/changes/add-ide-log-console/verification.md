# Verification Report: add-ide-log-console

2026-11-11, baseline84f619c, repo-local spec-driven. Проверены proposal,
delta, design, tasks, native artifacts и implementation. Mac/physical GUI
не запускались; archive не выполняется.

## Summary

| Dimension | Status |
|---|---|
| Completeness | 6/7 tasks,4/4 ADDED requirements реализованы; Windows/Ubuntu задачи выполнены, Mac/GUI task3.2 открыт |
| Correctness | Все10 spec scenarios покрыты16 новыми native checks на ОС; selected regression —46 различных checks на ОС |
| Coherence | Store/source/view в421 строку, прежние registry/Edgy/controls и optional DAP focus predicate; deps/pins/SDK прежние |

## Requirement Implementation Mapping

- IDE-LOG-1: init/ForgeLogs/keymaps, logs component в registry и Edgy,
  controls work/title/help/Space w i; q/reopen, focus/code, help/zoom/restore
  проверены keyboard UI. IDE-107: optional owns_focus в прежнем helper,
  requester/Debug predicate в ide.dap; late callback не отменяет Logs/Problems.
- IDE-LOG-2: ранний notify delegate, direct Fidget update_hook с сохранённым
  set_content_key, штатные :messages snapshots, native file/output catalog,
  явные status/path/mtime/truncation. Реальные Node missing→исправление→
  js-debug breakpoint/continue в том же backend и gofmt failure/native log;
  native E492, early notify и direct Fidget проверены. Native paths сверены
  с pinned sources; каждый возможный отказ каждого backend не заявляется покрытым.
- IDE-LOG-3: native source chooser, literal query/level filters/reset, /,
  details и report. Отсутствующий/пустой источник и пустой query различимы;
  clipboard API explicit, физический clipboard остаётся GUI gate.
- IDE-LOG-4: per-session current/previous128KiB,200 displayed records,
  восемь подтверждённых inactive sessions, active/unknown PID не удаляется.
  Ротация/валидный Unicode/credentials/IO failure/reopen и native restart/
  damaged history проверены. Нет чтения opts.data/env/debug variables,
  auto install/log-level changes/polling/new jobs при просмотре.

## Scenario Coverage и исходные отказы

Source84f619c: настоящий F5 без Node даёт предупреждение с действием,
но :ForgeLogs отсутствует — по1 RED Windows/Ubuntu с exact final test bytes.
IDE-107: controlled private scheduler задерживает только native callbacks
focus_code_later, не меняет их действия. После реального failed F5 выбрана
Problems; source84 callback уводит trouble→javascript на обеих ОС. Current
Problems/Logs по2 PASS. Actual source copies и native quit/scopes сохранены.

Первый observer diagnostic сохранил :messages/cmdheight, но не доказал visual
forwarding. Первый Windows UI2PASS/1FAIL обнаружил невидимый input:
ext_messages неявно включает ext_cmdline. Подписка полностью отвергнута;
native history читается по open/r/VimEnter/VimLeavePre. Её timestamp — время
снимка. Штатные input/messages сохранены, никаких UI override в runtime нет.

Первый source suite2/2: fixture не подтвердил длинный ожидаемый Format WARN,
при cleanup потребовался SIGTERM root; второй отказ был ожиданием старого view.
После правильного ожидания source property выявлен product no-op: :ForgeLogs
с новым source при видимом component не вызывал open/refresh. Callback теперь
явно обновляет view. Первый picker fixture предполагал numbered input вместо
реального Telescope; теперь следует actual UI. Node debugger-statement probe
получил native reason=pause/allThreadsStopped=false; nvim-dap намеренно не
выбирает current frame для такой паузы. Acceptance использует настоящий F9
breakpoint; expectation паузы не ослаблен, SDK/DAP protocol не переписан.

До commit отдельные tail tests дали по2 RED: единственная длинная строка
терялась и называлась пустой; native :messages срез начинался внутри UTF-8.
Исправлен только bounded reader: сохраняется доступный хвост длинной строки,
начало выровнено по UTF-8. После этого tail2 и полный source8 PASS на каждой ОС.
Первая tail fixture использовала silent echomsg и не создавала native history;
она исключена из causal evidence, final source RED получен native nvim_echo.

## Проверенный selected regression

Основной прогон: новые core3/source8/history1/focus2 =14 checks; прежние
editor10/work-panels6/debug-panels5/tool-panels9 =30. Итого44 checks на ОС.
Он предшествует последней правке bounded reader; затем повторены source8 и
новые tail2 на финальном reader.46 различных checks на ОС, остальные runtime
bytes прежние. Это осознанный targeted repeat, не повтор всего full suite.

Audit .tests/ide106-audit.py проверяет90 scoped editor profiles, включая
source84/tail RED и final positive; root exit/signal0/APIerrors[], native
QuitPre/VimLeavePre/VimLeave, own scopes empty, root hard-kill нет. Ещё22
настоящих TUI backend (по11 на ОС) имеют VimEnter/ready/VimLeavePre/VimLeave,
разные session IDs и natural job exit0. Active parent/current history сохранена,
старых inactive осталось8. Три Windows owned Jobs завершили оставшихся своих
потомков; естественный выход каждого descendant не утверждается. Живой
terminal fixture останавливается явно своим jobstop после проверки пассивности.

Сверены66 runtime/pin/patch origins, actual driver/helper/self-test copies,
raw bytes native Conform log, credentials отсутствие в own journal, JSON/
Unicode/limits. Pre-tail source variant допускается только для одного reader
файла, post-tail profiles совпадают с финальным runtime полностью. Quick360,
trace11 на ОС, strict93. Поправлены две ошибки самого auditor: read_text
нормализовал CRLF и Windows-only active_after отсутствовал на POSIX.

67 pins/backports/Windows binary74AFF15B…C6AD9 прежние; Docker default image
f63a05ca…33d0 использован без build/pull. Desktop/WSL lifecycle/settings/prune
не выполнялись. Windows temp/cache на F:. Journals дописываются raw bytes с
guard ide106-prefix.json; §182 и AGENT_COMMANDS94 содержат историю/команды.

## Issues

### CRITICAL

1. Task3.2: native Mac/physical WezTerm клавиатура, clipboard и GUI ещё не
   проверены. Результат не заменяется Windows/Ubuntu или наличием одинаковой карты.

### WARNING

Нет в указанной проверенной области. Full suite, производительность всех
проектов, авария до выполнения early setup и live stream всех native сообщений
этим отчётом не доказаны. Native :messages — явно помеченный snapshot.

### SUGGESTION

Нет. Следующий roadmap шаг — ограниченный frame pilot, затем конкретные
сокращения по feature review. Новая диагностика не заменяет эту очередь.

## Final Assessment

Windows/Ubuntu реализация и выбранные сценарии проверены. Один CRITICAL
(native Mac/physical GUI), warning0/suggestion0; change не архивируется,
общий IDE roadmap остаётся активным.
