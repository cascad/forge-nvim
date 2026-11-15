# Проверка IDE-BOOT-22

2026-11-15. Пять существующих инструментов; новые LSP/SDK/provider не добавлены.
Native Windows/Ubuntu проверены, Mac не запускался. Full release catalog пуст.

## Реальное поведение

Mason установил gopls v0.23.0, gofumpt v0.12.0, golines v0.16.0,
stylua v2.6.0, prettier3.9.10: Go build, готовый native StyLua, npm package.
Controlled Lua registry содержит те же official source IDs, настоящие Mason
compilers/receipts/exports. Это проверка пяти providers/consumers; остальной
Default и публикация этим не доказываются.

Native Neovim использует существующие plugins.lsp и plugins.format/Conform:
Lua форматируется StyLua, Go проходит golines/gofumpt (длинный вызов реально
разбивается), JSON — native Node + Prettier JS entrypoint. Project Prettier
своей .prettierrc имеет приоритет. gopls прыгает между двумя Go файлами через
настоящий textDocument/definition. Install/registry-refresh hooks во время
format/LSP заменены assertions на запрет вызова, не implementation consumers.
SDK env guard сравнивает выставленные и unset values.

## Результаты и неудачные прогоны

| Проверка | Результат | Raw |
|---|---|---|
| Native source policy52d630e | ожидаемый RED: все5 отсутствуют | .tests/ide-tools-source-red-windows.txt/json |
| Windows настоящая подготовка | 5 packages ready | .tests/ide-tools-prepare-windows-v3.txt |
| Windows первая suite | 6 PASS/2 fixture FAIL, 3.024s | .tests/ide-tools-windows-v1.txt |
| Windows исправленные format/project | адресные PASS после правки stand | formatters-windows-v2/v4.txt |
| Windows новые SDK/stage checks | 2 PASS0.520s | .tests/ide-tools-stage-windows-v1.txt |
| Windows source-build/reuse guards | 5 PASS2.020s, затем final readiness5 PASS0.280s | guards-windows-v5/readiness-windows-v6.txt |
| Windows усиленные consumers | 2 PASS1.680s | .tests/ide-tools-consumers-windows-v7.txt |
| Ubuntu source preparation из cache | 5 native packages ready | .tests/ubuntu/ide-tools-prepare-ubuntu-v3.txt |
| Ubuntu final suite | 10 PASS/2 Windows-only skips, 6.120s | .tests/ubuntu/ide-tools-ubuntu-v3.txt |
| Ubuntu усиленные consumers | 2 PASS3.054s | .tests/ide-tools-consumers-ubuntu-v4.txt |
| Выбор Core/Python/SQL/legacy/Go+Node pins | Windows5 PASS12.725s, Ubuntu5 PASS0.969s | ide-tools-profile-windows.txt; ubuntu/ide-tools-profile-ubuntu.txt |
| Старые receipt/share/opt controls | Windows3 PASS0.958s, Ubuntu4 PASS0.965s | ide-tools-readiness-windows.txt; ubuntu/ide-tools-readiness-ubuntu.txt |

В совокупности все12 разных Windows cases прошли. Full green loop не
повторялся: исправления/усиления проверялись адресно. Source policy RED снят
с исходных файлов HEAD52d630e, не с текущей таблицы после изменения.

Первоначальные prep command/log-directory ошибки относились к -u NONE stand.
Windows format failures: custom Mason root не совпал с native fride namespace;
краткий JSON в новом Prettier законно inline, .tests был под repo ignore.
Исправлены stand/oracle, добавлены project cwd и длинный JSON. Ubuntu initial
cache failure: Go deprecation lookup не работает с GOPROXY=off; штатный file
proxy из cache решил это без сети. Затем fixture unlink/restore потерял POSIX
executable mode; он сохраняется/восстанавливается. JS entry check теперь до
symlink exports, с одинаковой ясной причиной на обеих ОС. Raw failures сохранены.

## SDK и границы

Native Go1.23 на Windows: fresh tool context завершается до install callback
с требованием Go1.26.0+; правильные ready tools позволяют повторную подготовку
без обновления Go. GOTOOLCHAIN=local/RUSTUP_AUTO_INSTALL=0 — только tools stage.
SDK TUI ещё не учитывает все minima/не возвращается к выбору по этой ошибке.
Новые SDK на host не скачивались, system prefixes не подготавливались.

Docker — готовый image, --no-deps --pull never, network none, local cached
Go file proxy/npm cache/StyLua asset HTTP. Desktop/WSL не запускались и не
перенастраивались. Linux не подменяет native Mac acceptance.

## Артефакты и сохранность

.tests/ide-tools-native-metadata/{windows,ubuntu}: 5 actual receipts на ОС,
SHA72 Windows/69 Linux files. Готовые tools оставлены для повторения.
.tests/ide-tools-cleanup.json: 0.84GiB собственных compiler caches/project
copies удалены после проверки границ .tests; SDK/prepared tools не удалялись.
Frozen24 inputs, SDK/lazy-lock/backports/Cargo/чужой WIP и raw/staged journal
prefixes проверяются в .tests/ide-tools-audit.json перед точным local commit.

Следующий срез: Windows codelldb, Bash/SQL preparation, forge-sqltest;
затем Core/Terminal artifacts, настоящий Default/Custom и Mac/publication.
