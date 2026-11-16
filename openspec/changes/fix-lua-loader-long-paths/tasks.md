# Tasks

## 1. Надёжная загрузка Lua

- [x] 1.1 Добавить native E2E полного редактора в длинном Unicode profile с require/reload, реальным сохранением файла и двумя запусками; Windows на исходной конфигурации подтверждает cache filename RED, артефакты сохранены.
- [x] 1.2 Применить штатную cache policy в config/lazy.lua и parser fixture; targeted Windows E2E зелёный, сохранить cold-start timings. Записать FIXLOG IDE-BOOT-25 (ADDED), HISTORY/команды/план и границы; frozen inputs/journal prefixes/strict validate перед локальным commit.

## 2. Проверка платформ

- [x] 2.1 Тот же полный editor E2E и affected parser delivery на Ubuntu в готовом ограниченном контейнере; actual Windows parser delivery с production policy. Native Mac явно оставить owner gate, без публикации и смены SDK/locks.
