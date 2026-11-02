# Tasks

## 1. Воспроизведение и lifecycle

- [x] 1.1 Зарегистрировать реальные process E2E (обычный RPC/qa!, POSIX SIGSTOP/настоящий 10s RPC timeout); сохранить RED исходного stop_process из 5e4dfe8 и обязательное завершение собственного child после теста. Windows SIGSTOP SKIP, Ubuntu actual native; README/команды описывают границы.
- [x] 1.2 Добавить общий test-only shutdown helper с прежними интервалами + SIGKILL, журналом PID/stages/exit и FAIL при forced kill; процессные E2E Windows/Ubuntu подтверждают exit и первичную ошибку, документация отражает протокол.

## 2. Интеграция редакторных тестов

- [x] 2.1 Сохранять первый RPC timeout до сигнала, передавать исходную ошибку через editor stop/startup и общий Gitsigns caller; сохранять artifacts/cleanup verdict и корректно освобождать runtime. Проверить editor-runtime и оба Gitsigns файла последовательно Windows/Ubuntu, исходный RPC IDE-047 не закрывать зелёным повтором.
- [x] 2.2 Дописать FIXLOG/HISTORY/PROBLEMS/ROADMAP/AGENT_COMMANDS, strict validate и trace; source/prefix/artifact checks и локальный коммит. Непроверенные Mac/GUI и неизвестную первичную причину оставить явно открытыми.
