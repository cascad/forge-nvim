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

Commit/installed controls/candidate дописываются после безопасной доставки;
task3 пока открыт. Native Mac и физическая GUI приёмка не объявляются PASS.
