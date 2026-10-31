## 1. Первый работающий контур

- [x] 1.1 Добавить suite и CLI entrypoints. Проверка: Windows quick,
  `nvim -l tests/run.lua unit e2e trace` и CLI e2e argv/invalid mode.
- [x] 1.2 Подготовить Ubuntu Docker image/compose без root и runtime-сети.
  Проверка: сборка image и запуск `ubuntu full`; результаты сохраняются отдельно.
- [x] 1.3 Подтвердить Ubuntu-regression после настройки владельца файлов отчётов.
  Проверка: `docker compose -f tests/containers/compose.yaml run --rm ubuntu full`.
- [ ] 1.4 Выполнить команды на Mac. Проверка: владелец сохраняет .tests и версии ОС.
- [x] 1.5 Дописать FIXLOG и результаты, сверить docs/roadmap и `git diff --check`.

## 2. Доведение e2e покрытия

- [x] 2.0 Базовый e2e настоящего nvim_forge с подготовленными
  pinned плагинами и изолированными каталогами. Проверка: запуск нашей сборки,
  файл/tree/search/buffers/focus, настоящий UIEnter/VeryLazy, Windows/Ubuntu PASS.
- [ ] 2.0.1 Подтвердить тот же editor e2e на Mac. Проверка: владелец выполняет
  prepare_editor.py --download и scripts/test.sh e2e, сохраняет артефакты/версии.
- [ ] 2.1 Изучить cs2d после получения пути и уточнить общий контракт.
  Проверка: решения подкреплены ссылками на реальные файлы cs2d.
- [ ] 2.2 Каталог сценариев и автоматическая проверка «фича/баг → e2e».
  Проверка: отсутствие сценария у изменённой фичи даёт неполный результат.
- [ ] 2.3 Общие IDE-сценарии и PTY/ConPTY/GUI-backends. Проверка: native
  Win/Ubuntu/Mac, доставка клавиш/clipboard проверяется реальным GUI.
- [ ] 2.4 Заполнить матрицу каждой текущей фичи/бага. Проверка: перечень в
  tests/e2e/README.md не скрывает SKIP/MANUAL/не реализовано.
