# Verification Report: protect-unsaved-files-in-explorer

2026-11-11. Repo-local root F:/repo/forge-nvim; schema spec-driven.
Проверены proposal/design/delta/tasks, runtime diff и реальные source/current
профили. CLI status.isComplete относится к planning artifacts: apply показывает
3/4 implementation tasks, один pending. Change не архивирован.

## Summary

| Dimension | Status |
|---|---|
| Completeness | 3/4 tasks; 2/2 ADDED requirements имеют реализацию. Task1.4 Mac/physical GUI не выполнен |
| Correctness | Windows/Ubuntu: 2/2 требований, все7 spec scenarios покрыты9 native cases. Scenario Coverage для Mac/physical GUI: Not verified (нет запуска на целевой машине) |
| Coherence | Design Adherence и Code Pattern Consistency проверены: существующий command boundary и native backend, без fork/нового controller |

## Requirement Implementation Mapping

- IDE-FILE-3: plugins/neo-tree.lua delete_is_blocked/safe_delete и
  filesystem.commands.delete. Loaded modified file buffers сверяются по
  canonical realpath с boundary '/', Windows case-fold; guard до confirm
  и после Yes, WARN с save/Discard/retry. Native delete_node/refresh выполняет
  чистое удаление. safe_tree_node восстанавливает actual zoom selection;
  root/message/invalid сохраняют native отказ. Никакого force-write/Discard
  за пользователя или фиктивного FILE_DELETED.
- IDE-FILE-4: прежние native y/p/c, без нового runtime copy слоя.
  file-copy-delete.test.lua покрывает Unicode file/dir, dirty source,
  независимую запись destination, typed name/conflict/cancel. Копируются данные
  на диске; несохранённый source buffer не является содержимым копии.

## Scenario Coverage и evidence

Пять сценариев IDE-FILE-3 покрыты6 checks: dirty file→save/retry, hidden
descendant/sibling prefix, late modification, clean file Esc/No/zoom Yes,
recursive directory No/Yes и root refusal. Два сценария IDE-FILE-4 —3 checks.
Команды/native confirmation настоящие; поздняя background правка сделана
native buffer API, backend не подменяется. :ASToggle выключает autosave,
destructive realpath остаётся внутри owned private project.

До runtime edit source acffa63 на обеих ОС:5 controls PASS/3 ожидаемых RED
в первых8 cases. Final immutable replay с добавленным root control:6/3 в9 cases.
Файл dirty/late удалён вместе с buffer; hidden descendant удалён на диске
при сохранённом modified buffer. Current:9/9 PASS на ОС. Latest selected
Files7/Buffers8/Deleted-files5 вместе с новыми9 —29 checks на ОС. Это не
стабильный full gate: два более ранних Ubuntu legacy6/1 сохранены как IDE-104.

Audit .tests/files-audit.py:64 matrix +4 diagnostic profiles, root exit/signal0,
APIerrors[], native QuitPre/VimLeavePre/VimLeave, owned scopes empty;63
normalized runtime/pin/patch sources, точные driver и захваченные test copies.
Единственный runtime diff — neo-tree.lua, SDK/pins прежние. Quick360/16files,
trace11/2files +1 manual-link SKIP на каждой ОС, strict91. Raw reports/source
archive/first failures в ignored .tests; постоянный регресс в tests/.

## Issues

### CRITICAL

1. Task1.4: выполнить те же cases native на Mac и физический keyboard/GUI
   workflow на целевых машинах. До реального результата checkbox не закрывать,
   не архивировать. Windows/Ubuntu RPC UI не заменяет этот запуск.

### WARNING

1. IDE-104 остаётся открытым: два legacy отказа при существующем child на диске,
   capture показывает ready/expanded parent без child в visible rows.
   Source7/7, trace7/7 и latest NoTrace7/7 не доказывают исправления.
   Сохранить first failures; дальше снимать actual scan/render node map,
   child_ids/filtered flags в отказе. Не добавлять R/extra toggle/таймаут
   вместо причинного исправления. Failure collector и bounded opt-in observer
   не меняют production scan/ожидания.

### SUGGESTION

Нет. Trash/visual multi-select/cross-volume/case-only/LSP и modified rename/move
вне согласованного normal d/copy scope, не оцениваются как выполненные.

## Final Assessment

Один CRITICAL (task1.4) и один WARNING (IDE-104). Suggestion0. Реализация и
новые9 cases проверены Windows/Ubuntu; Scenario Coverage Mac/physical GUI
не проверена из-за отсутствия фактического запуска. Архивирование отложено;
полную стабильность Files и полную переносимость этот отчёт не утверждает.
