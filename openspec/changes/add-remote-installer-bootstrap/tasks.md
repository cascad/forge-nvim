# Tasks

## 1. Transport и состав

- [x] 1.1 Зафиксировать Default/Custom inventory и gaps действующих installers;
  review по runtime/tools/SDK, без заявления полной установки.
- [x] 1.2 Реализовать Windows/POSIX entry: download/validate/cache/dispatch,
  без Git; existing backend local source и languages default.
- [x] 1.3 Один E2E transport stand Windows/Ubuntu: HTTP entry+archive, повтор,
  download/structure/backend failure; native shells, private paths, без host
  package operations. Mac — runnable команда, native результат отдельно.
  Windows6/Ubuntu6 PASS (§233); первая Ubuntu fixture newline ошибка сохранена.
- [x] 1.4 FIXLOG232 со Спека: IDE-BOOT-8 (ADDED), PROBLEMS/roadmap/README,
  HISTORY/commands; strict/frozen/prefix/exact staging и local commit.

## 2. Native Mac

- [ ] 2.1 Тот же tests/install-bootstrap.test.py на настоящем Mac;
  пока не запускался — не PASS. Полный Default не входит в transport gate.
