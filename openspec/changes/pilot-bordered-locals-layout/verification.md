# Verification — pilot-bordered-locals-layout

2026-11-11. Schema spec-driven, root F:/repo/forge-nvim, repo-local.

| Измерение | Результат |
|---|---|
| Completeness | 4/6 tasks после истории/commit; physical review и default decision открыты |
| Correctness | IDE-PANEL-20: все3 сценария покрыты native E2E Windows/Ubuntu; Mac/physical GUI не проверены |
| Coherence | Один owner Code/Locals, public DAP UI buffers, штатный renderer; default прежний, private fork/новых deps нет |

Source RED: команда отсутствует на исходном945bc92; .tests/frame-layout-red.txt.
IDE-108 source:44795203006100, длинное INFO при60×22 блокирует API hit-enter;
короткое сообщение проходит тот же native resize без автоматического Enter.

Финальные scoped batches: Windows45286115031700 / Ubuntu40467610890276 для
пилота; по18 checks/5 files, по14 isolated editor profiles. В28 shutdown:
root exit0/signal0, API errors[], no root hard kill, owned scopes empty;
Windows scratch runtime пути из snapshot отсутствуют. По8 actual pilot
start/save cycles, native source session restore, stdout FRAME_AFTER50.

Unit/trace: Windows/Ubuntu360 unit+11 trace PASS, один trace SKIP.
Strict OpenSpec:94 PASS. Pins/SDK/backports не менялись.
Архивы .tests/frame-regression-{windows,ubuntu}-logs и соответствующие JSON;
контрольный summary — docs/assets/panel-frames/pilot-evidence.json.

Проверены actual RGB углы/цвет, same-buffer/no shadow, step42→43, второй
breakpoint, keys/help/hide/reopen/native open/tab/minimum/правки/session.
Первое включение внутри модуля17.70мс Windows /8.48мс Ubuntu — по одному
наблюдению, не сравнительный benchmark. Idle400мс без layout loop.

Предыдущие неудачные probes не считаются runtime fixes: picker readiness
([telescope.ui-select] Nothing currently selected), неверное ожидание
modified при работающем autosave, неэкранированный % в session filename.
Один ранний broad substring session check не сохранил файл и не локализовал
причину; позднее проверяются actual buffers/ft и настоящая загрузка session,
а не любое имя панели в сохранённых options/statusline. Новый session fix
по повторному зелёному запуску не заявляется.

Critical до archive: task2.1 — реальный WezTerm Windows/Mac; task2.2 — решение
о распространении. Текущая рекомендация — сохранить пилот opt-in, не делать
двух параллельных менеджеров всего IDE. Native dapui.close layout1 не владеет
pilot float; для него q/ForgeFramePilot. Все панели не покрыты этим change.
