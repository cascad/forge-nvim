# Tasks

## 1. Core parser runtime

- [x] 1.1 Добавить publisher над existing package-runtime с native ABI/query/revision checks и metadata. Проверка: tests/install-parser-runtime.test.py на Windows, настоящие libraries и отказ при повреждении/revision mismatch.
- [x] 1.2 Подключить owned site к runtimepath и managed read-only stage; native Windows delivery/launcher разбор и captures без CLI/компилятора, failure сохраняет старый kit. Добавить FIXLOG IDE-BOOT-24 (ADDED), HISTORY, команды и очередь; проверить frozen inputs, append-only и strict validate перед локальным commit. Unmanaged явную команду проверить отдельным control.

## 2. Native platform acceptance

- [x] 2.1 Тот же targeted delivery E2E на Ubuntu в уже предоставленном Docker engine без start/build/pull; сохранить результат и metadata. Native macOS явно оставить owner gate, публикацию не выполнять.
