# Verification

## Windows — 2026-11-12

Source runtime dab7bf6; SDK74AFF15B...C6AD9,67 pins/6 patched dependencies
прежние. Общий scripts/test.ps1 e2e выполнен один раз:74 файла,71 PASS/3 FAIL,
363 cases PASS/3 FAIL/5 SKIP за2604.6 s. Raw .tests/integration-20261112-wide-1
сохраняет report/logs/run.json; исходный terminal-shell.test.lua скопирован
в profile13792255328900. File существует с нулевым размером; observer прочёл
пустую строку вместо payload, после чего cleanup обрывает command.

Постоянный delayed-write.lua запускается настоящей командой текущего PTY.
Он создаёт пустой результат, ждёт1 s и пишет FORGE_AFTER/stdout marker.
Контролируемый прежний observer даёт1 RED/3 SKIP, profile15234331353600;
новый observer1 PASS/3 SKIP, profile15267032176800. Target явно наблюдает
empty → payload и следующий stdout. Kind file тоже ждёт непустую запись.
Timeout observer и native quit прежние. FORGE_REPO нужен только для replay
frozen test; каждый profile хранит реально исполненные test/fixture bytes.

Source test SHA256:698bf751684a11d11adb7dad430476518e458f4abcb1f1d52c12c1d75d02b677.
Target test:e9370455a5a0e9145d0b912a4633b15900a87601aee46fb1fb0d812e9c6e6e99.
Fixture:ecd1f9d34ef0238ccdeb3306c94bd52eec02eac0573b968f09fe5efb428e01a3.
Оба owned native root exit0/signal0/APIerrors[], без SIGTERM/hard kill;
scopes пусты, actual config/test/fixture bytes совпадают, runtime удалён.
Все временные/build данные Windows F:.

Unit360+trace11 PASS/1 SKIP, strict100 PASS. Native audit22 новых panel/DAP/key profiles
общего набора прошёл, source/test/config identity и cleanup подтверждены.
Metadata review263 paths:262 editor shutdown и1 отдельный health CLI exit0.
В четырёх editor profiles SIGTERM1/15 (IDE-085); два старых callers скрыли
это под file PASS (IDE-114). Причина native задержки не установлена.
Selected source/target не превращает общий Windows FAIL в PASS.

## Outstanding

2026-11-12 Ubuntu bash/sh: source2 RED/2 SKIP → target2 PASS/2 SKIP;
оба target result=FORGE_AFTER, тот же PTY/PID/history/stdout. Тест/fixture
SHA прежние. Source/target root0/signal0/APIerrors[]/empty scopes, удаление
runtime проверено в соответствующем pod (readiness-*-audit.json). Whole
Ubuntu74 файла:71 PASS/1 FAIL/2 SKIP,351 checks PASS/1 FAIL/6 SKIP;
непрохождение — IDE-116, а не shell observer. Whole Windows не повторялся.
Доказательства source-initial/source-v2 и native review — FIXLOG §192,
verification fix-panel-restore-focus. Tasks1.2/2.1 выполнены как сбор actual
результатов; общий статус обоих исходных наборов остаётся FAIL.

Mac и real Windows pwsh не проверены (Neovim exepath не находит pwsh;
Store alias от Get-Command не подменяет реальную проверку). Spec delta не
создавалась: skip_specs=true, поведение IDE-PANEL-19/runtime не менялось.
