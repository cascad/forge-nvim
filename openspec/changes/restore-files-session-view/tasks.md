# Tasks

## 1. Files view в native session

- [x] 1.1 Добавить снимок Files до cleanup, проверку session hash и native restore во всех вкладках; common save events без второго autosave, follow при смене файла. Проверка — session-files-view E2E.
- [x] 1.2 Один Windows прогон session-files-view/project-session/session-legacy/file-explorer/outline-focus; сохранить первичный результат. Итог14 PASS/2 FAIL, без повторов. Ubuntu/macOS/physical отдельно непроверены.
- [x] 1.3 Записать FIXLOG202–205/HISTORY/AGENT_COMMANDS113–116, docs и verification; strict/diff/append-only, commit проверенного Windows среза с явным Ubuntu cleanup gate. WF-01 остальных панелей оставить открытым.

Первый прогон не принят: новый case blocked при раскрытии fixture; старый
project-session потерял Files. После прогона исправлено чтение состояния
неактивной вкладки и locator/screen capture нового E2E. Эти правки ещё
не проверены; 1.1 и commit остаются открытыми. История/verification сохранены.

Продолжение §203: один новый прогон проверил явный tab ID/locator. Старый
project-session PASS, новый case дошёл до restore equality и FAIL. Итог14
checks PASS/2 FAIL плюс file-explorer teardown FAIL; второй case FAIL —
Outline startup UI attach. Runtime прежний; E2E после прогона дополнен
expected/actual и raw metadata до cleanup, ещё не запускался. Следующий
ограниченный запуск — только новый case для точной диагностики; приёмка
пяти выбранных файлов и остальные отказы не отменены. 1.1/commit открыты.

Продолжение §204: один диагностический запуск нового case,0 PASS/1 FAIL.
Подтверждены только width/topline первой неактивной вкладки (32/14 вместо38/6);
metadata/session SHA и прочие поля совпали. После прогона подготовлены
последовательный restore по native render callback и position.save, общий
focus/follow completion. Ещё не проверены. Следующий прогон — пять выбранных
файлов, прежние отказы §203 не отменяются. FIXLOG204/commands115 дописаны;
1.1 и commit остаются открытыми.

Финал §205: конечный source совпал с Windows sequential16 PASS; расширенный
case после исправления ожиданий/latest snapshot/minimum тоже PASS. UI cache
гипотеза удалена контрольным запуском. Ubuntu final workflow ok, но E2E FAIL
по известному POSIX scope probe IDE-117 при cleanup; gate не снят. Mac/physical
и другие панели открыты. Последнее уточнение владельца: продолжать следующие
итерации/пункты в одном заходе без «дальше», сохраняя каждый FAIL.
