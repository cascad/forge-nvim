# Проверка IDE-BOOT-23

Проверки2026-11-15. Native Windows/Ubuntu, без SDK/WSL/Desktop installation.
Mac и Windows Bash launch не проверялись. Работа прервана владельцем до commit;
2026-11-16 возобновлена для заключительного аудита и фиксации.

## Подтверждено

- Actual Mason: codelldb1.12.2 и existing Bash adapter release, настоящие
  compilers/download/link/receipts. Stock sources закреплены, нового provider нет.
- Owned Bash prepare/repeat/unknown hash/external override: Win3 PASS;
  Ubuntu suite5 PASS16.357s включает real Bash debug.
- Actual codelldb breakpoint/focused frame/continue/output: Windows final
  case04 PASS0.639s, Ubuntu PASS. Терминал/repl проверяется отдельно от source.
- Windows/Ubuntu publisher принимает проверенные sqls/forge-sqltest manifests,
  source/lock/patch/binary hashes и native versions. Локальные archives созданы.
- Source/UI/Core+SQL parts HTTP → staged setup → installed launcher с Go/Rust
  скрытыми в PATH → patched comment query42, SQLite, Neotest build_spec/results.
- Manifest mismatch/corrupt archive/wrong sqls и runner versions дают nonzero;
  причина в stage log, старый owner/runtime сохраняются.
- SQL managed prerequisites не требуют Go; native SQL выбирается перед старым
  PATH/Mason, explicit overrides остаются. Caller FRIDE_RUNTIME restore при exit7.

## Native результаты

| Набор | Windows | Ubuntu |
|---|---|---|
| Debug tools | 3 patch cases + real codelldb PASS; WSL launch не выполнялся | 5 PASS16.357s |
| SQL delivery | все4 cases PASS суммарно по адресным follow-ups | 4 PASS13.138s |
| Усиленный Neotest path | 1 PASS17.125s | 1 PASS8.194s |
| Policy/Core/SQL/versions | 4 PASS1.511s | 4 PASS0.694s |
| Existing receipt controls | 3 PASS0.190s | 4 PASS0.954s |
| Caller restore | 1 PASS18.006s | Windows-only |

Source policy87d6092 RED фиксирует omission Windows codelldb и старый SQL
Go dependency/stock sqls list. Raw source/initial failures сохранены.
Первые failures: RTP/focused-frame/console oracle в debugger stand, имя marker
и UI-summary вместо stage-log в SQL test. Продукт не подгонялся под эти ошибки;
повторялись адресные cases, full green loops не выполнялись.

## Доказательства и ограничения

.tests/debug-tools-*.txt и .tests/ubuntu/debug-tools-*.txt содержат raw runs.
debug-tools-metadata/{windows,ubuntu}: actual receipts/patch hashes.
Native SQL archives + receipts: .tests/debug-tools/windows-x64/sql.zip и
.tests/ubuntu/debug-tools/linux-x64/sql.tar.gz. Production catalog пуст.
Core plugin/parser callbacks/sqruff provisioning в SQL stand controlled;
это не полный Default acceptance и не доказательство всех SDK prerequisites.
SDK source builders требуют предоставленные Go/Rust/CC только publisher.

Cleanup 2.14GiB собственных payloads,78 metadata references сохранены.
SDK/lazy-lock/backports/Cargo/сторонний WIP24 hashes, raw/staged journal prefixes,
AST/doc links/diff/allowlist проверяются в .tests/debug-tools-audit.json.
Следующий Core/Terminal этап не начат.
