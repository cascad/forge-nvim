# Verification: preserve-normal-command-order

2026-11-12. Windows проверен; Ubuntu/Mac открыты, archive readiness не заявляется.

| Dimension | Status |
|---|---|
| Completeness | 3/5 tasks; 2.1 Ubuntu и2.2 Mac открыты |
| Correctness | IDE-PANEL-22: Windows source4 RED/2 controls → target6 PASS; Ubuntu/Mac Not verified |
| Coherence | 3 строки в прежнем helper, других owners/state/timers нет |

Source dc748b7:6 реальных profiles,4 normal order failures и2 controls
(insert, настоящий terminal input/job). Нормальные F7/F6/buffer cycle
переопределяли следующий Logs focus; deferred close закрывал сам Logs вместо
исходного сохранённого файла. Target6/6: последний выбор сохранён, file cycle/
close применяются до открытия панели, insert text и terminal PID/channel/
stdout сохраняются. Native input и scheduled barrier — без backend mocks.

57 прежних checks/10 suites PASS: editor10, buffers8, terminal escape6,
Terminal/Trouble9, Files7, Diffview7, merge/rebase4, code focus3, late DAP
focus2 и actual debugpy error1. С новыми6 —63 различных Windows target checks.
Unit360+trace11 PASS, trace1 SKIP; strict99 PASS. Это selected regression,
не global full или физическая доставка OS keys.

Audit focus-evidence.py / focus-evidence.json проверяет54 profiles:
source6/target6/regression42; saved config/test SHA, root0/signal0/APIerrors[],
no root hard kill, owned scopes empty, private runtime удалены. Единственное
runtime отличие — config/keymaps.lua; buffers/controls/state/DAP/lock прежние.
SDK74AFF15B...C6AD9 не пересобирался. Финальные temp/build F:.

Первый target выявил ошибку reader нового test: window ID передавался в
buf_get_name. Reader исправлен через win_get_buf, повторены final source6 и
target6. Ошибка test reader не объявляется багом редактора; final APIerrors[].
Source fixture хранит source identity dc748b7, исходный draft также сохранён.

Mapping: normal order — after_normal_mode early branch; scenarios focus/
cycle/close —4 native cases, other modes —2 controls и existing escape/buffers.
Helper продолжает возвращать nil. Не-normal stopinsert/feedkeys/schedule
сохранены. Интерактивный modified-file dialog проверен прежним buffers suite.

CRITICAL: задачи2.1/2.2 — actual Ubuntu source/target/selected regression и Mac.
Engine pipe недоступен, Desktop/WSL агент не запускает. Windows PASS не
подменяет платформенную проверку.
