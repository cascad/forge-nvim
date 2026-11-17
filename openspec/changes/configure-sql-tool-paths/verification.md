# Проверка

2026-11-17, prepared upstream Sqruff0.44.0. SDK/tools не скачивались.

- Windows sql-basic:2 PASS/0 FAIL; Ubuntu sql-basic:2 PASS/0 FAIL.
  Настоящие native LSP diagnostics, project formatter, path с пробелами,
  background buffer/root и отказ неверного override. Спавнов sqls/SQLLogicTest/
  Go/Cargo/Rustc ради basic SQL нет, own protocol module не загружен.
- Прежний unsaved batch/query/Results controls: Windows1 PASS, Ubuntu1 PASS.
  Initial smoke выявил nil sqls config при явном вызове до lazy load;
  setup_connections теперь сам загружает штатный nvim-lspconfig.
- Missing optional backend/config/database: по3 PASS на Windows/Ubuntu.
  Fixture сохраняет basic formatter при missing DB backend и явно включает
  прежнюю DB setup. Это selected controls, не повтор всех SQL regressions.
- Логи .tests/toolchain-research/sql-basic-{windows,ubuntu}.txt,
  sql-advanced-{windows,ubuntu}-final.txt, sql-optional-missing-{windows,ubuntu}.txt.
- Docker ready image, no build/pull/network. Native Mac отдельно владельцем.
- OpenSpec strict, exact index/registry delta, frozen25 и append-only prefixes.

Простой Ubuntu запуск:

```sh
docker compose -f tests/containers/compose.yaml run --rm --no-deps --pull never -e FORGE_TEST_ID=IDE-BOOT-34 --entrypoint bash ubuntu tests/containers/tool-paths.sh tests/e2e/sql-basic.test.lua
```

Installer advanced SQL parts/Bash DAP в этом срезе не менялись: их
обязательность пересматривается следующим пунктом после обзора состава.
