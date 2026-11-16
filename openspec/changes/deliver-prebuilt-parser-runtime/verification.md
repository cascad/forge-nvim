# Проверка IDE-BOOT-24

2026-11-16. Windows x64, закреплённый patched Neovim0.12.2, прежние67 plugin pins/6 backports.

- Publisher `.tests/parser-runtime/publisher-windows-v2.txt`: готовый Core с33 libraries и36 query directories; native load/query probe PASS. Metadata содержит grammar URLs/revisions и hashes. Source/compiler/SDK installation не выполнялись.
- Windows `tests/install-parser-runtime.test.py`: case03 publisher revision/ABI отказ PASS в v1; cases01/02/04 PASS в v2 (3 cases,48.652s); case02 дополнен missing owned query, PASS в v3 (1 case,49.247s). Успешные независимые cases целиком не повторялись.
- Реальный HTTP source/UI/catalog/Core → private installer → launcher, Lua tree без parse errors и реальные highlight captures; runtimepath после настоящего Lazy reset предпочитает owned library перед намеренно испорченной копией в app data.
- Missing library, invalid library, missing owned highlights и invalid query дают stage nonzero, сохраняя marker/native library прежнего kit. Compiler/tree-sitter/download commands запрещены в fixture и удалены из Windows PATH.
- Unmanaged command control: startup не вызывает installer; явная команда вызывает существующий Treesitter API (provider контролируемый, source download не запускался).
- Code review обнаружил оставшийся Lazy `build=:TSUpdate`; managed hook теперь false, unmanaged сохранён. Адресный v4: managed delivery и unmanaged hook/command PASS (2 cases,53.984s), остальные зелёные cases не перезапускаются.

## Значимые failures и ограничения

Publisher v1 сравнивал несуществующий receipt.Version с policy.Version; native binary version уже проверяется отдельно, сравнение receipt исправлено. v1 unmanaged report перезаписывался process log с тем же именем; имена разделены.

Delivery v1 обнаружил реальную проблему Neovim Lua cache: `vim.loader.cache_filename` URI-encode полного пути создал basename257 символов, parent существует, fs_open падает на NTFS limit255. Ошибка init затем породила вторичный backports missing error. Parser fixture использует настоящий Lazy с отключённым только bytecode cache; production cache не изменялся. `FORGE_PARSER_TEST_CACHE=1` возвращает воспроизведение. Этот блокер записан в PROBLEMS и должен быть исправлен до full Default. Его не объявляем исправленным зелёным parser E2E.

Другие Core plugin/Mason preparation в stand контролируются. Это не full Default readiness, полный source/license inventory не готов, production catalog пуст. Native Ubuntu подтверждён дополнительным прогоном §254; Desktop/WSL не запускались/не менялись. Native Mac не проверен, публикации нет.


## Ubuntu acceptance — §254

2026-11-16: engine предоставлен владельцем, image прежний, network none,2 CPU/2GiB. Все33 native parsers собраны по pinned commits через штатный API с local sources/CLI0.26.8, Core publisher probe PASS. Все4 delivery cases PASS40.313s, raw .tests/ubuntu/parser-runtime/e2e-ubuntu-v1.txt. Native artifacts/source receipts и evidence сохранены на F; тяжёлые /tmp payloads исчезли с контейнером.

Prep failures: native reload сбрасывал local path mapping (исправлено User TSUpdate hook); compiler memory cap (1 job/CFLAGS=-O1 -g0); parser dir отсутствовал при RTP registration (mkdir до setup, изменение production publisher helper). Успешная Windows suite не повторялась. Native Mac и Lua cache bug пока открыты, full Default не заявлен.
