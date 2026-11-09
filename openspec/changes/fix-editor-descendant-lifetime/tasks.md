# Tasks

## 1. Воспроизведение и Windows scope

- [x] 1.1 Добавить постоянные native process/editor E2E для IDE-075: ранний выход intermediate parent, живой orphan с реальным file lock и отдельный чужой child. Тот же тест против exact driver eeae06c даёт целевой RED и сохраняет artifact/PID/source/verdict; baseline cleanup убирает только подтверждённые собственные процессы. Проверка Windows, fixtures/реестр и описание команды в tests/e2e/README.md.
- [x] 1.2 Реализовать общий process scope и Windows Job Object backend, startup barrier до init, attach failure cleanup и идемпотентный stop. Проверка Windows: постоянные E2E из 1.1 GREEN, normal/early exit/повторный stop, реальный lock освобождён, чужой child жив; editor-process и editor-runtime сохраняют main verdict/primary error. Дописать FIXLOG/HISTORY (test-only, без изменения spec), команды и E2E README с точными границами.

## 2. POSIX граница

- [ ] 2.1 Реализовать POSIX process-group backend за тем же интерфейсом; изолировать own PGID до config, TERM/wait/KILL и сохранение forced-stop FAIL. Те же native E2E, SIGSTOP/RPC регресс и editor-runtime на Ubuntu/macOS; проверить фактическую принадлежность native language workers и явно отделённые sessions. Если engine/Mac недоступны, оставить platform verification открытой, записать команды/непроверенные границы, не объявлять общий PASS и не управлять Desktop/WSL.

## 3. Общая интеграция

- [x] 3.1 Последовательно Windows: полный Rust language suite с реальными clippy/F5/debug tests, process/runtime, SQL Tests/common panels, unit/trace и strict OpenSpec. Проверить scope/shutdown/worker absence/runtime cleanup, exact sources и append-only историю; дописать FIXLOG/HISTORY/команды/PROBLEMS/roadmap и коммит. Только реальный успешный требуемый прогон закрывает integration 3.1 add-sql-test-workflow; IDE-073/074 без причины/фикса остаются открытыми.
- [ ] 3.2 Ubuntu при уже доступном engine: те же process/runtime/Rust/SQL и явная подготовка SDK; приложить реальные platform artifacts и результаты. Без engine задача остаётся открытой, Docker/WSL lifecycle не менять.
- [ ] 3.3 macOS владельца: те же native process/runtime/language сценарии через scripts/test.sh и отдельные GUI/WezTerm проверки, если изменится доставка клавиш. Внести фактические результаты; отсутствие Mac не заменять Windows/POSIX кодом или unit. Mint отложен.
