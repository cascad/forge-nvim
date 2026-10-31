## 1. Регресс и исправление

- [x] 1.1 Добавить editor E2E без codelldb; проверить исходный red на
  Windows/Ubuntu для Go, breakpoint и явной попытки запуска.
- [x] 1.2 Отложить поиск и WARN до запуска, сохранить default configurations;
  проверка: tests/e2e/dap-discovery.test.lua Windows/Ubuntu без подмены DAP.
- [x] 1.3 Дописать FIXLOG/историю, docs и roadmap/PROBLEMS; проверка:
  Спека IDE-DAP-4 (ADDED), точная причина, результаты и границы проверок.

## 2. Общая интеграция

- [x] 2.1 Windows unit/e2e/wezterm/trace и Ubuntu Docker full, strict validate
  и git diff --check; проверка: сохранённые отчёты без FAIL, SKIP отдельно.
- [ ] 2.2 Mac: владелец запускает те же проверки; до отчёта явно непроверено.
