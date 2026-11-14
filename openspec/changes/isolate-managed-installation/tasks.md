# Tasks

## 1. Изоляция установки и запуска

- [x] 1.1 Перевести source entry на private backend, отдельный InstallPath, запрет global package fallback; проверить native root-entry E2E и описать изменение API.
- [x] 1.2 Реализовать общий installer с manifest/probes, собственными stdpath/temp, guard targets, backup и сохранением запуска при setup failure; проверить native isolation E2E с чужим nvim/config.
- [x] 1.3 Подготовить runtime packaging/delivery contract с SHA256 и отказом для отсутствующего artifact; проверить download/local bundle, повреждение и ошибочную component mask, обновить IDE-138 и историю.

## 2. Native acceptance

- [ ] 2.1 Запустить tests/install-isolation.test.py на macOS и сохранить результат; Ubuntu не заменяет native Mac.
