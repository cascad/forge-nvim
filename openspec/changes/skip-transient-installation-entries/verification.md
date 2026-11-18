# Verification — 2026-11-18

## RED and implementation

Actual Default после реального Core workflow создал Windows kit/tmp/bee1.tmp.
Repeat завершился EACCES в uv.fs_lstat, прежний kit оставался готовым. Native
os.lstat показал tag0x80000023 (AF_UNIX), см.
[Microsoft MS-FSCC](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-fscc/c8e77b37-3909-4fe6-a4ea-2b9d423b1ee4).
check_owned теперь пропускает рекурсию только после успешной проверки самого
directory kit/tmp. Link ветка/все постоянные subtrees прежние. Не удаляет tmp,
не игнорирует произвольный EACCES и не распознаёт platform tags в продукте.

## Native regression

Один initial batch/ОС: Windows1795016930467361600, Ubuntu1795016943206026493.
Новые5 cases, прежние process-exit12, UI-source6 иtrace. На Windows первые2
case получили fixture ERROR: CPython не предоставляет socket.AF_UNIX. Остальные
прошли. На Ubuntu5 new cases прошли сразу. Fixture заменён стандартным Go net
helper на всех ОС: native socket, короткое relative имя, SetUnlinkOnClose(false).
Go SDK существующий, GOTOOLCHAIN local, без downloads/FFI.

Only affected closed/live2: Windows29.203s, Ubuntu11.529s PASS. Контролируется
сохранение inode/tag, active owner, config и foreign snapshot/launcher. Foreign
tmp root и persistent link остаются отказами, previous-kit failure проверен.
Latest aggregate: Windows23 PASS10 SKIP (8 POSIX signals+2 info), Ubuntu31 PASS2
info SKIP. Источники original ERROR и repeats сохранены. Product patch не менялся
после initial batch. Общий full не повторялся.

## Actual archive acceptance

Отдельный cached native stand:20 actual Mason packages,67 настоящих pinned Git
repos/ОС; source/Core33 parsers+rg/Terminal archives, actual Root/UI/backend/
config/stages/LSP, без substitutions. Source catalogs локального HTTP stand —
transport input. Это не полностью cold network/SDK installation.

Windows: Default ранее установлен21.25s; после fix launch0.31s/Core observe3.52s/
repeat17.76s; Custom Core install20.39s/launch0.33s/observe2.89s/repeat13.73s.
Ubuntu: Core package7.52s, Terminal preparation1.56s/package17.57s; Default
install14.52s/launch0.06s/observe1.39s/repeat4.71s; Custom Core install4.12s/
launch0.08s/observe1.5s/repeat2.74s. Core observer проверяет actual tree/search,
LuaLS diagnostics/edit/save/restart. Receipts всех20 tools byte-identical после
setup/repeat. Default marker хранит runtime parts core/terminal, Core — core.

Evidence: Windows .tests/default-acceptance/windows-x64/1795014050793199700/acceptance.json;
Ubuntu .tests/ubuntu/default-acceptance/linux-x64/fride-default-f3fzzdaq/acceptance.json.
Initial failed repeat сохранён как repeat-default-before-transient-fix.json;
новые stand artifacts/current source digest различаются, previous errors не стирались.

## Bounds

Native Mac/Windows WSL, installed-language matrix, cold bootstrap без SDK и
public release остаются gates. Existing Docker image, test runs offline2CPU/3GiB;
owned bridge session для явной upstream подготовки, без Desktop/WSL changes.
Host temp/cache F. Frozen SDK/locks/backports/UI, source/raw/staged journal
prefixes и exact index проверяются. Native Go helper только создаёт свой socket.
