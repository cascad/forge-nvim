# Tasks

## 1. Рабочие панели и регресс

- [x] 1.1 Добавить зарегистрированные work-panel UI E2E для новых routes/общих действий, Go summary/results, running tasks и rg search; сохранить baseline RED/причину потери query, source/artifacts и команды Windows.
- [x] 1.2 Реализовать четыре routes/контекстные maps/help/focus/zoom и сохранение search buffer, selected task; получить GREEN UI E2E Windows/Ubuntu, обновить пользовательскую шпаргалку/README.

## 2. Интеграция и история

- [x] 2.1 Последовательно проверить релевантные прежние Debug/Go test/smoke на Windows/Ubuntu, Windows unit/trace и strict validate; записать FIXLOG/HISTORY/PROBLEMS/ROADMAP/команды с точными пределами Mac/GUI и локально закоммитить. Известные IDE-047/048 не закрывать посторонним PASS.

## Verification

- Legacy query RED конечным source на config fe64757: Windows 43617957022000.
- Windows/Ubuntu: по 6 новых UI PASS, Go tests 5 + Debug panels 4 + smoke 10 PASS.
- Windows unit/trace: 15 файлов PASS, 364 checks; strict validate PASS.
- Доказательства/исходные неудачные попытки/границы: FIXLOG §109, AGENT_COMMANDS §40.
- Нет проверенного Mac/GUI; terminal/Trouble, языковая матрица и IDE-047/048 открыты.
