# Проверка — 2026-11-12

Чистый рефакторинг на основе 8c92268: один runtime-файл, 16 добавленных /
24 удалённых строки, net−8. Восемь entry делегируют точные прежние три
операции `prepare_navigation(enter)`; true у direction/hide, false у остальных.
Других runtime-изменений в этой итерации нет. Спецификации поведения прежние.

Один Windows selected прогон, без повторов:

| Постоянный E2E | PASS | FAIL / SKIP |
|---|---:|---:|
| tests/e2e/debug-panels.test.lua | 5 | 0 / 0 |
| tests/e2e/work-panels.test.lua | 6 | 0 / 0 |
| tests/e2e/outline.test.lua | 6 | 0 / 0 |
| tests/e2e/git-workflow.test.lua | 6 | 0 / 0 |
| tests/e2e/frame-layout.test.lua | 1 | 0 / 0 |

Итого24 PASS. У15 сохранённых native profiles: exit0/signal0, APIerrors[],
owned scopes empty. Captured controls.lua совпадает с проверенным runtime.
Артефакты: .tests/navigation-{debug-panels,work-panels,outline,git-workflow,
frame-layout}.txt, navigation-result.json, navigation-audit.json и профили
editor-e2e, перечисленные в audit. Строгая проверка этого change PASS.

Ubuntu/macOS, физический WezTerm/клавиши и общий full suite не запускались.
Нового бага/исходного RED не заявляем: поведение сохраняется. Существующие
permanent E2E используются без изменения. Черновики E2E-каталога и POSIX
probe сохранены вне commit; их прежние изменённые файлы не переписаны.
