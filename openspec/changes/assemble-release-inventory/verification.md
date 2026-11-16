# Verification

2026-11-16. IDE-BOOT-29.

## Native Windows / Ubuntu

tests/release-inventory.test.py: initial Windows4 PASS2.258s.
После добавления missing-current-runtime case05: Windows5 PASS2.793s,
Ubuntu5 PASS1.829s. После missing metadata/receipt case06 — адресные01+06
Windows2 PASS1.320s / Ubuntu2 PASS0.829s. Остальные green suites не повторялись.

Настоящие native Neovim/frontend инспектируют current catalog; SDK PATH пуст
в tests. Prepared source fixtures содержат настоящие plugin license/patch
files и Treesitter catalog; receipts/archive/documents для controlled evidence
явно не являются рабочими IDE bundles.6 разных сценариев пройдены на каждой ОС:
notices/determinism/strict; profile и external SDK boundary; corrupt archive/
existing output; plugin revision/backport SHA drift; legacy runtime missing;
missing manifest/invalid receipt. Prepared inputs/parser site неизменны.

## Real publisher inputs

Windows .tests/release-audit/default-windows-final; Ubuntu
.tests/ubuntu/release-audit/default-ubuntu-final. По141 items:
67 plugins,6 backports,33 parsers,21 Mason,8 artifacts,3 runtimes,1 font,
2 native SQL tools.121/134 license documents;33 parser license sets в обеих ОС.
Gaps совпадают:14 not-prepared Mason packages,6 missing-document sets,
5 не переданных языковых archives. Core/SQL/Terminal предоставлены и проверены.
Strict real Windows report корректно exit2; полнота metadata/release не заявлена.

Parser license fetched только явно из pinned source. Первый run пропускал
Python ref v0.25.0; collector исправлен для configured refs с явным revision_kind.
Повторный report использует проверенный cache и один missing source; дальнейшие
reports offline. Текущие producer SHA в final reports соответствуют исходнику.

## Boundaries

Mason package binaries не исполнялись; SDKs/venvs не копировались и не сканировались.
Не было host installs/изменения pins/runtime. Linux existing Docker28.5.1,
--rm/--no-deps/--pull never/network none,2CPU/2GiB. В disposable /tmp явно
подготовлена копия editor-deps через existing prepare-plugins, перепакованы
готовые native Core/Terminal inputs; исходные archives/image не менялись.
Docker Desktop/WSL/build/pull отсутствовали. Native Mac не проверен.

Это direct-root inventory и provided documents, без юридического или полного
transitive заключения. Следующий продуктовый срез — real Custom Core, затем
Default. FIXLOG §259/commands §167, frozen25/append-only/exact staging checks.
Final AST/Lua parse и strict OpenSpec PASS, frozen25/raw prefixes сохранены;
оба final reports и все license copy SHA перепроверены, gap sets совпадают.
Удалены2443875 bytes own fixture copies; reports/notices/raw logs сохранены.
Local commit через allowlist17, без sync/archive/push.
