## Context

См. proposal.md и IDE-012 в PROBLEMS. Go FT загружает nvim-dap-go с
зависимостью nvim-dap. В конце общего setup выполняется codelldb_path и
vim.schedule(WARN); при отсутствии бинарника не регистрируются также
C/C++/Rust конфигурации. Это независимый дефект от zsh/Go startup IDE-001.

## Goals / Non-Goals

Goals: отложить обнаружение до действия пользователя, сохранить сообщение
при реальной проблеме и зарегистрированные конфигурации, проверить отсутствие
инструмента на Windows/Ubuntu без подмены DAP.
Non-Goals: переписывать Rust build/launch, искать или устанавливать новые
версии debugger, менять прочие языковые предупреждения и UI lifecycle.
Реальные Rust/codelldb positive DAP E2E остаются в исходной матрице долга.

## Decisions

- Используем документированный function adapter nvim-dap. Он получает
  актуальный путь при каждом запросе и передаёт прежний server adapter table
  в callback. Порядок PATH → Windows standard location → Mason сохранён.
- При отсутствии инструмента сообщаем и прерываем именно эту попытку;
  глобальная загрузка и регистрация default configurations не зависят от поиска.
  Простое удаление WARN скрыло бы проблему и оставило missing adapter error.
- E2E запускает настоящую сборку. PATH дочернего редактора исключает каталоги
  с codelldb; LOCALAPPDATA/Mason уже приватные. Явно проверяем отсутствие
  инструмента и наличие Git до действий. Исходные binary/data не меняются.
  Если codelldb делит единственный PATH-каталог с обязательными tools, для
  negative-сценария нужно подготовленное окружение без него (не mock executable).
- Go open, F9 в .txt, F5 реальной launch.json и повторный запуск. Снимки
  сохраняют предупреждения; event-loop barrier проверяет scheduled уведомления.
  Для negative launch program — реальный Neovim executable, он не исполняется:
  отсутствие adapter должно остановить запуск до создания DAP-сессии.
- Наблюдатель передаёт реальные vim.notify как RPC notifications, сохраняя
  штатный вызов. Negative launch на старом коде даёт missing adapter exception
  и hit-enter; polling через blocking Lua RPC создавал гонку/таймаут самого
  наблюдателя. Push сохраняет причину без запроса за error prompt.

## Risks / Trade-offs

- Отложенная ошибка может потеряться → E2E проверяет конкретное сообщение,
  отсутствие missing adapter error/session и доступность редактирования.
- Отсутствующий бинарник на Windows скрыт установленной копией → private
  environment + проверка executable codelldb, не обход проверки по ОС.
- Поиск положительного пути сам по себе не доказывает Rust/C debugging;
  существующий долг не объявляется закрытым этим negative E2E.
- macOS/физические F-клавиши → отдельный прогон владельца.

## Migration Plan

Перезапуск Neovim после обновления конфигурации. Новых зависимостей нет.
Откат — возврат прежнего adapter setup; постоянный E2E остаётся воспроизводимым.
