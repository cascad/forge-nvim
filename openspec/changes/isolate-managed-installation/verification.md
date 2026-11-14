# Проверка IDE-BOOT-11

- Windows v1:8 cases/11 failures (включая cleanup assertions). PowerShell Get-FileHash недоступен в изолированной среде; empty arguments к child powershell.exe терялись; observer учитывал созданный самим PowerShell startup-cache. Raw .tests/isolation-windows-v1.txt.
- Исправлены .NET SHA256 и передача только непустых optional args. Windows v2:8 cases/5 failures: наблюдатель startup-cache и переносы stderr. Native install/launch/repeat/failure recovery уже проходили, это видно по raw cases.
- Windows v3:11 PASS, .tests/isolation-windows-v3.txt. После добавления guard внешних ссылок внутри owned target — targeted2 PASS (repeat/launch + own-data junction), .tests/isolation-windows-targeted.txt.
- Ubuntu v1: bind mount замедлил распаковку/исполнение, первый install subprocess timeout90s; прогон остановлен точным TERM только тестового Python PID7 внутри контейнера. Первая попытка использовала host PID из docker top и ничего не завершила. Raw сохранён, результат не PASS.
- Ubuntu v2:12 cases/1 failure/1 Windows skip на native /tmp: archive guard ошибочно отвергал завершающий slash обычного каталога tar. Исправлен guard traversal без запрета обычных directory entries.
- Ubuntu v3:11 PASS/1 Windows-only skip,8.495s; .tests/isolation-ubuntu-v3.txt. Все маленькие артефакты экспортированы из native /tmp; SDK binaries повторно не копировались в bind mount.
- Existing profile/source controls после смены dispatch: Windows19 PASS, Ubuntu18 PASS/1 platform skip, .tests/isolation-profile-{windows,ubuntu}.txt.
- При review найден лог первого bootstrap Neovim: -uNONE не изолирует stdpath/log. Bootstrap получил собственные stdpath/temp/log до запуска native executable. Новый targeted case13 без NVIM_LOG_FILE override: Windows1 PASS, Ubuntu1 PASS, .tests/isolation-bootstrap-{windows,ubuntu}.txt.
- Export observer исключает expanded .runtime-cache вместе с prepared/runtime, чтобы не дублировать SDK на Windows bind mount. Результаты и receipts сохраняются; это не изменение runtime установки.
- Review относительного custom path: stdpath должны получать абсолютный путь до запуска setup. Source/target/runtime нормализованы общим installer. Новый case14: Windows1 PASS, Ubuntu1 PASS; первая попытка test driver остановилась до запуска из-за лишней скобки, raw isolation-relative-windows.txt сохранён, исправленный driver — isolation-relative-windows-v2.txt.
- Root fixtures теперь проверяют private dispatch contract; global package recipes сохранены только legacy direct tests. Нет подмены real Default SDK acceptance этими fixtures.
- Native Mac не запускался. Полные языковые bundles, actual package readiness, Terminal integration и публикация one-liner остаются IDE-138. Главные specs не изменялись; change не архивирован.
