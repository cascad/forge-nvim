# Design

## Context

Существующие ide registry/state уже содержат tests, tests_output, search и
tasks_output; слоты right/bottom и backend open/close готовы. Controls имеет
свой список filetypes и пока исключает их. Search close удаляет buffer, хотя
open уже умеет переиспользовать скрытый. Native действия используют контекст
sidebar/current cursor; перед созданием output split из zoom возвращаем
выбранный cursor в обычное окно.

## Goals / Non-Goals

**Goals:** распространить существующий controls на четыре рабочих компонента,
сохранить результаты/ввод/jobs и реальное действие выбранной строки.

**Non-Goals:** новый менеджер окон, новые plugins/SDK/пины, переписывание
native test/task/search действий, языковая матрица, исправление IDE-047/048,
изменение терминального ввода или управление Docker Desktop/WSL.

## Decisions

1. Общий route через registry open/focus и ту же restore/help последовательность.
   Отложенный backend focus выполняется после появления окна, только если
   запрошен тот же компонент; явные общие команды отменяют pending focus.
2. Новые filetypes получают normal q/Esc/? после native setup и при WinEnter.
   Summary native help переносится на g?; Overseer/GrugFar уже имеют g?.
3. Zoom остаётся тем же overlay. Grug-far читает cursor через bufwinid, который
   выбирает исходное окно: перед native Goto/Open/next/prev/preview возвращаем
   туда выбранную строку. Overseer callbacks тоже выполняются из обычного
   sidebar, чтобы output splits получали исходную раскладку. Neotest использует
   текущую строку; private вызовов/патчей нет. j/k и ввод Search остаются локальными.
4. Search close скрывает только окна, сохраняя backend buffer/context; текущий
   open reuse обеспечивает тот же query. Явное закрытие всего backend остаётся
   native операцией. Штатные aliases и split keys не переназначаются.
5. E2E использует fixture Go + настоящие neotest/gotestsum, process tasks из
   .vscode/tasks.json с Python release marker и реальный rg. Подготовка файлов
   и чтение состояния допустимы; тесты не вызывают native actions напрямую.

## Risks / Trade-offs

- Позднее открытие ворует фокус → проверка выбранного компонента, отмена pending
  при общем переходе; real UI маршрут между соседними панелями.
- Backend перезаписывает карты → проверка после открытия/обновления, native
  g? сохраняется; ввод проверяется отдельно от normal shortcuts.
- Overlay выбирает прежнюю строку → две реальные задачи и output выбранной.
- Closing останавливает job/теряет query → release marker и hide/reopen.
- Platform runtime → одни сценарии Windows/Ubuntu последовательно, Mac/GUI
  отдельно; SDK/подготовленные зависимости переиспользуются явно.
