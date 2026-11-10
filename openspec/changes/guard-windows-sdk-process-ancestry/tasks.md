## 1. Guard и подготовка

- [x] 1.1 Закрепить process patch/hash и компиляцию фактического patched source в native ancestry fixtures; Windows: 4 guard PASS, 3 expected upstream RED, собственные scopes чисты.
- [x] 1.2 Подготовить staging/проверку/продвижение SDK с сохранением прежнего каталога; Windows CLI E2E проверяют invalid metadata и отказ до сборки.
- [x] 1.3 Добавить настоящие Neovim jobstop/quit lifecycle E2E и встроить обязательные probes в явную подготовку; Windows native exit/signal 0 и независимый worker жив.

## 2. Проверка и история

- [x] 2.1 Собрать StageOnly SDK и прогнать Windows process/editor-descendants, buffer/terminal и текущий panel/output regression выбранным binary; проверить отсутствие API errors и чистые scopes.
- [x] 2.2 Продвинуть проверенный SDK; Windows quick, SDK CLI E2E и строгая OpenSpec validation проходят. Linux/macOS runtime не меняется; native Mac не запускался.
- [x] 2.3 Записать FIXLOG §159 с IDE-BOOT-6 (ADDED), HISTORY, roadmap/PROBLEMS/руководства/команды, границы доказанного и каталог прежнего SDK; проверить append-only и закоммитить.
