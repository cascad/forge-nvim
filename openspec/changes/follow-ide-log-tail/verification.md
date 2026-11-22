# Проверка IDE-152 / IDE-LOG-6

2026-11-22. Baseline c877570. Изменён только Logs renderer и2 native cases
в существующем registered ide-logs suite. Новых provider mocks нет.

## Результаты

| Набор | Windows | Ubuntu |
|---|---:|---:|
| ide-logs:3 прежних +2 новых cases | 5 PASS | 5 PASS |
| session-logs-view: native tabs/projects/restart | 1 PASS | 1 PASS |
| Unique aggregate | **6 PASS** | **6 PASS** |

Нет SKIP. Один основной packet на ОС, повторён только failed source/filter
case. Первое падение — assertion требовал последний текст под cursor, хотя
native файл заканчивается newline; viewport уже показывал нужную запись над
пустой строкой. Assertion теперь проверяет видимый текст и cursor в конце.
Production code после пакета не менялся.

Проверены initial/reopen/latest, live follow, старые cursor/topline/leftcol,
фокус кода при обновлении, focus уже видимой панели без прокрутки, manual r,
native source и level/text/reset filters. Session E2E сохраняет точные views
между tabs/projects и native quit/relaunch.14 shutdown records: exit0,
без hard-kill/API errors, owned scopes inactive.

Evidence: `.tests/log-follow/{windows,ubuntu}-packet.json`, `*-native-final.log`,
`verification.json`. Strict OpenSpec PASS, trace9, syntax2. Pins/SDK/patches/
main specs/WezTerm и session transport прежние; журналы append-only.

## Доставка

Code commit `17c0b00d3e049578989c07dd351445c45f85d2e0`. Только
`F:/apps/fride/config/forge/lua/forge/logs.lua` обновлён после baseline c877570 /
committed byte check, с prepared receipt и backup
`F:/apps/fride/backups/log-tail-20261122-17c0b00`.2 native installed-source
IDE-LOG-6 cases PASS; origin/hash и shutdown обоих профилей проверены.
Owner session не перезагружалась; достаточно перезапустить fride.

Candidate `.tests/acceptance-installer/windows-log-tail-fix/install.cmd`,
clean-source17c0b00.2521 hashes/Default plan PASS; payload.sha256:
`c12825d8e154eeac9b1fcd1f70c969cabc859cf142477118d0febb7b45da087d`.
2357 runtime hashes идентичны windows-ownership-fix; Core/Terminal/frontend
не пересобирались. Фактической GUI переустановки поверх owner kit не было.
Receipt `.tests/log-follow/delivery-final.json`, candidate-plan.log.

Own container812d778e… удалён по exact ID после task label/top (только init/sleep),
повторный ps -a по ID пуст. Desktop/WSL/чужие контейнеры не менялись.
3/3 tasks завершены; main specs не синхронизированы, change оставлен для review.
Native Mac и физическая GUI приёмка не объявляются PASS.
