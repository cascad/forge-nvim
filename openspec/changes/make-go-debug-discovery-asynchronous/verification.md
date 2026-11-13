# Проверка

2026-11-13, source2b57b9a, тот же SDK74aff15b / imagef63a05ca.

| Среда | Source IDE-DAP-10 | Target IDE-DAP-10 | Passive edit | Actual first/repeat debug | Input held |
|---|---|---|---|---|---|
| Windows | 1 RED на vim.fn.system | 1 PASS | 1 PASS | 1 PASS / 2 sessions | 84.027ms |
| Ubuntu | 1 RED на vim.fn.system | 1 PASS | 1 PASS | 1 PASS / 2 sessions | 25.483ms |
| Mac/physical | отложено | отложено | отложено | отложено | не измерено |

Source/target используют одинаковый final test. Target удерживает только
доставку настоящего Go env результата, показывает реальный Delve1.26.3 и
выбранный private GOBIN. Проект требует Go1.99; probe env local завершается0,
глобальный GOTOOLCHAIN auto сохраняется. Для одной info команды наблюдаются
ровно2 async subprocess: env JSON и dlv version, без второго обхода. Native
argv/stdout/code/stack сохранены, данные не подменяются. Passive edit: calls0.
Debug control: реальные два initialize/stop/terminated и stdout/stderr first/
second. Target/controls native0/0/APIerrors[]/scope0, без hard kill.

Первый Ubuntu запуск нового case не нашёл SDK по .tests/dap-tools, хотя native
Delve находился в PATH. Source и target тогда FAIL до probes, это не source
доказательство. Shell script также использовал отсутствующий FORGE_E2E_DAP_TOOLS,
debug control ещё не запускался. Test получил тот же SDK fallback exepath,
что уже имел existing late-override case; script использует установленный PATH.
Исправленный source/target запущен по одному разу Windows/Ubuntu; ранее успешный
passive и Windows debug control не повторялись. Их общий/control код прежний,
старый test snapshot отличается только добавленной SDK fallback строкой нового case.

8 final native profiles и4 prior profiles сверены audit; source child может
закончиться1/signal15 при negative cleanup, scope всё равно0. Не выдаётся за
успешный startup/новый quit fix. Windows standalone .cmd с Unicode/space
native system/fn.system/jobstart завершился0, новый shell wrapper не добавлен.
Это CLI boundary smoke, не отдельная установленная Mason проверка.

Raw .tests/go-discovery-source-final.txt/target-final.txt/passive.txt/
debug-control.txt, guest equivalents и go-discovery-audit.json. Первая Ubuntu
ошибка сохранена в go-discovery-ubuntu.txt; final в go-discovery-ubuntu-final.txt.
Runtime+test+SDK/pins/frozen/prefix guards PASS, старые infra drafts исключены.
Ready engine28.5.1/network none/private Neogit overlay; без image build,
downloads/Desktop/WSL lifecycle. Win/Linux serial, jobs2, host temp F.
Выбор версий/override policy сохраняется кодом; все permutation paths и
Mason install/реальный Mac/холодные большие проекты этим срезом не доказаны.
