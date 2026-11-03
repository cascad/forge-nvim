# Tasks

## 1. Общий fallback и регресс

- [x] 1.1 Сохранить baseline source/RED с gopls и trim-only plan, добавить окончательный regression E2E трёх маршрутов и common cleanup; проверить RED на исходном config и Windows GREEN после исправления.
- [x] 1.2 Исправить общую filetype политику Conform и её callers/health без потери common trim/auto-save guards; обновить пользовательские docs, проверить Windows Go language E2E, Go tests/smoke, unit/trace и strict validate.
- [ ] 1.3 На работающем engine проверить те же E2E Ubuntu после явной подготовки; при недоступном engine оставить задачу открытой, Mac/GUI не объявлять PASS.

## 2. История

- [x] 2.1 Записать FIXLOG/HISTORY/IDE-050/roadmap/команды со Спека: IDE-FMT-1 (ADDED), исходными FAIL и границами проверок; локально закоммитить выполненный Windows шаг, сохранив незавершённую Ubuntu задачу.

Окончательный baseline RED 2795273491200, Windows 6 UI PASS и сохранённый
format plan/requests/source. Ubuntu 1.3 не выполнена: нет engine; Mac/GUI
не проверены. Полный change ещё не завершён; FIXLOG §110, AGENT_COMMANDS §42.
